terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    # Backend configuration will be provided via CLI
    # -backend-config parameters in CI/CD pipeline
  }
}

# Configure AWS Provider
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment   = var.environment
      Project       = var.project_name
      ManagedBy     = "terraform"
      Owner         = var.owner
      CostCenter    = var.cost_center
      CreatedDate   = timestamp()
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values
locals {
  account_id = data.aws_caller_identity.current.account_id
  
  common_tags = {
    Environment   = var.environment
    Project       = var.project_name
    ManagedBy     = "terraform"
    Owner         = var.owner
    CostCenter    = var.cost_center
  }

  # Availability zones (limit to 2 for dev to save costs)
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  # Network Configuration
  vpc_cidr             = var.vpc_cidr
  availability_zones   = local.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  
  # Tagging
  environment    = var.environment
  project_name   = var.project_name
  additional_tags = local.common_tags

  # Features (cost-optimized for dev)
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = true  # Use single NAT for dev
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_flow_logs       = false  # Disable for dev to save costs
}

# Security Module
module "security" {
  source = "../../modules/security"

  vpc_id               = module.vpc.vpc_id
  environment          = var.environment
  project_name         = var.project_name
  additional_tags      = local.common_tags
  
  # Security Configuration (more permissive for dev)
  allowed_cidr_blocks  = var.allowed_cidr_blocks
  enable_waf           = false  # Disable for dev
  enable_shield        = false
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  # Network Configuration
  vpc_id                    = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.private_subnet_ids

  # Cluster Configuration
  cluster_name             = var.cluster_name
  cluster_version          = var.cluster_version
  environment              = var.environment
  project_name             = var.project_name
  additional_tags          = local.common_tags

  # Node Group Configuration (cost-optimized)
  node_groups = var.node_groups

  # Security (more open for dev)
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Add-ons (essential only for dev)
  cluster_addons = var.cluster_addons

  # Logging (reduced for dev)
  cluster_enabled_log_types = ["api", "audit"]

  depends_on = [module.vpc, module.security]
}

# ECR Repository
resource "aws_ecr_repository" "app_repository" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false  # Disable for dev to save costs
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

# ECR Lifecycle Policy (more aggressive cleanup for dev)
resource "aws_ecr_lifecycle_policy" "app_repository_policy" {
  repository = aws_ecr_repository.app_repository.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 3 tagged images"
        selection = {
          tagStatus     = "tagged"
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# CloudWatch Log Groups (minimal retention for dev)
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = 7  # Short retention for dev
  
  tags = local.common_tags
}

# Secrets Manager for application secrets
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}-${var.environment}-secrets"
  description             = "Application secrets for ${var.project_name} ${var.environment}"
  recovery_window_in_days = 0  # Force delete for dev

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    database_url = "sqlite:///app.db"  # SQLite for dev
    secret_key   = var.app_secret_key != "" ? var.app_secret_key : "dev-secret-key-${random_password.app_secret.result}"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Random password for app secret if not provided
resource "random_password" "app_secret" {
  length  = 32
  special = true
}

# S3 Bucket for static assets (optional for dev)
resource "aws_s3_bucket" "static_assets" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-static-${random_id.bucket_suffix.hex}"

  tags = local.common_tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "static_assets_versioning" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.static_assets[0].id
  versioning_configuration {
    status = "Disabled"  # No versioning for dev
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets_encryption" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.static_assets[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "static_assets_pab" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.static_assets[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
