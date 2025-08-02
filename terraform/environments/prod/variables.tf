# General Configuration
variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "flask-auth-app"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps Team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "Engineering"
}

variable "backup_policy" {
  description = "Backup policy for resources"
  type        = string
  default     = "daily"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost optimization"
  type        = bool
  default     = false
}

variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
}

variable "enable_waf" {
  description = "Enable AWS WAF"
  type        = bool
  default     = true
}

variable "enable_shield" {
  description = "Enable AWS Shield Advanced"
  type        = bool
  default     = false
}

# EKS Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "flask-app-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_addons" {
  description = "Map of cluster addon configurations"
  type = map(object({
    version = string
  }))
  default = {
    coredns = {
      version = "v1.10.1-eksbuild.4"
    }
    kube-proxy = {
      version = "v1.28.2-eksbuild.2"
    }
    vpc-cni = {
      version = "v1.15.1-eksbuild.1"
    }
    aws-ebs-csi-driver = {
      version = "v1.24.0-eksbuild.1"
    }
  }
}

# Node Group Configuration
variable "node_groups" {
  description = "Map of EKS node group configurations"
  type = map(object({
    instance_types        = list(string)
    scaling_config = object({
      desired_size = number
      max_size     = number
      min_size     = number
    })
    update_config = object({
      max_unavailable_percentage = number
    })
    capacity_type  = string
    disk_size     = number
    ami_type      = string
    labels        = map(string)
    taints        = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {
    main = {
      instance_types = ["t3.medium"]
      scaling_config = {
        desired_size = 2
        max_size     = 4
        min_size     = 1
      }
      update_config = {
        max_unavailable_percentage = 25
      }
      capacity_type = "ON_DEMAND"
      disk_size    = 50
      ami_type     = "AL2_x86_64"
      labels = {
        Environment = "prod"
        NodeGroup   = "main"
      }
      taints = []
    }
    spot = {
      instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
      scaling_config = {
        desired_size = 1
        max_size     = 3
        min_size     = 0
      }
      update_config = {
        max_unavailable_percentage = 50
      }
      capacity_type = "SPOT"
      disk_size    = 50
      ami_type     = "AL2_x86_64"
      labels = {
        Environment = "prod"
        NodeGroup   = "spot"
        SpotInstance = "true"
      }
      taints = [
        {
          key    = "spot-instance"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
}

# RDS Configuration
variable "enable_rds" {
  description = "Enable RDS database"
  type        = bool
  default     = true
}

variable "rds_engine" {
  description = "Database engine"
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.4"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS instance"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage for RDS instance"
  type        = number
  default     = 100
}

variable "rds_storage_type" {
  description = "Storage type for RDS instance"
  type        = string
  default     = "gp3"
}

variable "rds_db_name" {
  description = "Name of the database"
  type        = string
  default     = "flaskapp"
}

variable "rds_username" {
  description = "Username for the database"
  type        = string
  default     = "flaskuser"
}

variable "rds_port" {
  description = "Port for the database"
  type        = number
  default     = 5432
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "rds_monitoring_interval" {
  description = "Enhanced monitoring interval"
  type        = number
  default     = 60
}

variable "rds_performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

# Storage Configuration
variable "create_s3_bucket" {
  description = "Create S3 bucket for static assets"
  type        = bool
  default     = true
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_log_encryption" {
  description = "Enable log encryption with KMS"
  type        = bool
  default     = true
}

# Application Configuration
variable "app_secret_key" {
  description = "Secret key for Flask application"
  type        = string
  sensitive   = true
  default     = ""
}

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable enhanced monitoring"
  type        = bool
  default     = true
}

variable "enable_alerting" {
  description = "Enable CloudWatch alerting"
  type        = bool
  default     = true
}

# Disaster Recovery
variable "enable_disaster_recovery" {
  description = "Enable disaster recovery features"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "Backup schedule for resources"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Daily at 2 AM
}
