# RDS Instance Outputs

# ============================================================================
# RDS Instance Information
# ============================================================================

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_resource_id" {
  description = "Resource ID of the RDS instance"
  value       = aws_db_instance.main.resource_id
}

# ============================================================================
# Security Information
# ============================================================================

output "db_security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.main.name
}

output "db_parameter_group_name" {
  description = "DB parameter group name"
  value       = aws_db_parameter_group.main.name
}

# ============================================================================
# Secrets Manager Information
# ============================================================================

output "master_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing master password"
  value       = aws_secretsmanager_secret.db-master-password.arn
}

output "master_password_secret_name" {
  description = "Name of the Secrets Manager secret containing master password"
  value       = aws_secretsmanager_secret.db-master-password.name
}

output "connection_secret_arn" {
  description = "ARN of the Secrets Manager secret containing connection information"
  value       = aws_secretsmanager_secret.db-connection.arn
}

output "connection_secret_name" {
  description = "Name of the Secrets Manager secret containing connection information"
  value       = aws_secretsmanager_secret.db-connection.name
}

# ============================================================================
# Monitoring Information
# ============================================================================

output "monitoring_role_arn" {
  description = "ARN of the IAM role for enhanced monitoring"
  value       = var.enable_enhanced_monitoring ? aws_iam_role.rds-monitoring[0].arn : null
}

output "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled"
  value       = aws_db_instance.main.performance_insights_enabled
}

# ============================================================================
# High Availability Information
# ============================================================================

output "multi_az" {
  description = "Whether Multi-AZ is enabled"
  value       = aws_db_instance.main.multi_az
}

output "availability_zone" {
  description = "Availability zone of the RDS instance"
  value       = aws_db_instance.main.availability_zone
}

# ============================================================================
# Backup Information
# ============================================================================

output "backup_retention_period" {
  description = "Backup retention period in days"
  value       = aws_db_instance.main.backup_retention_period
}

output "backup_window" {
  description = "Backup window"
  value       = aws_db_instance.main.backup_window
}

output "maintenance_window" {
  description = "Maintenance window"
  value       = aws_db_instance.main.maintenance_window
}

# ============================================================================
# Storage Information
# ============================================================================

output "allocated_storage" {
  description = "Allocated storage in GB"
  value       = aws_db_instance.main.allocated_storage
}

output "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  value       = aws_db_instance.main.max_allocated_storage
}

output "storage_type" {
  description = "Storage type"
  value       = aws_db_instance.main.storage_type
}

output "storage_encrypted" {
  description = "Whether storage is encrypted"
  value       = aws_db_instance.main.storage_encrypted
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = aws_db_instance.main.kms_key_id
}

# ============================================================================
# CloudWatch Alarms
# ============================================================================

output "cloudwatch_alarm_arns" {
  description = "ARNs of CloudWatch alarms"
  value = var.enable_cloudwatch_alarms ? {
    cpu_utilization      = aws_cloudwatch_metric_alarm.cpu-utilization[0].arn
    free_storage_space   = aws_cloudwatch_metric_alarm.free-storage-space[0].arn
    freeable_memory      = aws_cloudwatch_metric_alarm.freeable-memory[0].arn
    database_connections = aws_cloudwatch_metric_alarm.database-connections[0].arn
    read_latency         = aws_cloudwatch_metric_alarm.read-latency[0].arn
    write_latency        = aws_cloudwatch_metric_alarm.write-latency[0].arn
  } : {}
}

# ============================================================================
# Connection String (for reference)
# ============================================================================

output "connection_string_example" {
  description = "Example connection string (password is in Secrets Manager)"
  value       = "mysql://${aws_db_instance.main.username}:<password>@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
}
