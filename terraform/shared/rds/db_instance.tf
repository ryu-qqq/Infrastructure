# ============================================================================
# RDS Database Instance
# ============================================================================

resource "aws_db_instance" "main" {
  # Basic configuration
  identifier     = var.db_identifier
  db_name        = var.db_name
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Storage configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id
  iops                  = var.storage_type == "gp3" || var.storage_type == "io1" ? var.iops : null
  storage_throughput    = var.storage_type == "gp3" ? var.storage_throughput : null

  # Credentials (use AWS Secrets Manager)
  username                    = "admin"
  manage_master_user_password = true
  iam_database_authentication_enabled = true

  # Network configuration
  db_subnet_group_name   = "prod-shared-mysql-subnet-group"  # 기존 리소스 직접 참조 (import 불가)
  vpc_security_group_ids = [aws_security_group.main.id]
  publicly_accessible    = var.publicly_accessible
  port                   = local.db_port

  # High availability
  multi_az = var.multi_az

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true
  deletion_protection     = var.deletion_protection

  # Parameter and option groups
  parameter_group_name = "prod-shared-mysql-params"  # 기존 리소스 직접 참조 (import 불가)

  # Monitoring
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.kms_key_id : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  # Upgrades
  auto_minor_version_upgrade = true
  apply_immediately          = false

  tags = merge(
    local.required_tags,
    {
      Name      = var.db_identifier
      Component = "database"
    }
  )

  # Import된 리소스 - 기존 태그 및 설정 보존
  lifecycle {
    ignore_changes = [
      tags,
      master_user_secret,      # Import 시 비밀번호 관련
      latest_restorable_time,  # 자동 업데이트되는 속성
      username,                # 기존 사용자명 보존
      manage_master_user_password,  # 기존 비밀번호 관리 방식 보존
      db_subnet_group_name,    # 기존 Subnet Group 사용 (import 불가)
      parameter_group_name     # 기존 Parameter Group 사용 (import 불가)
    ]
  }
}
