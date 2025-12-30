# ==============================================================================
# Primary Identifiers (ID, ARN, Endpoint)
# ==============================================================================

output "db_instance_id" {
  description = "The identifier of the RDS instance"
  value       = aws_db_instance.this.id
}

output "db_instance_identifier" {
  description = "The RDS instance identifier (use this for RDS Proxy target)"
  value       = aws_db_instance.this.identifier
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.this.arn
}

output "db_instance_endpoint" {
  description = "The connection endpoint for the RDS instance (format: address:port)"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.this.address
}

output "db_instance_port" {
  description = "The port on which the DB accepts connections"
  value       = aws_db_instance.this.port
}

# ==============================================================================
# Database Configuration
# ==============================================================================

output "db_instance_engine" {
  description = "The database engine"
  value       = aws_db_instance.this.engine
}

output "db_instance_engine_version" {
  description = "The running version of the database engine"
  value       = aws_db_instance.this.engine_version_actual
}

output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.this.username
  sensitive   = true
}

# ==============================================================================
# Resource Configuration
# ==============================================================================

output "db_instance_class" {
  description = "The RDS instance class"
  value       = aws_db_instance.this.instance_class
}

output "db_instance_allocated_storage" {
  description = "The allocated storage size in GB"
  value       = aws_db_instance.this.allocated_storage
}

output "db_instance_storage_type" {
  description = "The storage type"
  value       = aws_db_instance.this.storage_type
}

# ==============================================================================
# Network Configuration
# ==============================================================================

output "db_subnet_group_id" {
  description = "The db subnet group name"
  value       = aws_db_subnet_group.this.id
}

output "db_subnet_group_arn" {
  description = "The ARN of the db subnet group"
  value       = aws_db_subnet_group.this.arn
}

output "db_instance_availability_zone" {
  description = "The availability zone of the instance"
  value       = aws_db_instance.this.availability_zone
}

output "db_instance_multi_az" {
  description = "Whether the RDS instance is multi-AZ"
  value       = aws_db_instance.this.multi_az
}

# ==============================================================================
# Parameter Group
# ==============================================================================

output "db_parameter_group_id" {
  description = "The db parameter group id (if created)"
  value       = var.parameter_group_family != null ? aws_db_parameter_group.this[0].id : null
}

output "db_parameter_group_arn" {
  description = "The ARN of the db parameter group (if created)"
  value       = var.parameter_group_family != null ? aws_db_parameter_group.this[0].arn : null
}

# ==============================================================================
# Monitoring and Performance
# ==============================================================================

output "db_instance_resource_id" {
  description = "The RDS Resource ID of this instance (for use in Performance Insights, monitoring, etc.)"
  value       = aws_db_instance.this.resource_id
}

output "db_instance_status" {
  description = "The RDS instance status"
  value       = aws_db_instance.this.status
}

output "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled"
  value       = aws_db_instance.this.performance_insights_enabled
}

# ==============================================================================
# Security and Backup
# ==============================================================================

output "db_instance_storage_encrypted" {
  description = "Whether the DB instance is encrypted"
  value       = aws_db_instance.this.storage_encrypted
}

output "db_instance_kms_key_id" {
  description = "The KMS key ID used for encryption"
  value       = aws_db_instance.this.kms_key_id
}

output "db_instance_backup_retention_period" {
  description = "The backup retention period"
  value       = aws_db_instance.this.backup_retention_period
}

output "db_instance_backup_window" {
  description = "The backup window"
  value       = aws_db_instance.this.backup_window
}

output "db_instance_maintenance_window" {
  description = "The maintenance window"
  value       = aws_db_instance.this.maintenance_window
}
