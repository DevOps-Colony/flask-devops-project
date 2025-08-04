variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
}

variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets"
  type        = list(string)
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS Cluster name"
}

variable "node_group_name" {
  type        = string
  description = "Node group name"
}

variable "instance_types" {
  type        = list(string)
  description = "Instance types for EKS worker nodes"
}

variable "desired_capacity" {
  type        = number
  description = "Desired node count"
}

variable "min_size" {
  type        = number
  description = "Minimum node count"
}

variable "max_size" {
  type        = number
  description = "Maximum node count"
}

variable "db_name" {
  description = "Name of the RDS database"
  type        = string
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
}
