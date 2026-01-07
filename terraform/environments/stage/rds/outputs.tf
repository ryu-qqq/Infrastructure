# RDS Instance Outputs

# ============================================================================
# RDS Instance Information
# ============================================================================

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance"
  value       = module.rds.db_instance_arn
}

output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS instance"
  value       = module.rds.db_instance_endpoint
}

output "db_instance_address" {
  description = "Hostname of the RDS instance"
  value       = module.rds.db_instance_address
}

output "db_instance_port" {
  description = "Port of the RDS instance"
  value       = module.rds.db_instance_port
}

output "db_instance_name" {
  description = "Database name"
  value       = module.rds.db_instance_name
}

output "db_instance_username" {
  description = "Master username"
  value       = module.rds.db_instance_username
  sensitive   = true
}

output "db_instance_resource_id" {
  description = "Resource ID of the RDS instance"
  value       = module.rds.db_instance_resource_id
}

# ============================================================================
# Security Information
# ============================================================================

output "db_security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = module.rds_security_group.security_group_id
}

output "db_subnet_group_id" {
  description = "DB subnet group name"
  value       = module.rds.db_subnet_group_id
}

output "db_parameter_group_id" {
  description = "DB parameter group ID"
  value       = module.rds.db_parameter_group_id
}

# ============================================================================
# Secrets Manager Information
# ============================================================================

output "master_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing master credentials and connection info"
  value       = aws_secretsmanager_secret.db-master-password.arn
}

output "master_password_secret_name" {
  description = "Name of the Secrets Manager secret containing master credentials and connection info"
  value       = aws_secretsmanager_secret.db-master-password.name
}

# ============================================================================
# Monitoring Information
# ============================================================================

output "monitoring_role_arn" {
  description = "ARN of the IAM role for enhanced monitoring"
  value       = var.enable_enhanced_monitoring ? module.rds_monitoring_role[0].role_arn : null
}

output "performance_insights_enabled" {
  description = "Whether Performance Insights is enabled"
  value       = module.rds.performance_insights_enabled
}

# ============================================================================
# High Availability Information
# ============================================================================

output "multi_az" {
  description = "Whether Multi-AZ is enabled"
  value       = module.rds.db_instance_multi_az
}

output "availability_zone" {
  description = "Availability zone of the RDS instance"
  value       = module.rds.db_instance_availability_zone
}

# ============================================================================
# Backup Information
# ============================================================================

output "backup_retention_period" {
  description = "Backup retention period in days"
  value       = module.rds.db_instance_backup_retention_period
}

# ============================================================================
# Staging-Specific Information
# ============================================================================

output "restore_from_snapshot" {
  description = "Whether this instance was restored from a snapshot"
  value       = var.restore_from_snapshot
}

output "source_snapshot_id" {
  description = "Source snapshot ID if restored from snapshot"
  value       = var.restore_from_snapshot ? coalesce(var.snapshot_identifier, try(data.aws_db_snapshot.prod_latest[0].id, "N/A")) : "N/A"
}

# ============================================================================
# SSM Parameter Store Exports for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "db-instance-id" {
  name        = "/staging/rds/db-instance-id"
  description = "Staging RDS instance identifier for cross-stack references"
  type        = "String"
  value       = module.rds.db_instance_id

  tags = merge(
    local.required_tags,
    var.tags,
    {
      Name      = "staging-db-instance-id-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "db-instance-address" {
  name        = "/staging/rds/db-instance-address"
  description = "Staging RDS instance hostname for cross-stack references"
  type        = "String"
  value       = module.rds.db_instance_address

  tags = merge(
    local.required_tags,
    var.tags,
    {
      Name      = "staging-db-instance-address-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "db-instance-port" {
  name        = "/staging/rds/db-instance-port"
  description = "Staging RDS instance port for cross-stack references"
  type        = "String"
  value       = tostring(module.rds.db_instance_port)

  tags = merge(
    local.required_tags,
    var.tags,
    {
      Name      = "staging-db-instance-port-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "db-security-group-id" {
  name        = "/staging/rds/db-security-group-id"
  description = "Staging RDS security group ID for cross-stack references"
  type        = "String"
  value       = module.rds_security_group.security_group_id

  tags = merge(
    local.required_tags,
    var.tags,
    {
      Name      = "staging-db-security-group-id-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "master-password-secret-name" {
  name        = "/staging/rds/master-password-secret-name"
  description = "Staging RDS master password secret name for cross-stack references"
  type        = "String"
  value       = aws_secretsmanager_secret.db-master-password.name

  tags = merge(
    local.required_tags,
    var.tags,
    {
      Name      = "staging-master-password-secret-name-export"
      Component = "rds"
    }
  )
}
