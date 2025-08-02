#!/bin/bash

# Script to set up Terraform backend infrastructure
# This needs to be run once before using Terraform

set -e

REGION="ap-south-1"
ENVIRONMENTS=("dev" "staging" "prod")

echo "Setting up Terraform backend infrastructure..."

for env in "${ENVIRONMENTS[@]}"; do
    echo "Setting up backend for $env environment..."
    
    # Create S3 bucket for state
    BUCKET_NAME="flask-app-terraform-state-$env"
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $REGION \
        --create-bucket-configuration LocationConstraint=$REGION \
        2>/dev/null || echo "Bucket $BUCKET_NAME already exists"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket $BUCKET_NAME \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket $BUCKET_NAME \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket $BUCKET_NAME \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    
    # Create DynamoDB table for state locking
    TABLE_NAME="terraform-state-lock-$env"
    aws dynamodb create-table \
        --table-name $TABLE_NAME \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region $REGION \
        2>/dev/null || echo "Table $TABLE_NAME already exists"
    
    echo "Backend setup completed for $env"
done

echo "All Terraform backends are ready!"
echo ""
echo "You can now initialize Terraform in each environment:"
echo "cd terraform/environments/dev && terraform init -backend-config=../../backend-config/backend-dev.hcl"
echo "cd terraform/environments/staging && terraform init -backend-config=../../backend-config/backend-staging.hcl"
echo "cd terraform/environments/prod && terraform init -backend-config=../../backend-config/backend-prod.hcl"
