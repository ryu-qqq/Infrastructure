# RDS MySQL Instance using rds module
# Supports fresh creation or restoration from prod snapshot

module "rds" {
  source = "../../../modules/rds"

  # Required variables
  identifier     = local.name_prefix
  engine         = "mysql"
  engine_version = var.mysql_version
  instance_class = var.instance_class

  # Snapshot Restore Configuration
  # When restoring from snapshot, db_name/username/password are inherited from snapshot
  snapshot_identifier = var.restore_from_snapshot ? coalesce(
    var.snapshot_identifier,
    try(data.aws_db_snapshot.prod_latest[0].id, null)
  ) : null

  # Database Configuration (only used when NOT restoring from snapshot)
  db_name         = var.database_name
  master_username = var.master_username
  master_password = random_password.master.result
  port            = var.port

  # Network Configuration
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [module.rds_security_group.security_group_id]

  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = aws_kms_key.rds.arn
  iops                  = var.iops

  # High Availability (disabled for staging)
  multi_az = var.enable_multi_az

  # Backup Configuration
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = local.final_snapshot_identifier
  copy_tags_to_snapshot     = var.copy_tags_to_snapshot

  # Maintenance
  auto_minor_version_upgrade = true
  maintenance_window         = var.maintenance_window
  apply_immediately          = true # Allow immediate changes for staging

  # Monitoring Configuration
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports
  monitoring_interval                   = var.enable_enhanced_monitoring ? var.monitoring_interval : 0
  monitoring_role_arn                   = var.enable_enhanced_monitoring ? module.rds_monitoring_role[0].role_arn : null
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention_period : null

  # Security (relaxed for staging)
  deletion_protection                 = var.enable_deletion_protection
  publicly_accessible                 = var.publicly_accessible
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  # Parameter Group
  parameter_group_family = var.parameter_group_family
  parameters             = var.parameters

  # Required tagging information
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class

  # Additional tags
  additional_tags = merge(
    var.tags,
    {
      RestoreFromSnapshot = var.restore_from_snapshot ? "true" : "false"
      SourceSnapshot      = var.restore_from_snapshot ? coalesce(var.snapshot_identifier, "prod-latest") : "N/A"
    }
  )
}
