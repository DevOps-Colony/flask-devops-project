output "eks_cluster_name" {
  value = var.eks_cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
