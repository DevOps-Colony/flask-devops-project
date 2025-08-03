variable "vpc_id" {
  description = "ID of the VPC where security groups will be created"
  type        = string
}

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

# Security Group Configuration
variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "bastion_security_group_id" {
  description = "Security group ID of bastion host (if exists)"
  type        = string
  default     = ""
}

# WAF Configuration
variable "enable_waf" {
  description = "Enable AWS WAF"
  type        = bool
  default     = true
}

variable "enable_waf_logging" {
  description = "Enable WAF logging to CloudWatch"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Rate limit for WAF (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "waf_blocked_countries" {
  description = "List of country codes to block in WAF"
  type        = list(string)
  default     = []
}

# Shield Configuration
variable "enable_shield" {
  description = "Enable AWS Shield Advanced"
  type        = bool
  default     = false
}

# Network ACL Configuration
variable "enable_network_acl" {
  description = "Enable custom Network ACLs"
  type        = bool
  default     = false
}

# KMS Configuration
variable "create_kms_key" {
  description = "Create a KMS key for encryption"
  type        = bool
  default     = true
}

# Security Services
variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = false
}

variable "enable_cloudtrail" {
  description = "Enable AWS CloudTrail"
  type        = bool
  default     = true
}

# Security Group Rules Customization
variable "additional_alb_ingress_rules" {
  description = "Additional ingress rules for ALB security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "additional_eks_cluster_ingress_rules" {
  description = "Additional ingress rules for EKS cluster security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "additional_eks_nodes_ingress_rules" {
  description = "Additional ingress rules for EKS nodes security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "additional_rds_ingress_rules" {
  description = "Additional ingress rules for RDS security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

# SSL/TLS Configuration
variable "ssl_policy" {
  description = "SSL policy for load balancers"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

# Compliance and Monitoring
variable "enable_compliance_monitoring" {
  description = "Enable compliance monitoring features"
  type        = bool
  default     = true
}

variable "compliance_standards" {
  description = "List of compliance standards to enable"
  type        = list(string)
  default     = ["aws-foundational-security-standard", "cis-aws-foundations-benchmark"]
}

# Notification Configuration
variable "security_notification_email" {
  description = "Email address for security notifications"
  type        = string
  default     = ""
}

variable "create_sns_topic" {
  description = "Create SNS topic for security notifications"
  type        = bool
  default     = false
}

# Secrets Management
variable "enable_secrets_manager_vpc_endpoint" {
  description = "Create VPC endpoint for Secrets Manager"
  type        = bool
  default     = false
}

variable "enable_parameter_store_vpc_endpoint" {
  description = "Create VPC endpoint for Parameter Store"
  type        = bool
  default     = false
}

# Advanced Security Features
variable "enable_macie" {
  description = "Enable Amazon Macie for data security"
  type        = bool
  default     = false
}

variable "enable_inspector" {
  description = "Enable Amazon Inspector for vulnerability assessment"
  type        = bool
  default     = false
}

# IP Allowlist/Blocklist
variable "ip_allowlist" {
  description = "List of IP addresses to always allow"
  type        = list(string)
  default     = []
}

variable "ip_blocklist" {
  description = "List of IP addresses to always block"
  type        = list(string)
  default     = []
}

# Session Management
variable "session_timeout_minutes" {
  description = "Session timeout in minutes"
  type        = number
  default     = 60
}

# Security Headers
variable "enable_security_headers" {
  description = "Enable security headers in responses"
  type        = bool
  default     = true
}

variable "security_headers" {
  description = "Map of security headers to add"
  type        = map(string)
  default = {
    "X-Frame-Options"         = "DENY"
    "X-Content-Type-Options"  = "nosniff"
    "X-XSS-Protection"        = "1; mode=block"
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains"
    "Content-Security-Policy" = "default-src 'self'"
    "Referrer-Policy"         = "strict-origin-when-cross-origin"
  }
}
