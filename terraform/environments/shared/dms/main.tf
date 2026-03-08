# ============================================================================
# DMS Replication: Prod RDS → Stage RDS (luxurydb schema)
# ============================================================================

locals {
  name_prefix = "prod-to-stage-dms"
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# KMS Key for DMS encryption
# ============================================================================

resource "aws_kms_key" "dms" {
  description             = "KMS key for DMS replication encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 14
}

resource "aws_kms_alias" "dms" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.dms.key_id
}

# ============================================================================
# IAM Role for DMS
# ============================================================================

resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_vpc_management" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_iam_role" "dms_cloudwatch_role" {
  name = "dms-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch" {
  role       = aws_iam_role.dms_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# Secrets Manager access for DMS endpoints
resource "aws_iam_role" "dms_secrets_access" {
  name = "${local.name_prefix}-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.${data.aws_region.current.name}.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "dms_secrets_policy" {
  name = "${local.name_prefix}-secrets-policy"
  role = aws_iam_role.dms_secrets_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.source_secrets_manager_arn,
          var.target_secrets_manager_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# ============================================================================
# Security Group for DMS Replication Instance
# ============================================================================

resource "aws_security_group" "dms" {
  name_prefix = "${local.name_prefix}-sg-"
  description = "Security group for DMS replication instance"
  vpc_id      = var.vpc_id

  # Outbound to source RDS (Prod)
  egress {
    description     = "Access to source Prod RDS"
    from_port       = var.source_db_port
    to_port         = var.source_db_port
    protocol        = "tcp"
    security_groups = [var.source_security_group_id]
  }

  # Outbound to target RDS (Stage)
  egress {
    description     = "Access to target Stage RDS"
    from_port       = var.target_db_port
    to_port         = var.target_db_port
    protocol        = "tcp"
    security_groups = [var.target_security_group_id]
  }

  # HTTPS outbound for AWS API calls
  egress {
    description = "HTTPS for AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================================================
# Ingress rules on RDS security groups to allow DMS access
# ============================================================================

resource "aws_security_group_rule" "dms_to_source_rds" {
  type                     = "ingress"
  from_port                = var.source_db_port
  to_port                  = var.source_db_port
  protocol                 = "tcp"
  description              = "Allow DMS replication instance to access source Prod RDS"
  security_group_id        = var.source_security_group_id
  source_security_group_id = aws_security_group.dms.id
}

resource "aws_security_group_rule" "dms_to_target_rds" {
  type                     = "ingress"
  from_port                = var.target_db_port
  to_port                  = var.target_db_port
  protocol                 = "tcp"
  description              = "Allow DMS replication instance to access target Stage RDS"
  security_group_id        = var.target_security_group_id
  source_security_group_id = aws_security_group.dms.id
}

# ============================================================================
# DMS Subnet Group
# ============================================================================

resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = local.name_prefix
  replication_subnet_group_description = "DMS subnet group for prod-to-stage replication"
  subnet_ids                           = var.private_subnet_ids

  depends_on = [aws_iam_role_policy_attachment.dms_vpc_management]
}

# ============================================================================
# DMS Replication Instance
# ============================================================================

resource "aws_dms_replication_instance" "main" {
  replication_instance_id    = local.name_prefix
  replication_instance_class = var.replication_instance_class
  allocated_storage          = var.allocated_storage
  kms_key_arn                = aws_kms_key.dms.arn

  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  multi_az                   = false
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_management,
    aws_iam_role_policy_attachment.dms_cloudwatch,
  ]
}

# ============================================================================
# DMS Source Endpoint (Prod RDS)
# ============================================================================

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${local.name_prefix}-source-prod"
  endpoint_type = "source"
  engine_name   = "mysql"

  secrets_manager_access_role_arn = aws_iam_role.dms_secrets_access.arn
  secrets_manager_arn             = var.source_secrets_manager_arn

  ssl_mode = "none"
}

# ============================================================================
# DMS Target Endpoint (Stage RDS - direct, not proxy)
# ============================================================================

resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${local.name_prefix}-target-stage"
  endpoint_type = "target"
  engine_name   = "mysql"

  secrets_manager_access_role_arn = aws_iam_role.dms_secrets_access.arn
  secrets_manager_arn             = var.target_secrets_manager_arn

  ssl_mode = "none"
}

# ============================================================================
# DMS Replication Task
# ============================================================================

resource "aws_dms_replication_task" "luxurydb" {
  replication_task_id      = "${local.name_prefix}-luxurydb"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  migration_type = var.migration_type

  table_mappings = jsonencode({
    rules = [
      {
        rule-type   = "selection"
        rule-id     = "1"
        rule-name   = "select-luxurydb"
        rule-action = "include"
        object-locator = {
          schema-name = var.schema_name
          table-name  = "%"
        }
      }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema           = ""
      SupportLobs            = true
      FullLobMode            = false
      LobChunkSize           = 64
      LimitedSizeLobMode     = true
      LobMaxSize             = 32
      InlineLobMaxSize       = 0
      LoadMaxFileSize        = 0
      ParallelLoadThreads    = 0
      ParallelLoadBufferSize = 0
      BatchApplyEnabled      = false
    }
    FullLoadSettings = {
      TargetTablePrepMode             = "DROP_AND_CREATE"
      CreatePkAfterFullLoad           = false
      StopTaskCachedChangesApplied    = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks             = 8
      TransactionConsistencyTimeout   = 600
      CommitRate                      = 10000
    }
    Logging = {
      EnableLogging = true
      LogComponents = [
        {
          Id       = "TRANSFORMATION"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SOURCE_UNLOAD"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "IO"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TARGET_LOAD"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "PERFORMANCE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SOURCE_CAPTURE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SORTER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "REST_SERVER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "VALIDATOR_EXT"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TARGET_APPLY"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TASK_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TABLES_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "METADATA_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "FILE_FACTORY"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "COMMON"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "ADDONS"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "DATA_STRUCTURE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "COMMUNICATION"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "FILE_TRANSFER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        }
      ]
    }
    ControlTablesSettings = {
      historyTimeslotInMinutes    = 5
      ControlSchema               = ""
      HistoryTimeslotInMinutes    = 5
      HistoryTableEnabled         = false
      SuspendedTablesTableEnabled = false
      StatusTableEnabled          = false
    }
    StreamBufferSettings = {
      StreamBufferCount        = 3
      StreamBufferSizeInMB     = 8
      CtrlStreamBufferSizeInMB = 5
    }
    ChangeProcessingDdlHandlingPolicy = {
      HandleSourceTableDropped   = true
      HandleSourceTableTruncated = true
      HandleSourceTableAltered   = true
    }
    ErrorBehavior = {
      DataErrorPolicy                             = "LOG_ERROR"
      DataTruncationErrorPolicy                   = "LOG_ERROR"
      DataErrorEscalationPolicy                   = "SUSPEND_TABLE"
      DataErrorEscalationCount                    = 0
      TableErrorPolicy                            = "SUSPEND_TABLE"
      TableErrorEscalationPolicy                  = "STOP_TASK"
      TableErrorEscalationCount                   = 0
      RecoverableErrorCount                       = -1
      RecoverableErrorInterval                    = 5
      RecoverableErrorThrottling                  = true
      RecoverableErrorThrottlingMax               = 1800
      RecoverableErrorStopRetryAfterThrottlingMax = true
      ApplyErrorDeletePolicy                      = "IGNORE_RECORD"
      ApplyErrorInsertPolicy                      = "LOG_ERROR"
      ApplyErrorUpdatePolicy                      = "LOG_ERROR"
      ApplyErrorEscalationPolicy                  = "LOG_ERROR"
      ApplyErrorEscalationCount                   = 0
      ApplyErrorFailOnTruncationDdl               = false
      FullLoadIgnoreConflicts                     = true
      FailOnTransactionConsistencyBreached        = false
      FailOnNoTablesCaptured                      = true
    }
    ChangeProcessingTuning = {
      BatchApplyPreserveTransaction = true
      BatchApplyTimeoutMin          = 1
      BatchApplyTimeoutMax          = 30
      BatchApplyMemoryLimit         = 500
      BatchSplitSize                = 0
      MinTransactionSize            = 1000
      CommitTimeout                 = 1
      MemoryLimitTotal              = 1024
      MemoryKeepTime                = 60
      StatementCacheSize            = 50
    }
  })

  start_replication_task = false
}
