# Bootstrap resources for Terraform state management
# Run this first to create S3 buckets and DynamoDB tables for state storage

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "flask-auth-app"
}

variable "environments" {
  description = "List of environments"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

# Create S3 buckets for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  for_each = toset(var.environments)
  bucket   = "${var.project_name}-terraform-state-${each.value}"

  tags = {
    Name        = "${var.project_name}-terraform-state-${each.value}"
    Environment = each.value
    Purpose     = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create DynamoDB tables for state locking
resource "aws_dynamodb_table" "terraform_state_lock" {
  for_each = toset(var.environments)
  name     = "terraform-state-lock-${each.value}"
  
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-state-lock-${each.value}"
    Environment = each.value
    Purpose     = "terraform-state-lock"
  }
}

# Output values
output "s3_bucket_names" {
  description = "Names of the S3 buckets created for Terraform state"
  value       = { for k, v in aws_s3_bucket.terraform_state : k => v.bucket }
}

output "dynamodb_table_names" {
  description = "Names of the DynamoDB tables created for state locking"
  value       = { for k, v in aws_dynamodb_table.terraform_state_lock : k => v.name }
}

# Instructions for using these resources
output "usage_instructions" {
  description = "Instructions for using the created backend resources"
  value = <<-EOT
    Bootstrap resources created successfully!
    
    To use these backends in your Terraform configurations:
    
    1. For each environment, initialize Terraform with the appropriate backend config:
       terraform init -backend-config=../backend-config/backend-dev.hcl
       terraform init -backend-config=../backend-config/backend-staging.hcl
       terraform init -backend-config=../backend-config/backend-prod.hcl
    
    2. Your backend configurations are:
       ${jsonencode({ for k, v in aws_s3_bucket.terraform_state : k => {
         bucket         = v.bucket
         key            = "flask-app/${k}/terraform.tfstate"
         region         = var.region
         dynamodb_table = aws_dynamodb_table.terraform_state_lock[k].name
         encrypt        = true
       }})}
  EOT
}
