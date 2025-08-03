terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    # Backend configuration will be provided via CLI
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  environment    = var.environment
  project_name   = var.project_name
  vpc_cidr       = var.vpc_cidr
  azs            = data.aws_availability_zones.available.names
  
  additional_tags = var.additional_tags
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  vpc_id         = module.vpc.vpc_id
  environment    = var.environment
  project_name   = var.project_name
  
  # Security configuration for staging
  enable_waf          = true
  enable_guardduty    = true
  enable_cloudtrail   = true
  enable_config       = false  # Cost optimization for staging
  
  additional_tags = var.additional_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"
  
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids
  control_plane_subnet_ids  = module.vpc.private_subnet_ids
  
  cluster_name    = "${var.project_name}-${var.environment}-cluster"
  cluster_version = var.kubernetes_version
  environment     = var.environment
  project_name    = var.project_name
  
  # Node groups for staging
  node_groups = {
    main = {
      instance_types = ["t3.medium"]
      scaling_config = {
        desired_size = 2
        max_size     = 4
        min_size     = 1
      }
      update_config = {
        max_unavailable_percentage = 50
      }
      capacity_type = "ON_DEMAND"
      disk_size     = 50
      ami_type      = "AL2_x86_64"
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }
      taints = []
    }
  }
  
  additional_tags = var.additional_tags
}

# RDS Module (Optional for staging)
module "rds" {
  source = "../../modules/rds"
  
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.rds_security_group_id]
  
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"  # Cost-optimized for staging
  
  allocated_storage = 20
  storage_encrypted = true
  multi_az         = false  # Single AZ for staging cost optimization
  
  environment    = var.environment
  project_name   = var.project_name
  additional_tags = var.additional_tags
}
