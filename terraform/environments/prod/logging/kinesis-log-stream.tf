# ============================================================================
# Kinesis Data Streams Log Routing System
# CloudWatch Logs → Kinesis Data Streams → Lambda → OpenSearch (Bulk API)
# ============================================================================

# ============================================================================
# Kinesis Data Stream
# ============================================================================

resource "aws_kinesis_stream" "logs" {
  name = "${var.environment}-cloudwatch-logs"

  stream_mode_details {
    stream_mode = "ON_DEMAND" # 자동 스케일링, 샤드 관리 불필요
  }

  encryption_type = "KMS"
  kms_key_id      = local.kms_key_arn

  retention_period = 24 # 시간 (기본값: 24시간)

  tags = merge(local.common_tags, {
    Name      = "${var.environment}-cloudwatch-logs"
    Component = "log-routing"
  })
}

# ============================================================================
# DLQ (SQS) for Failed Records
# ============================================================================

resource "aws_sqs_queue" "log_router_dlq" {
  name = "${var.environment}-log-router-dlq"

  message_retention_seconds  = 1209600 # 14일
  visibility_timeout_seconds = 300
  receive_wait_time_seconds  = 20

  kms_master_key_id = local.kms_key_arn

  tags = merge(local.common_tags, {
    Name      = "${var.environment}-log-router-dlq"
    Component = "log-routing"
  })
}

# ============================================================================
# Lambda Function: Log Router
# ============================================================================

data "archive_file" "log_router" {
  type        = "zip"
  source_dir  = "${path.module}/../../../../lambda/log-router"
  output_path = "${path.module}/log-router.zip"
}

resource "aws_lambda_function" "log_router" {
  function_name    = "${var.environment}-log-router"
  role             = aws_iam_role.log_router.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.11"
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.log_router.output_path
  source_code_hash = data.archive_file.log_router.output_base64sha256

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = data.aws_opensearch_domain.logs[0].endpoint
      INDEX_PREFIX        = var.opensearch_index_prefix
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.log_router_dlq.arn
  }

  tags = merge(local.common_tags, {
    Name      = "${var.environment}-log-router"
    Component = "log-routing"
  })

  # IAM 정책이 완전히 전파될 때까지 대기
  depends_on = [aws_iam_role_policy.log_router]
}

# Lambda CloudWatch Log Group
resource "aws_cloudwatch_log_group" "log_router" {
  name              = "/aws/lambda/${var.environment}-log-router"
  retention_in_days = 14
  kms_key_id        = local.kms_key_arn

  tags = merge(local.common_tags, {
    Name      = "log-router-logs"
    Component = "log-routing"
  })
}

# ============================================================================
# IAM Role for Lambda (Log Router)
# ============================================================================

resource "aws_iam_role" "log_router" {
  name = "${var.environment}-log-router-role"

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
    Name      = "${var.environment}-log-router-role"
    Component = "log-routing"
  })
}

resource "aws_iam_role_policy" "log_router" {
  name = "${var.environment}-log-router-policy"
  role = aws_iam_role.log_router.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KinesisAccess"
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:ListShards",
          "kinesis:ListStreams"
        ]
        Resource = aws_kinesis_stream.logs.arn
      },
      {
        Sid    = "OpenSearchAccess"
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpGet"
        ]
        Resource = [
          data.aws_opensearch_domain.logs[0].arn,
          "${data.aws_opensearch_domain.logs[0].arn}/*"
        ]
      },
      {
        Sid    = "SQSDLQAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.log_router_dlq.arn
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.environment}-log-router:*"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.kms_key_arn
      }
    ]
  })
}

# ============================================================================
# Kinesis → Lambda Event Source Mapping
# ============================================================================

resource "aws_lambda_event_source_mapping" "kinesis_to_log_router" {
  event_source_arn  = aws_kinesis_stream.logs.arn
  function_name     = aws_lambda_function.log_router.arn
  starting_position = "LATEST"

  batch_size                         = 100
  maximum_batching_window_in_seconds = 5
  parallelization_factor             = 2

  # 실패 시 재시도 설정
  maximum_retry_attempts        = 3
  maximum_record_age_in_seconds = 3600 # 1시간

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.log_router_dlq.arn
    }
  }
}

# ============================================================================
# IAM Role for CloudWatch Logs → Kinesis
# ============================================================================

resource "aws_iam_role" "cloudwatch_to_kinesis" {
  name = "${var.environment}-${var.service_name}-cloudwatch-to-kinesis-role"

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
    Name      = "${var.environment}-${var.service_name}-cloudwatch-to-kinesis-role"
    Component = "log-routing"
  })
}

resource "aws_iam_role_policy" "cloudwatch_to_kinesis" {
  name = "${var.environment}-${var.service_name}-cloudwatch-to-kinesis-policy"
  role = aws_iam_role.cloudwatch_to_kinesis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KinesisPutRecord"
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.logs.arn
      },
      {
        Sid    = "KMSEncrypt"
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey"
        ]
        Resource = local.kms_key_arn
      }
    ]
  })
}

# ============================================================================
# CloudWatch Logs Subscription Filters → Kinesis
# ============================================================================

# Atlantis Production Application Logs → Kinesis
resource "aws_cloudwatch_log_subscription_filter" "atlantis_prod_to_kinesis" {
  name            = "atlantis-prod-to-kinesis"
  log_group_name  = "/aws/ecs/atlantis-prod/application"
  filter_pattern  = var.log_filter_pattern
  destination_arn = aws_kinesis_stream.logs.arn
  role_arn        = aws_iam_role.cloudwatch_to_kinesis.arn
}

# Atlantis Application Logs (centralized) → Kinesis
resource "aws_cloudwatch_log_subscription_filter" "atlantis_application_to_kinesis" {
  name            = "atlantis-application-to-kinesis"
  log_group_name  = module.atlantis_application_logs.log_group_name
  filter_pattern  = var.log_filter_pattern
  destination_arn = aws_kinesis_stream.logs.arn
  role_arn        = aws_iam_role.cloudwatch_to_kinesis.arn
}

# Atlantis Error Logs → Kinesis
resource "aws_cloudwatch_log_subscription_filter" "atlantis_errors_to_kinesis" {
  name            = "atlantis-errors-to-kinesis"
  log_group_name  = module.atlantis_error_logs.log_group_name
  filter_pattern  = var.log_filter_pattern
  destination_arn = aws_kinesis_stream.logs.arn
  role_arn        = aws_iam_role.cloudwatch_to_kinesis.arn
}

# ============================================================================
# SSM Parameters for Cross-Stack Reference
# ============================================================================

resource "aws_ssm_parameter" "kinesis_stream_arn" {
  name  = "/shared/logging/kinesis-stream-arn"
  type  = "String"
  value = aws_kinesis_stream.logs.arn

  tags = merge(local.common_tags, {
    Name      = "kinesis-stream-arn"
    Component = "log-routing"
  })
}

resource "aws_ssm_parameter" "cloudwatch_to_kinesis_role_arn" {
  name  = "/shared/logging/cloudwatch-to-kinesis-role-arn"
  type  = "String"
  value = aws_iam_role.cloudwatch_to_kinesis.arn

  tags = merge(local.common_tags, {
    Name      = "cloudwatch-to-kinesis-role-arn"
    Component = "log-routing"
  })
}
