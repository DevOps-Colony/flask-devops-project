output "db_instance_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_availability_zone" {
  description = "The availability zone of the RDS instance"
  value       = aws_db_instance.main.availability_zone
}

output "db_instance_endpoint" {
  description = "The RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_hosted_zone_id" {
  description = "The canonical hosted zone ID of the DB instance (to be used in a Route 53 Alias record)"
  value       = aws_db_instance.main.hosted_zone_id
}

output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_resource_id" {
  description = "The RDS Resource ID of this instance"
  value       = aws_db_instance.main.resource_id
}

output "db_instance_status" {
  description = "The RDS instance status"
  value       = aws_db_instance.main.status
}

output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_password" {
  description = "The database password (this password may be old, because Terraform doesn't track it after initial creation)"
  value       = random_password.master_password.result
  sensitive   = true
}

output "db_instance_port" {
  description = "The database port"
  value       = aws_db_instance.main.port
}

output "db_subnet_group_id" {
  description = "The db subnet group name"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "The ARN of the db subnet group"
  value       = aws_db_subnet_group.main.arn
}

output "db_parameter_group_id" {
  description = "The db parameter group id"
  value       = aws_db_parameter_group.main.id
}

output "db_parameter_group_arn" {
  description = "The ARN of the db parameter group"
  value       = aws_db_parameter_group.main.arn
}

output "db_option_group_id" {
  description = "The db option group id"
  value       = var.engine == "mysql" ? aws_db_option_group.main[0].id : null
}

output "db_option_group_arn" {
  description = "The ARN of the db option group"
  value       = var.engine == "mysql" ? aws_db_option_group.main[0].arn : null
}

output "enhanced_monitoring_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the monitoring role"
  value       = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null
}

output "db_instance_cloudwatch_log_groups" {
  description = "Map of CloudWatch log groups created and their attributes"
  value       = aws_db_instance.main.enabled_cloudwatch_logs_exports
}

# Connection string outputs
output "connection_string" {
  description = "Database connection string"
  value       = "${var.engine}://${aws_db_instance.main.username}:${random_password.master_password.result}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

output "jdbc_connection_string" {
  description = "JDBC connection string"
  value = var.engine == "postgres" ? (
    "jdbc:postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  ) : (
    "jdbc:mysql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  )
}

# Secrets Manager outputs
output "db_password_secret_arn" {
  description = "The ARN of the secret containing the database password"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_password_secret_name" {
  description = "The name of the secret containing the database password"
  value       = aws_secretsmanager_secret.db_password.name
}

# KMS outputs
output "kms_key_id" {
  description = "The globally unique identifier for the key used for RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the key used for RDS encryption"
  value       = aws_kms_key.rds.arn
}

# Monitoring outputs
output "cloudwatch_alarms" {
  description = "Map of CloudWatch alarms created and their attributes"
  value = var.create_cloudwatch_alarms ? {
    cpu_utilization    = aws_cloudwatch_metric_alarm.database_cpu[0]
    disk_queue_depth   = aws_cloudwatch_metric_alarm.database_disk_queue[0]
    free_storage_space = aws_cloudwatch_metric_alarm.database_disk_free[0]
    freeable_memory    = aws_cloudwatch_metric_alarm.database_free_memory[0]
  } : {}
}
