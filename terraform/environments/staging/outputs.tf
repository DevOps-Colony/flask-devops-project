
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
  sensitive = true
}

output "rds_username" {
  value = module.rds.db_username
}

output "rds_name" {
  value = module.rds.db_name
} 
