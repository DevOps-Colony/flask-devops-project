terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = var.owner
      CostCenter  = var.cost_center
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"
  
  name_prefix     = "${var.project_name}-${var.environment}"
  cidr_block      = var.vpc_cidr
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs
  
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security Module
module "security" {
  source = "../../modules/security"
  
  vpc_id           = module.vpc.vpc_id
  name_prefix      = "${var.project_name}-${var.environment}"
  allowed_cidrs    = var.allowed_cidr_blocks
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# EKS Module
module "eks" {
  source = "../../modules/eks"
  
  cluster_name                        = var.cluster_name
  cluster_version                     = var.cluster_version
  vpc_id                             = module.vpc.vpc_id
  subnet_ids                         = module.vpc.private_subnet_ids
  control_plane_subnet_ids           = module.vpc.public_subnet_ids
  
  cluster_endpoint_private_access     = var.cluster_endpoint_private_access
  cluster_endpoint_public_access      = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_enabled_log_types          = var.cluster_enabled_log_types
  
  node_groups = var.node_groups
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS Module (conditional)
module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "../../modules/rds"
  
  identifier                = "${var.project_name}-${var.environment}-db"
  engine                   = var.rds_engine
  engine_version           = var.rds_engine_version
  instance_class           = var.rds_instance_class
  allocated_storage        = var.rds_allocated_storage
  max_allocated_storage    = var.rds_max_allocated_storage
  
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  allowed_security_groups  = [module.security.eks_security_group_id]
  
  db_name  = var.rds_db_name
  username = var.rds_username
  port     = var.rds_port
  
  backup_retention_period = var.rds_backup_retention_period
  backup_window          = var.rds_backup_window
  maintenance_window     = var.rds_maintenance_window
  multi_az              = var.rds_multi_az
  
  monitoring_interval               = var.rds_monitoring_interval
  performance_insights_enabled      = var.rds_performance_insights_enabled
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
