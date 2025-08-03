# Random password for database
resource "random_password" "master_password" {
  length  = 16
  special = true
}

# KMS key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.additional_tags, {
    Name = "${var.project_name}-${var.environment}-rds-encryption"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.additional_tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  family = var.engine == "postgres" ? "postgres15" : "mysql8.0"
  name   = "${var.identifier}-parameter-group"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = var.additional_tags
}

# DB Option Group (for MySQL only)
resource "aws_db_option_group" "main" {
  count                    = var.engine == "mysql" ? 1 : 0
  name                     = "${var.identifier}-option-group"
  option_group_description = "Option group for ${var.identifier}"
  engine_name              = var.engine
  major_engine_version     = split(".", var.engine_version)[0]

  dynamic "option" {
    for_each = var.options
    content {
      option_name = option.value.option_name
      
      dynamic "option_settings" {
        for_each = option.value.option_settings
        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = var.additional_tags
}

# Enhanced Monitoring Role
resource "aws_iam_role" "enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.identifier}-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.additional_tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Instance
resource "aws_db_instance" "main" {
  # Basic Configuration
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.storage_encrypted ? aws_kms_key.rds.arn : null

  # Database Configuration
  db_name  = var.db_name
  username = var.username
  password = random_password.master_password.result
  port     = var.port

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = var.publicly_accessible

  # Backup Configuration
  backup_retention_period   = var.backup_retention_period
  backup_window            = var.backup_window
  maintenance_window       = var.maintenance_window
  delete_automated_backups = var.delete_automated_backups
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  skip_final_snapshot      = var.skip_final_snapshot
  copy_tags_to_snapshot    = true

  # High Availability
  multi_az               = var.multi_az
  availability_zone      = var.multi_az ? null : var.availability_zone

  # Performance and Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? aws_kms_key.rds.arn : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  # Parameter and Option Groups
  parameter_group_name = aws_db_parameter_group.main.name
  option_group_name    = var.engine == "mysql" ? aws_db_option_group.main[0].name : null

  # Security
  deletion_protection = var.deletion_protection

  # Lifecycle
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      password,
      final_snapshot_identifier,
    ]
  }

  tags = merge(var.additional_tags, {
    Name = var.identifier
  })
}

# Store database password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.identifier}-db-password"
  description             = "Database password for ${var.identifier}"
  recovery_window_in_days = 7

  tags = var.additional_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.master_password.result
    engine   = aws_db_instance.main.engine
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  count               = var.create_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.identifier}-database-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.additional_tags
}

resource "aws_cloudwatch_metric_alarm" "database_disk_queue" {
  count               = var.create_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.identifier}-database-disk-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "64"
  alarm_description   = "This metric monitors RDS disk queue depth"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.additional_tags
}

resource "aws_cloudwatch_metric_alarm" "database_disk_free" {
  count               = var.create_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.identifier}-database-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.additional_tags
}

resource "aws_cloudwatch_metric_alarm" "database_free_memory" {
  count               = var.create_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.identifier}-database-free-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "128000000" # 128MB in bytes
  alarm_description   = "This metric monitors RDS freeable memory"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.additional_tags
}
