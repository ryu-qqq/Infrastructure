# ============================================================================
# Log Streaming System
# CloudWatch Logs → Kinesis Firehose → OpenSearch (+ S3 backup)
# ============================================================================

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# OpenSearch domain reference (existing)
data "aws_opensearch_domain" "logs" {
  count       = var.enable_log_streaming ? 1 : 0
  domain_name = var.opensearch_domain_name
}

# ============================================================================
# S3 Bucket for Firehose Backup
# ============================================================================

module "firehose_backup_bucket" {
  count  = var.enable_log_streaming ? 1 : 0
  source = "../../../modules/s3-bucket"

  bucket_name = "${var.environment}-log-firehose-backup-${data.aws_caller_identity.current.account_id}"

  # Lifecycle rules for cost optimization
  lifecycle_rules = [
    {
      id                         = "archive-and-expire"
      enabled                    = true
      transition_to_ia_days      = 30
      transition_to_glacier_days = 90
      expiration_days            = 365
    }
  ]

  # Required tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class
}

# ============================================================================
# IAM Role for Kinesis Firehose
# ============================================================================

resource "aws_iam_role" "firehose-opensearch" {
  count = var.enable_log_streaming ? 1 : 0
  name  = "${var.environment}-${var.service_name}-firehose-opensearch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name      = "${var.environment}-${var.service_name}-firehose-opensearch-role"
    Component = "log-streaming"
  })
}

resource "aws_iam_role_policy" "firehose-opensearch" {
  count = var.enable_log_streaming ? 1 : 0
  name  = "${var.environment}-${var.service_name}-firehose-opensearch-policy"
  role  = aws_iam_role.firehose-opensearch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OpenSearchAccess"
        Effect = "Allow"
        Action = [
          "es:DescribeElasticsearchDomain",
          "es:DescribeElasticsearchDomains",
          "es:DescribeElasticsearchDomainConfig",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet",
          "es:ESHttpHead"
        ]
        Resource = [
          data.aws_opensearch_domain.logs[0].arn,
          "${data.aws_opensearch_domain.logs[0].arn}/*"
        ]
      },
      {
        Sid    = "S3BackupAccess"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          module.firehose_backup_bucket[0].bucket_arn,
          "${module.firehose_backup_bucket[0].bucket_arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesisfirehose/*"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.kms_key_arn
      },
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:GetFunctionConfiguration"
        ]
        Resource = aws_lambda_function.log-transformer[0].arn
      }
    ]
  })
}

# ============================================================================
# Kinesis Firehose Delivery Stream
# ============================================================================

resource "aws_cloudwatch_log_group" "firehose-errors" {
  count             = var.enable_log_streaming ? 1 : 0
  name              = "/aws/kinesisfirehose/${var.environment}-logs-to-opensearch"
  retention_in_days = 14
  kms_key_id        = local.kms_key_arn

  tags = merge(local.common_tags, {
    Name      = "firehose-errors-log-group"
    Component = "log-streaming"
  })
}

resource "aws_cloudwatch_log_stream" "firehose-errors" {
  count          = var.enable_log_streaming ? 1 : 0
  name           = "DestinationDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose-errors[0].name
}

resource "aws_kinesis_firehose_delivery_stream" "logs-to-opensearch" {
  count       = var.enable_log_streaming ? 1 : 0
  name        = "${var.environment}-logs-to-opensearch"
  destination = "opensearch"

  opensearch_configuration {
    domain_arn            = data.aws_opensearch_domain.logs[0].arn
    role_arn              = aws_iam_role.firehose-opensearch[0].arn
    index_name            = var.opensearch_index_name
    index_rotation_period = "OneDay"
    buffering_interval    = 60
    buffering_size        = 5
    retry_duration        = 300

    s3_backup_mode = "FailedDocumentsOnly"

    s3_configuration {
      role_arn           = aws_iam_role.firehose-opensearch[0].arn
      bucket_arn         = module.firehose_backup_bucket[0].bucket_arn
      prefix             = "failed-logs/"
      error_output_prefix = "errors/"
      buffering_size     = 10
      buffering_interval = 400
      compression_format = "GZIP"
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose-errors[0].name
      log_stream_name = aws_cloudwatch_log_stream.firehose-errors[0].name
    }

    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.log-transformer[0].arn
        }
        parameters {
          parameter_name  = "BufferSizeInMBs"
          parameter_value = "1"
        }
        parameters {
          parameter_name  = "BufferIntervalInSeconds"
          parameter_value = "60"
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name      = "${var.environment}-logs-to-opensearch"
    Component = "log-streaming"
  })
}

# ============================================================================
# Lambda for Log Transformation
# ============================================================================

data "archive_file" "log-transformer" {
  count       = var.enable_log_streaming ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../../../lambda/log-transformer"
  output_path = "${path.module}/log-transformer.zip"
}

resource "aws_lambda_function" "log-transformer" {
  count            = var.enable_log_streaming ? 1 : 0
  function_name    = "${var.environment}-log-transformer"
  role             = aws_iam_role.log-transformer[0].arn
  handler          = "lambda_function.handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 128
  filename         = data.archive_file.log-transformer[0].output_path
  source_code_hash = data.archive_file.log-transformer[0].output_base64sha256

  tags = merge(local.common_tags, {
    Name      = "${var.environment}-log-transformer"
    Component = "log-streaming"
  })
}

resource "aws_iam_role" "log-transformer" {
  count = var.enable_log_streaming ? 1 : 0
  name  = "${var.environment}-log-transformer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name      = "${var.environment}-log-transformer-role"
    Component = "log-streaming"
  })
}

resource "aws_iam_role_policy_attachment" "log-transformer-basic" {
  count      = var.enable_log_streaming ? 1 : 0
  role       = aws_iam_role.log-transformer[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "firehose-invoke" {
  count         = var.enable_log_streaming ? 1 : 0
  statement_id  = "AllowFirehoseInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log-transformer[0].function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.logs-to-opensearch[0].arn
}

# ============================================================================
# IAM Role for CloudWatch Logs Subscription
# ============================================================================

resource "aws_iam_role" "cloudwatch-to-firehose" {
  count = var.enable_log_streaming ? 1 : 0
  name  = "${var.environment}-${var.service_name}-cloudwatch-to-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name      = "${var.environment}-${var.service_name}-cloudwatch-to-firehose-role"
    Component = "log-streaming"
  })
}

resource "aws_iam_role_policy" "cloudwatch-to-firehose" {
  count = var.enable_log_streaming ? 1 : 0
  name  = "${var.environment}-${var.service_name}-cloudwatch-to-firehose-policy"
  role  = aws_iam_role.cloudwatch-to-firehose[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.logs-to-opensearch[0].arn
      }
    ]
  })
}

# ============================================================================
# CloudWatch Logs Subscription Filters
# ============================================================================

# Atlantis Production Application Logs → OpenSearch (existing log group with actual logs)
resource "aws_cloudwatch_log_subscription_filter" "atlantis-prod-application" {
  count           = var.enable_log_streaming ? 1 : 0
  name            = "atlantis-prod-application-to-opensearch"
  log_group_name  = "/aws/ecs/atlantis-prod/application"
  filter_pattern  = var.log_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.logs-to-opensearch[0].arn
  role_arn        = aws_iam_role.cloudwatch-to-firehose[0].arn
}

# Atlantis Application Logs → OpenSearch (new centralized log group)
resource "aws_cloudwatch_log_subscription_filter" "atlantis-application" {
  count           = var.enable_log_streaming ? 1 : 0
  name            = "atlantis-application-to-opensearch"
  log_group_name  = module.atlantis-application_logs.log_group_name
  filter_pattern  = var.log_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.logs-to-opensearch[0].arn
  role_arn        = aws_iam_role.cloudwatch-to-firehose[0].arn
}

# Atlantis Error Logs → OpenSearch
resource "aws_cloudwatch_log_subscription_filter" "atlantis-errors" {
  count           = var.enable_log_streaming ? 1 : 0
  name            = "atlantis-errors-to-opensearch"
  log_group_name  = module.atlantis_error_logs.log_group_name
  filter_pattern  = var.log_filter_pattern
  destination_arn = aws_kinesis_firehose_delivery_stream.logs-to-opensearch[0].arn
  role_arn        = aws_iam_role.cloudwatch-to-firehose[0].arn
}

# ============================================================================
# SSM Parameters for Cross-Stack Reference
# ============================================================================

resource "aws_ssm_parameter" "firehose-arn" {
  count = var.enable_log_streaming ? 1 : 0
  name  = "/shared/logging/firehose-arn"
  type  = "String"
  value = aws_kinesis_firehose_delivery_stream.logs-to-opensearch[0].arn

  tags = merge(local.common_tags, {
    Name      = "firehose-arn"
    Component = "log-streaming"
  })
}

resource "aws_ssm_parameter" "cloudwatch-to-firehose-role-arn" {
  count = var.enable_log_streaming ? 1 : 0
  name  = "/shared/logging/cloudwatch-to-firehose-role-arn"
  type  = "String"
  value = aws_iam_role.cloudwatch-to-firehose[0].arn

  tags = merge(local.common_tags, {
    Name      = "cloudwatch-to-firehose-role-arn"
    Component = "log-streaming"
  })
}
