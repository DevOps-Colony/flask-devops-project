# Network Configuration
variable "vpc_id" {
  description = "ID of the VPC where the RDS instance will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the RDS instance"
  type        = list(string)
}

# Basic Configuration
variable "identifier" {
  description = "The name of the RDS instance"
  type        = string
}

variable "engine" {
  description = "The database engine"
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "Engine must be either 'postgres' or 'mysql'."
  }
}

variable "engine_version" {
  description = "The engine version to use"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

# Storage Configuration
variable "allocated_storage" {
  description = "The allocated storage in gigabytes"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "The upper limit to which Amazon RDS can automatically scale the storage of the DB instance"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "One of standard (magnetic), gp2 (general purpose SSD), gp3 (general purpose SSD), or io1 (provisioned IOPS SSD)"
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
  type        = bool
  default     = true
}

variable "iops" {
  description = "The amount of provisioned IOPS. Setting this implies a storage_type of io1"
  type        = number
  default     = null
}

# Database Configuration
variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "app"
}

variable "username" {
  description = "Username for the master DB user"
  type        = string
  default     = "dbadmin"
}

variable "port" {
  description = "The port on which the DB accepts connections"
  type        = number
  default     = null
}

variable "publicly_accessible" {
  description = "Bool to control if instance is publicly accessible"
  type        = bool
  default     = false
}

# Backup Configuration
variable "backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "The daily time range (in UTC) during which automated backups are created if they are enabled"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "The window to perform maintenance in"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

variable "delete_automated_backups" {
  description = "Specifies whether to remove automated backups immediately after the DB instance is deleted"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "The database can't be deleted when this value is set to true"
  type        = bool
  default     = false
}

# High Availability
variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "The Availability Zone of the RDS instance"
  type        = string
  default     = null
}

# Performance and Monitoring
variable "monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance"
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "performance_insights_enabled" {
  description = "Specifies whether Performance Insights are enabled"
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "The amount of time in days to retain Performance Insights data"
  type        = number
  default     = 7
}

# Parameter Groups
variable "parameters" {
  description = "A list of DB parameters (map) to apply"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Option Groups (for MySQL)
variable "options" {
  description = "A list of Options to apply"
  type = list(object({
    option_name = string
    option_settings = list(object({
      name  = string
      value = string
    }))
  }))
  default = []
}

# Tagging
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Monitoring and Alerting
variable "create_cloudwatch_alarms" {
  description = "Whether to create CloudWatch alarms for the RDS instance"
  type        = bool
  default     = true
}

variable "alarm_actions" {
  description = "The list of actions to execute when this alarm transitions into an ALARM state"
  type        = list(string)
  default     = []
}
