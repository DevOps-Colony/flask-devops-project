output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

# Uncomment this block only after you actually create an RDS resource
# output "rds_endpoint" {
#   description = "RDS instance endpoint"
#   value       = aws_db_instance.main.endpoint
# }

# Optional: build kubeconfig from the cluster you created
output "kubeconfig" {
  description = "kubectl config"
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
