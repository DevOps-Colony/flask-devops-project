#!/bin/bash
set -e

echo "?? Starting automated infrastructure deployment..."

# Variables
BUCKET_NAME="flask-terraform-state-$(date +%Y%m%d%H%M%S)"
AWS_REGION="ap-south-1"
ENVIRONMENT="staging"

echo "?? Setting up Terraform backend with S3"

# Create S3 bucket for terraform state
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "?? Creating S3 bucket $BUCKET_NAME"
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"

  aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
fi

# Create terraform directory structure
mkdir -p terraform/environments/staging
cd terraform/environments/staging

# Create backend config
cat > backend.hcl << BACKEND_EOF
bucket = "$BUCKET_NAME"
key    = "staging/terraform.tfstate"
region = "$AWS_REGION"
encrypt = true
BACKEND_EOF

# Create complete Terraform configuration
cat > main.tf << 'TERRAFORM_EOF'
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
}

data "aws_availability_zones" "available" {
  state = "available"
}

# *** VPC, subnet, NAT, route-table, IAM, EKS cluster + node group declarations ***
# (full block already provided in previous message)

variable "aws_region" {
  default = "ap-south-1"
}

output "cluster_name"     { value = aws_eks_cluster.main.name     }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
TERRAFORM_EOF

echo "??? Deploying infrastructure with Terraform"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

echo "? Infrastructure deployment completed!"
aws eks list-clusters --region "$AWS_REGION" --output table
