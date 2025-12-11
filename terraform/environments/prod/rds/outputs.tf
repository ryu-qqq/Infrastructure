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

output "db_parameter_group_name" {
  description = "DB parameter group name"
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

# Deprecated: Use master_password_secret_* outputs instead
# Kept for backward compatibility during migration
output "connection_secret_arn" {
  description = "[DEPRECATED] Use master_password_secret_arn - same secret contains all connection info"
  value       = aws_secretsmanager_secret.db-master-password.arn
}

output "connection_secret_name" {
  description = "[DEPRECATED] Use master_password_secret_name - same secret contains all connection info"
  value       = aws_secretsmanager_secret.db-master-password.name
}

# ============================================================================
# Application User Secrets - setof
# ============================================================================

output "setof_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing setof user credentials"
  value       = aws_secretsmanager_secret.db-setof-password.arn
}

output "setof_password_secret_name" {
  description = "Name of the Secrets Manager secret containing setof user credentials"
  value       = aws_secretsmanager_secret.db-setof-password.name
}

# ============================================================================
# Application User Secrets - auth
# ============================================================================

output "auth_password_secret_arn" {
  description = "ARN of the Secrets Manager secret containing auth user credentials"
  value       = aws_secretsmanager_secret.db-auth-password.arn
}

output "auth_password_secret_name" {
  description = "Name of the Secrets Manager secret containing auth user credentials"
  value       = aws_secretsmanager_secret.db-auth-password.name
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

output "backup_window" {
  description = "Backup window"
  value       = module.rds.db_instance_backup_window
}

output "maintenance_window" {
  description = "Maintenance window"
  value       = module.rds.db_instance_maintenance_window
}

# ============================================================================
# Storage Information
# ============================================================================

output "allocated_storage" {
  description = "Allocated storage in GB"
  value       = module.rds.db_instance_allocated_storage
}

output "max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  value       = var.max_allocated_storage
}

output "storage_type" {
  description = "Storage type"
  value       = module.rds.db_instance_storage_type
}

output "storage_encrypted" {
  description = "Whether storage is encrypted"
  value       = module.rds.db_instance_storage_encrypted
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = module.rds.db_instance_kms_key_id
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
  value       = "mysql://${module.rds.db_instance_username}:<password>@${module.rds.db_instance_address}:${module.rds.db_instance_port}/${module.rds.db_instance_name}"
}

# ============================================================================
# SSM Parameter Store Exports for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "db-instance-id" {
  name        = "/shared/rds/db-instance-id"
  description = "RDS instance identifier for cross-stack references"
  type        = "String"
  value       = module.rds.db_instance_id

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name      = "db-instance-id-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "db-instance-address" {
  name        = "/shared/rds/db-instance-address"
  description = "RDS instance hostname for cross-stack references"
  type        = "String"
  value       = module.rds.db_instance_address

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name      = "db-instance-address-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "db-instance-port" {
  name        = "/shared/rds/db-instance-port"
  description = "RDS instance port for cross-stack references"
  type        = "String"
  value       = tostring(module.rds.db_instance_port)

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name      = "db-instance-port-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "db-security-group-id" {
  name        = "/shared/rds/db-security-group-id"
  description = "RDS security group ID for cross-stack references"
  type        = "String"
  value       = module.rds_security_group.security_group_id

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name      = "db-security-group-id-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "master-password-secret-name" {
  name        = "/shared/rds/master-password-secret-name"
  description = "RDS master password secret name for cross-stack references"
  type        = "String"
  value       = aws_secretsmanager_secret.db-master-password.name

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name      = "master-password-secret-name-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "setof-password-secret-name" {
  name        = "/shared/rds/setof-password-secret-name"
  description = "RDS setof user password secret name for cross-stack references"
  type        = "String"
  value       = aws_secretsmanager_secret.db-setof-password.name

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name      = "setof-password-secret-name-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "auth-password-secret-name" {
  name        = "/shared/rds/auth-password-secret-name"
  description = "RDS auth user password secret name for cross-stack references"
  type        = "String"
  value       = aws_secretsmanager_secret.db-auth-password.name

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name      = "auth-password-secret-name-export"
      Component = "rds"
    }
  )
}
