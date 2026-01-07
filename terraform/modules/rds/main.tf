# Common Tags Module
module "tags" {
  source = "../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = var.additional_tags
}

locals {
  # Required tags for governance compliance
  required_tags = module.tags.tags
}

# DB Subnet Group
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    local.required_tags,
    {
      Name        = "${var.identifier}-subnet-group"
      Description = "DB subnet group for RDS instance ${var.identifier}"
    }
  )
}

# DB Parameter Group (optional)
resource "aws_db_parameter_group" "this" {
  count = var.parameter_group_family != null ? 1 : 0

  name   = "${var.identifier}-params"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "${var.identifier}-params"
      Description = "DB parameter group for RDS instance ${var.identifier}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Instance
resource "aws_db_instance" "this" {
  identifier = var.identifier

  # Snapshot Restore (when specified, engine/db_name/username/password are inherited from snapshot)
  snapshot_identifier = var.snapshot_identifier

  # Engine Configuration (ignored when restoring from snapshot)
  engine         = var.engine
  engine_version = var.snapshot_identifier != null ? null : var.engine_version
  instance_class = var.instance_class

  # Database Configuration (ignored when restoring from snapshot)
  db_name  = var.snapshot_identifier != null ? null : var.db_name
  username = var.snapshot_identifier != null ? null : var.master_username
  password = var.snapshot_identifier != null ? null : var.master_password
  port     = var.port

  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id
  iops                  = var.iops
  storage_throughput    = var.storage_throughput

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = var.publicly_accessible

  # Parameter Group
  parameter_group_name = var.parameter_group_family != null ? aws_db_parameter_group.this[0].name : null

  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : (
    var.final_snapshot_identifier != null ? var.final_snapshot_identifier : "${var.identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  )
  copy_tags_to_snapshot = var.copy_tags_to_snapshot

  # Maintenance Configuration
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  maintenance_window         = var.maintenance_window
  apply_immediately          = var.apply_immediately

  # High Availability
  multi_az = var.multi_az

  # Monitoring Configuration
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? var.monitoring_role_arn : null

  # Deletion Protection
  deletion_protection = var.deletion_protection

  # IAM Database Authentication
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  tags = merge(
    local.required_tags,
    {
      Name        = var.identifier
      Description = "RDS instance ${var.identifier} - ${var.engine} ${var.engine_version}"
    }
  )

  lifecycle {
    ignore_changes = [
      password,
      final_snapshot_identifier,
      # AWS Database Insights Advanced 모드에서 설정된 값은 콘솔에서만 변경 가능
      performance_insights_enabled,
      performance_insights_retention_period
    ]

    precondition {
      condition     = var.monitoring_interval == 0 || var.monitoring_role_arn != null
      error_message = "monitoring_role_arn must be provided when monitoring_interval is greater than 0"
    }

    precondition {
      condition     = var.storage_type != "io1" && var.storage_type != "io2" || var.iops != null
      error_message = "iops must be specified when storage_type is io1 or io2"
    }

    precondition {
      condition     = var.storage_type == "gp3" || var.storage_throughput == null
      error_message = "storage_throughput can only be specified for gp3 storage type"
    }

    precondition {
      condition     = var.performance_insights_enabled == false || contains(["mysql", "postgres", "mariadb", "oracle-se2", "oracle-se", "oracle-ee", "sqlserver-se", "sqlserver-ee"], var.engine)
      error_message = "Performance Insights is not supported for all engine types. Supported: mysql, postgres, mariadb, oracle-*, sqlserver-se, sqlserver-ee"
    }
  }
}
