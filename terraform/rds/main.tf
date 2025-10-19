# DB Subnet Group

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-subnet-group"
    }
  )
}

# DB Parameter Group

resource "aws_db_parameter_group" "main" {
  name   = "${local.name_prefix}-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-params"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS MySQL Instance

resource "aws_db_instance" "main" {
  # Instance Configuration
  identifier     = local.name_prefix
  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = var.instance_class

  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = data.aws_kms_key.rds.arn
  iops                  = var.iops

  # Database Configuration
  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result
  port     = var.port

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.main.name

  # High Availability
  multi_az = var.enable_multi_az

  # Backup Configuration
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_identifier
  copy_tags_to_snapshot     = var.copy_tags_to_snapshot

  # Monitoring Configuration
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.enable_enhanced_monitoring ? var.monitoring_interval : 0
  monitoring_role_arn             = var.enable_enhanced_monitoring ? aws_iam_role.rds_monitoring[0].arn : null

  # Performance Insights
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_kms_key_id       = var.enable_performance_insights ? data.aws_kms_key.rds.arn : null
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention_period : null

  # Security
  deletion_protection = var.enable_deletion_protection

  # Auto Minor Version Upgrade
  auto_minor_version_upgrade = true

  # Apply changes immediately (운영 환경에서는 false 권장)
  apply_immediately = false

  tags = merge(
    local.common_tags,
    {
      Name = local.name_prefix
    }
  )

  lifecycle {
    ignore_changes = [
      # 비밀번호는 한 번 설정 후 변경하지 않음
      password,
      # 최종 스냅샷 식별자는 타임스탬프를 포함하므로 무시
      final_snapshot_identifier
    ]
  }

  depends_on = [
    aws_db_subnet_group.main,
    aws_db_parameter_group.main,
    aws_security_group.rds
  ]
}
