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
      BackupPolicy  = var.backup_policy
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

  # Availability zones (use 2 for staging)
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

  # Features
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  enable_vpn_gateway     = var.enable_vpn_gateway
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_flow_logs       = var.enable_vpc_flow_logs
}

# Security Module
module "security" {
  source = "../../modules/security"

  vpc_id               = module.vpc.vpc_id
  environment          = var.environment
  project_name         = var.project_name
  additional_tags      = local.common_tags
  
  # Security Configuration
  allowed_cidr_blocks  = var.allowed_cidr_blocks
  enable_waf           = var.enable_waf
  enable_shield        = var.enable_shield
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

  # Node Group Configuration
  node_groups = var.node_groups

  # Security
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  # Add-ons
  cluster_addons = var.cluster_addons

  # Logging
  cluster_enabled_log_types = var.cluster_enabled_log_types

  depends_on = [module.vpc, module.security]
}

# RDS Module (for staging database)
module "rds" {
  source = "../../modules/rds"
  count  = var.enable_rds ? 1 : 0

  # Network Configuration
  vpc_id                = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_ids   = [module.security.rds_security_group_id]

  # Database Configuration
  identifier           = "${var.project_name}-${var.environment}"
  engine              = var.rds_engine
  engine_version      = var.rds_engine_version
  instance_class      = var.rds_instance_class
  allocated_storage   = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_type        = var.rds_storage_type
  storage_encrypted   = true

  # Database Settings
  db_name  = var.rds_db_name
  username = var.rds_username
  port     = var.rds_port

  # Backup Configuration
  backup_retention_period = var.rds_backup_retention_period
  backup_window          = var.rds_backup_window
  maintenance_window     = var.rds_maintenance_window
  delete_automated_backups = false

  # High Availability (single-AZ for staging cost optimization)
  multi_az               = var.rds_multi_az
  publicly_accessible    = false

  # Monitoring
  monitoring_interval    = var.rds_monitoring_interval
  performance_insights_enabled = var.rds_performance_insights_enabled

  # Tagging
  environment    = var.environment
  project_name   = var.project_name
  additional_tags = local.common_tags

  depends_on = [module.vpc, module.security]
}

# ECR Repository
resource "aws_ecr_repository" "app_repository" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "app_repository_policy" {
  repository = aws_ecr_repository.app_repository.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging-", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 2 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# S3 Bucket for static assets
resource "aws_s3_bucket" "static_assets" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-static-assets-${random_id.bucket_suffix.hex}"

  tags = local.common_tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "static_assets_versioning" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.static_assets[0].id
  versioning_configuration {
    status = "Enabled"
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

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/eks/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_log_encryption ? aws_kms_key.log_encryption[0].arn : null

  tags = local.common_tags
}

# KMS Key for log encryption
resource "aws_kms_key" "log_encryption" {
  count                   = var.enable_log_encryption ? 1 : 0
  description             = "KMS key for log encryption"
  deletion_window_in_days = 7

  tags = local.common_tags
}

resource "aws_kms_alias" "log_encryption" {
  count         = var.enable_log_encryption ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-logs"
  target_key_id = aws_kms_key.log_encryption[0].key_id
}

# Secrets Manager for application secrets
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}-${var.environment}-secrets"
  description             = "Application secrets for ${var.project_name}"
  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    database_url = var.enable_rds ? module.rds[0].connection_string : ""
    secret_key   = var.app_secret_key
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
