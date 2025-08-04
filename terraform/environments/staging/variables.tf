# General Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
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
  description = "Cost center"
  type        = string
  default     = "Engineering"
}

variable "backup_policy" {
  description = "Backup policy"
  type        = string
  default     = "daily"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.20.0/24", "10.1.30.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway"
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
  description = "List of allowed CIDR blocks"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "enable_waf" {
  description = "Enable WAF"
  type        = bool
  default     = true
}

variable "enable_shield" {
  description = "Enable Shield"
  type        = bool
  default     = false
}

# EKS Configuration
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "flask-app-staging-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks for public endpoint access"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "cluster_enabled_log_types" {
  description = "List of enabled cluster log types"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

# Node Group Configuration
variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types = list(string)
    scaling_config = object({
      desired_size = number
      max_size     = number
      min_size     = number
    })
    update_config = object({
      max_unavailable_percentage = number
    })
    capacity_type = string
    disk_size     = number
    ami_type      = string
    labels        = map(string)
    taints = list(object({
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
      disk_size     = 50
      ami_type      = "AL2_x86_64"
      labels = {
        Environment = "staging"
        NodeGroup   = "main"
      }
      taints = []
    }
  }
}

# RDS Configuration
variable "enable_rds" {
  description = "Enable RDS"
  type        = bool
  default     = true
}

variable "rds_engine" {
  description = "RDS engine"
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "15.4"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "RDS max allocated storage"
  type        = number
  default     = 100
}

variable "rds_storage_type" {
  description = "RDS storage type"
  type        = string
  default     = "gp3"
}

variable "rds_db_name" {
  description = "RDS database name"
  type        = string
  default     = "flaskapp_staging"
}

variable "rds_username" {
  description = "RDS username"
  type        = string
  default     = "flaskuser"
}

variable "rds_port" {
  description = "RDS port"
  type        = number
  default     = 5432
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period"
  type        = number
  default     = 7
}

variable "rds_backup_window" {
  description = "RDS backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_maintenance_window" {
  description = "RDS maintenance window"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

variable "rds_multi_az" {
  description = "RDS multi-AZ"
  type        = bool
  default     = false
}

variable "rds_monitoring_interval" {
  description = "RDS monitoring interval"
  type        = number
  default     = 60
}

variable "rds_performance_insights_enabled" {
  description = "Enable RDS performance insights"
  type        = bool
  default     = true
}

# Storage Configuration
variable "create_s3_bucket" {
  description = "Create S3 bucket"
  type        = bool
  default     = true
}

# Logging Configuration
variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 14
}

variable "enable_log_encryption" {
  description = "Enable log encryption"
  type        = bool
  default     = true
}

# Application Configuration
variable "app_secret_key" {
  description = "Application secret key"
  type        = string
  default     = ""
  sensitive   = true
}

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Enable monitoring"
  type        = bool
  default     = true
}

variable "enable_alerting" {
  description = "Enable alerting"
  type        = bool
  default     = true
}

# Disaster Recovery
variable "enable_disaster_recovery" {
  description = "Enable disaster recovery"
  type        = bool
  default     = false
}
