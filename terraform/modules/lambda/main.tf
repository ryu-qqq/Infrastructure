# Lambda Function Module
# Creates AWS Lambda function with IAM role, VPC config, CloudWatch Logs, DLQ, and versioning support

locals {
  required_tags = {
    Environment = var.environment
    Service     = var.service
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
    Project     = var.project
  }

  # Lambda function name with naming convention
  function_name = var.function_name != "" ? var.function_name : "${var.service}-${var.environment}-${var.name}"
}

# Validate deployment source configuration
check "deployment_source_exclusive" {
  assert {
    condition     = var.filename == null || var.s3_bucket == null
    error_message = "'filename' (for local file) and 's3_bucket' (for S3) are mutually exclusive. Please specify only one deployment method."
  }
}

check "local_deployment_requires_hash" {
  assert {
    condition     = var.filename == null || var.source_code_hash != null
    error_message = "When using 'filename' for local deployment, 'source_code_hash' must also be provided to track changes."
  }
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda" {
  count = var.create_role ? 1 : 0

  name        = "${local.function_name}-role"
  description = "IAM role for Lambda function ${local.function_name}"

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

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.function_name}-role"
      Component = "iam-role"
    }
  )
}

# Attach AWS Managed Policy for VPC execution (if VPC config is provided)
resource "aws_iam_role_policy_attachment" "vpc-execution" {
  count = var.create_role && var.vpc_config != null ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Attach AWS Managed Policy for basic execution
resource "aws_iam_role_policy_attachment" "basic-execution" {
  count = var.create_role ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach additional custom policies
resource "aws_iam_role_policy_attachment" "custom" {
  for_each = var.create_role ? var.custom_policy_arns : {}

  role       = aws_iam_role.lambda[0].name
  policy_arn = each.value
}

# Inline policy for custom permissions
resource "aws_iam_role_policy" "inline" {
  count = var.create_role && var.inline_policy != null ? 1 : 0

  name   = "${local.function_name}-inline-policy"
  role   = aws_iam_role.lambda[0].id
  policy = var.inline_policy
}

# IAM Policy for DLQ access
resource "aws_iam_policy" "dlq" {
  count = var.create_dlq && var.create_role ? 1 : 0

  name        = "${local.function_name}-dlq-policy"
  description = "Allow Lambda to send messages to the SQS DLQ"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.dlq[0].arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.function_name}-dlq-policy"
      Component = "iam-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "dlq" {
  count = var.create_dlq && var.create_role ? 1 : 0

  role       = aws_iam_role.lambda[0].name
  policy_arn = aws_iam_policy.dlq[0].arn
}

# CloudWatch Log Group with KMS encryption
resource "aws_cloudwatch_log_group" "lambda" {
  count = var.create_log_group ? 1 : 0

  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_id

  tags = merge(
    local.required_tags,
    {
      Name          = "/aws/lambda/${local.function_name}"
      LogType       = "lambda"
      RetentionDays = tostring(var.log_retention_days)
      KMSEncrypted  = var.log_kms_key_id != null ? "true" : "false"
    }
  )
}

# Dead Letter Queue (SQS)
resource "aws_sqs_queue" "dlq" {
  count = var.create_dlq ? 1 : 0

  name                       = "${local.function_name}-dlq"
  message_retention_seconds  = var.dlq_message_retention_seconds
  visibility_timeout_seconds = var.dlq_visibility_timeout_seconds
  kms_master_key_id          = var.dlq_kms_key_id

  tags = merge(
    local.required_tags,
    {
      Name         = "${local.function_name}-dlq"
      Component    = "dead-letter-queue"
      KMSEncrypted = var.dlq_kms_key_id != null ? "true" : "false"
    }
  )
}

# Lambda Function
resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = var.description
  role          = var.create_role ? aws_iam_role.lambda[0].arn : var.lambda_role_arn

  # Code deployment
  filename          = var.filename
  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version
  source_code_hash  = var.source_code_hash

  lifecycle {
    precondition {
      condition     = var.create_role || var.lambda_role_arn != null
      error_message = "When create_role is false, a valid lambda_role_arn must be provided."
    }

    precondition {
      condition     = var.filename != null || (var.s3_bucket != null && var.s3_key != null)
      error_message = "Either 'filename' or both 's3_bucket' and 's3_key' must be provided for the Lambda function's source code."
    }
  }

  # Runtime configuration
  handler       = var.handler
  runtime       = var.runtime
  architectures = var.architectures
  timeout       = var.timeout
  memory_size   = var.memory_size

  # Reserved concurrent executions
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Environment variables
  dynamic "environment" {
    for_each = var.environment_variables != null ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # Dead Letter Queue configuration
  dynamic "dead_letter_config" {
    for_each = var.create_dlq ? [1] : []
    content {
      target_arn = aws_sqs_queue.dlq[0].arn
    }
  }

  # Tracing configuration
  dynamic "tracing_config" {
    for_each = var.tracing_mode != null ? [1] : []
    content {
      mode = var.tracing_mode
    }
  }

  # Ephemeral storage
  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size != null ? [1] : []
    content {
      size = var.ephemeral_storage_size
    }
  }

  # Layers
  layers = var.layers

  # Publish version
  publish = var.publish

  tags = merge(
    local.required_tags,
    {
      Name       = local.function_name
      Runtime    = var.runtime
      Handler    = var.handler
      MemorySize = tostring(var.memory_size)
      Timeout    = tostring(var.timeout)
    },
    var.additional_tags
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic-execution,
    aws_iam_role_policy_attachment.vpc-execution,
    aws_iam_role_policy_attachment.dlq,
  ]
}

# Lambda Function Alias
resource "aws_lambda_alias" "this" {
  for_each = var.aliases

  name             = each.key
  description      = each.value.description
  function_name    = aws_lambda_function.this.arn
  function_version = each.value.function_version

  # Routing configuration for weighted aliases
  dynamic "routing_config" {
    for_each = each.value.routing_config != null ? [each.value.routing_config] : []
    content {
      additional_version_weights = routing_config.value.additional_version_weights
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name            = "${local.function_name}-${each.key}"
      AliasName       = each.key
      FunctionName    = local.function_name
      FunctionVersion = each.value.function_version
    }
  )
}

# Lambda Permission for invoking from other AWS services
resource "aws_lambda_permission" "this" {
  for_each = var.lambda_permissions

  statement_id  = each.key
  action        = each.value.action
  function_name = aws_lambda_function.this.function_name
  principal     = each.value.principal
  source_arn    = each.value.source_arn
  qualifier     = each.value.qualifier
}
