# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb.arn
}

output "eks_cluster_security_group_id" {
  description = "ID of the EKS cluster security group"
  value       = aws_security_group.eks_cluster.id
}

output "eks_cluster_security_group_arn" {
  description = "ARN of the EKS cluster security group"
  value       = aws_security_group.eks_cluster.arn
}

output "eks_nodes_security_group_id" {
  description = "ID of the EKS nodes security group"
  value       = aws_security_group.eks_nodes.id
}

output "eks_nodes_security_group_arn" {
  description = "ARN of the EKS nodes security group"
  value       = aws_security_group.eks_nodes.arn
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

output "rds_security_group_arn" {
  description = "ARN of the RDS security group"
  value       = aws_security_group.rds.arn
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = aws_security_group.redis.id
}

output "redis_security_group_arn" {
  description = "ARN of the Redis security group"
  value       = aws_security_group.redis.arn
}

# WAF Outputs
output "waf_web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "waf_web_acl_capacity" {
  description = "Web ACL capacity units (WCU) currently being used by this web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].capacity : null
}

# KMS Outputs
output "kms_key_id" {
  description = "ID of the KMS key"
  value       = var.create_kms_key ? aws_kms_key.main[0].key_id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key"
  value       = var.create_kms_key ? aws_kms_key.main[0].arn : null
}

output "kms_alias_arn" {
  description = "ARN of the KMS key alias"
  value       = var.create_kms_key ? aws_kms_alias.main[0].arn : null
}

output "kms_alias_name" {
  description = "Name of the KMS key alias"
  value       = var.create_kms_key ? aws_kms_alias.main[0].name : null
}

# GuardDuty Outputs
output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "guardduty_detector_arn" {
  description = "ARN of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].arn : null
}

# Security Hub Outputs
output "security_hub_account_id" {
  description = "AWS account ID of Security Hub"
  value       = var.enable_security_hub ? aws_securityhub_account.main[0].id : null
}

# Config Outputs
output "config_configuration_recorder_name" {
  description = "Name of the Config configuration recorder"
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].name : null
}

output "config_delivery_channel_name" {
  description = "Name of the Config delivery channel"
  value       = var.enable_config ? aws_config_delivery_channel.main[0].name : null
}

output "config_s3_bucket_id" {
  description = "ID of the Config S3 bucket"
  value       = var.enable_config ? aws_s3_bucket.config[0].id : null
}

output "config_s3_bucket_arn" {
  description = "ARN of the Config S3 bucket"
  value       = var.enable_config ? aws_s3_bucket.config[0].arn : null
}

# CloudTrail Outputs
output "cloudtrail_id" {
  description = "ID of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].id : null
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "cloudtrail_s3_bucket_id" {
  description = "ID of the CloudTrail S3 bucket"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].id : null
}

output "cloudtrail_s3_bucket_arn" {
  description = "ARN of the CloudTrail S3 bucket"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].arn : null
}

# Network ACL Outputs
output "network_acl_id" {
  description = "ID of the network ACL"
  value       = var.enable_network_acl ? aws_network_acl.main[0].id : null
}

# Security Summary
output "security_summary" {
  description = "Summary of security features enabled"
  value = {
    waf_enabled          = var.enable_waf
    shield_enabled       = var.enable_shield
    guardduty_enabled    = var.enable_guardduty
    security_hub_enabled = var.enable_security_hub
    config_enabled       = var.enable_config
    cloudtrail_enabled   = var.enable_cloudtrail
    kms_key_created      = var.create_kms_key
    network_acl_enabled  = var.enable_network_acl
  }
}

# Security Group IDs (for easy reference)
output "security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    alb         = aws_security_group.alb.id
    eks_cluster = aws_security_group.eks_cluster.id
    eks_nodes   = aws_security_group.eks_nodes.id
    rds         = aws_security_group.rds.id
    redis       = aws_security_group.redis.id
  }
}

# All Security Group ARNs
output "security_group_arns" {
  description = "Map of all security group ARNs"
  value = {
    alb         = aws_security_group.alb.arn
    eks_cluster = aws_security_group.eks_cluster.arn
    eks_nodes   = aws_security_group.eks_nodes.arn
    rds         = aws_security_group.rds.arn
    redis       = aws_security_group.redis.arn
  }
}
