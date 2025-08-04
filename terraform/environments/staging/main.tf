provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source     = "../../modules/vpc"
  project    = var.project
  environment = var.environment
  cidr_block = var.vpc_cidr_block
  azs        = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source      = "../../modules/security"
  vpc_id      = module.vpc.vpc_id
  environment = var.environment
}

module "eks" {
  source            = "../../modules/eks"
  cluster_name      = var.eks_cluster_name
  subnet_ids        = module.vpc.private_subnet_ids
  vpc_id            = module.vpc.vpc_id
  node_group_name   = var.node_group_name
  instance_types    = var.instance_types
  desired_capacity  = var.desired_capacity
  min_size          = var.min_size
  max_size          = var.max_size
  region            = var.aws_region
  environment       = var.environment
  eks_role_arn      = module.security.eks_role_arn
  node_role_arn     = module.security.node_role_arn
}

module "rds" {
  source               = "../../modules/rds"
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  subnet_ids           = module.vpc.private_subnet_ids
  vpc_security_group_ids = [module.security.rds_sg_id]
  environment          = var.environment
}
