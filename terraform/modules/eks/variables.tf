variable "vpc_id" {
  description = "ID of the VPC where the cluster and its nodes will be provisioned"
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs where the nodes/node groups will be provisioned"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "A list of subnet IDs where the EKS cluster control plane will be provisioned"
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
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

# Cluster Configuration
variable "cluster_endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "A list of control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_in_days" {
  description = "Number of days to retain log events"
  type        = number
  default     = 14
}

# Node Groups Configuration
variable "node_groups" {
  description = "Map of EKS managed node group definitions to create"
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
  default = {}
}

# Cluster Add-ons
variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster"
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

# Security
variable "cluster_encryption_config" {
  description = "Configuration block with encryption configuration for the cluster"
  type = list(object({
    provider_key_arn = string
    resources        = list(string)
  }))
  default = []
}

variable "cluster_security_group_additional_rules" {
  description = "List of additional security group rules to add to the cluster security group"
  type = map(object({
    description                = string
    protocol                   = string
    from_port                  = number
    to_port                    = number
    type                       = string
    cidr_blocks                = list(string)
    ipv6_cidr_blocks          = list(string)
    prefix_list_ids           = list(string)
    security_groups           = list(string)
    self                      = bool
    source_security_group_id  = string
  }))
  default = {}
}

variable "node_security_group_additional_rules" {
  description = "List of additional security group rules to add to the node security group"
  type = map(object({
    description                = string
    protocol                   = string
    from_port                  = number
    to_port                    = number
    type                       = string
    cidr_blocks                = list(string)
    ipv6_cidr_blocks          = list(string)
    prefix_list_ids           = list(string)
    security_groups           = list(string)
    self                      = bool
    source_security_group_id  = string
  }))
  default = {}
}

# IAM
variable "cluster_service_role_arn" {
  description = "The Amazon Resource Name (ARN) of the IAM role that provides permissions for the Kubernetes control plane"
  type        = string
  default     = ""
}

variable "node_group_role_arn" {
  description = "The Amazon Resource Name (ARN) of the IAM role that provides permissions for the EKS node group"
  type        = string
  default     = ""
}

variable "enable_irsa" {
  description = "Determines whether to create an OpenID Connect Provider for EKS to enable IRSA"
  type        = bool
  default     = true
}

# Networking
variable "cluster_ip_family" {
  description = "The IP family used to assign Kubernetes pod and service addresses"
  type        = string
  default     = "ipv4"
  validation {
    condition     = contains(["ipv4", "ipv6"], var.cluster_ip_family)
    error_message = "Cluster IP family must be either ipv4 or ipv6."
  }
}

variable "cluster_service_ipv4_cidr" {
  description = "The CIDR block to assign Kubernetes service IP addresses from"
  type        = string
  default     = null
}

# Fargate
variable "fargate_profiles" {
  description = "Map of Fargate Profile definitions to create"
  type = map(object({
    name = string
    selectors = list(object({
      namespace = string
      labels    = map(string)
    }))
    subnet_ids                 = list(string)
    tags                      = map(string)
    timeouts = object({
      create = string
      delete = string
    })
  }))
  default = {}
}

# CloudWatch Logging
variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events. Default retention - 90 days"
  type        = number
  default     = 90
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "If a KMS Key ARN is set, this will be used to encrypt the corresponding log group"
  type        = string
  default     = null
}

# Timeouts
variable "cluster_timeouts" {
  description = "Create, update, and delete timeout configurations for the cluster"
  type = object({
    create = string
    update = string
    delete = string
  })
  default = {
    create = "30m"
    update = "60m"
    delete = "15m"
  }
}
