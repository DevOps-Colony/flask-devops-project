# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

# EKS Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "The Kubernetes version of the cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "eks_node_groups" {
  description = "EKS node groups"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      arn           = v.arn
      status        = v.status
      capacity_type = v.capacity_type
      instance_types = v.instance_types
      ami_type      = v.ami_type
      scaling_config = v.scaling_config[0]
    }
  }
}

# RDS Outputs (conditional)
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = var.enable_rds ? aws_db_instance.main[0].endpoint : null
}

output "rds_port" {
  description = "RDS instance port"
  value       = var.enable_rds ? aws_db_instance.main[0].port : null
}

output "rds_db_name" {
  description = "RDS database name"
  value       = var.enable_rds ? aws_db_instance.main[0].db_name : null
}

# S3 Outputs (conditional)
output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = var.create_s3_bucket ? aws_s3_bucket.main[0].bucket : null
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = var.create_s3_bucket ? aws_s3_bucket.main[0].arn : null
}

# Kubeconfig
output "kubeconfig" {
  description = "kubectl config as a string"
  value = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = aws_eks_cluster.main.name
      cluster = {
        certificate-authority-data = aws_eks_cluster.main.certificate_authority[0].data
        server                     = aws_eks_cluster.main.endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = aws_eks_cluster.main.name
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args = [
            "eks",
            "get-token",
            "--cluster-name",
            aws_eks_cluster.main.name
          ]
        }
      }
    }]
  })
  sensitive = true
}

# AWS Auth ConfigMap
output "aws_auth_configmap_yaml" {
  description = "Formatted yaml output for base aws-auth configmap containing roles used in cluster node groups"
  value = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "aws-auth"
      namespace = "kube-system"
    }
    data = {
      mapRoles = yamlencode([
        {
          rolearn  = aws_iam_role.eks_node_group.arn
          username = "system:node:{{EC2PrivateDNSName}}"
          groups = [
            "system:bootstrappers",
            "system:nodes"
          ]
        }
      ])
    }
  })
}

# Useful kubectl commands
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# Connection info
output "connection_info" {
  description = "Connection information"
  value = {
    cluster_name     = aws_eks_cluster.main.name
    cluster_endpoint = aws_eks_cluster.main.endpoint
    region          = var.aws_region
    vpc_id          = aws_vpc.main.id
    rds_endpoint    = var.enable_rds ? aws_db_instance.main[0].endpoint : null
    s3_bucket       = var.create_s3_bucket ? aws_s3_bucket.main[0].bucket : null
  }
}
