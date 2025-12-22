# ============================================================================
# OpenSearch Alerting Configuration
# Log-based alerting with SNS notifications
# ============================================================================

# ============================================================================
# Data Sources
# ============================================================================

data "aws_elasticsearch_domain" "logs" {
  count       = var.enable_opensearch-alerting ? 1 : 0
  domain_name = var.opensearch_domain_name
}

# ============================================================================
# IAM Role for OpenSearch Alerting → SNS
# ============================================================================

resource "aws_iam_role" "opensearch-alerting" {
  count = var.enable_opensearch-alerting ? 1 : 0
  name  = "${local.name_prefix}-opensearch-alerting-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-opensearch-alerting-role"
      Component = "opensearch-alerting"
    }
  )
}

resource "aws_iam_role_policy" "opensearch-alerting-sns" {
  count = var.enable_opensearch-alerting ? 1 : 0
  name  = "${local.name_prefix}-opensearch-alerting-sns-policy"
  role  = aws_iam_role.opensearch-alerting[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes"
        ]
        Resource = [
          module.sns_critical.topic_arn,
          module.sns_warning.topic_arn,
          module.sns_info.topic_arn
        ]
      },
      {
        Sid    = "AllowKMSForSNS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = aws_kms_key.monitoring.arn
      }
    ]
  })
}

# ============================================================================
# Note: SNS Topic Policies
# ============================================================================
# SNS topic policies are managed in alerting.tf via the sns module.
# The OpenSearch alerting role has direct IAM permissions to publish to SNS topics.
# No additional topic policy is needed since the role is in the same account.

# ============================================================================
# OpenSearch Alerting Setup Script
# ============================================================================

# Lambda to configure OpenSearch Alerting monitors and destinations
resource "aws_lambda_function" "opensearch-alerting-setup" {
  count            = var.enable_opensearch-alerting ? 1 : 0
  function_name    = "${local.name_prefix}-opensearch-alerting-setup"
  role             = aws_iam_role.opensearch-alerting-lambda[0].arn
  handler          = "lambda_function.handler"
  runtime          = "python3.11"
  timeout          = 120
  memory_size      = 256
  filename         = data.archive_file.opensearch-alerting-setup[0].output_path
  source_code_hash = data.archive_file.opensearch-alerting-setup[0].output_base64sha256

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = "https://${data.aws_elasticsearch_domain.logs[0].endpoint}"
      SNS_TOPIC_CRITICAL  = module.sns_critical.topic_arn
      SNS_TOPIC_WARNING   = module.sns_warning.topic_arn
      SNS_TOPIC_INFO      = module.sns_info.topic_arn
      SNS_ROLE_ARN        = aws_iam_role.opensearch-alerting[0].arn
      AWS_REGION_NAME     = local.aws_region
    }
  }

  # Note: OpenSearch is public endpoint with IP-based access control
  # No VPC config needed for Lambda

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-opensearch-alerting-setup"
      Component = "opensearch-alerting"
    }
  )
}

data "archive_file" "opensearch-alerting-setup" {
  count       = var.enable_opensearch-alerting ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../../../lambda/opensearch-alerting-setup"
  output_path = "${path.module}/opensearch-alerting-setup.zip"
}

resource "aws_iam_role" "opensearch-alerting-lambda" {
  count = var.enable_opensearch-alerting ? 1 : 0
  name  = "${local.name_prefix}-opensearch-alerting-lambda-role"

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
      Name      = "${local.name_prefix}-opensearch-alerting-lambda-role"
      Component = "opensearch-alerting"
    }
  )
}

resource "aws_iam_role_policy" "opensearch-alerting-lambda" {
  count = var.enable_opensearch-alerting ? 1 : 0
  name  = "${local.name_prefix}-opensearch-alerting-lambda-policy"
  role  = aws_iam_role.opensearch-alerting-lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OpenSearchAccess"
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete"
        ]
        Resource = [
          "${data.aws_elasticsearch_domain.logs[0].arn}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:log-group:/aws/lambda/${local.name_prefix}-opensearch-alerting-setup:*"
      }
    ]
  })
}

# Invoke Lambda to setup alerting (one-time execution via null_resource)
resource "null_resource" "opensearch-alerting-setup" {
  count = var.enable_opensearch-alerting && var.run_opensearch-alerting-setup ? 1 : 0

  triggers = {
    lambda_arn    = aws_lambda_function.opensearch-alerting-setup[0].arn
    source_hash   = data.archive_file.opensearch-alerting-setup[0].output_base64sha256
    sns_critical  = module.sns_critical.topic_arn
    sns_warning   = module.sns_warning.topic_arn
    setup_version = var.opensearch-alerting-setup_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws lambda invoke \
        --function-name ${aws_lambda_function.opensearch-alerting-setup[0].function_name} \
        --payload '{"action": "setup_all"}' \
        --region ${local.aws_region} \
        /tmp/opensearch-alerting-setup-response.json
      cat /tmp/opensearch-alerting-setup-response.json
    EOT
  }

  depends_on = [
    aws_lambda_function.opensearch-alerting-setup,
    aws_iam_role_policy.opensearch-alerting-lambda,
    aws_iam_role_policy.opensearch-alerting-sns
  ]
}

# ============================================================================
# Outputs
# ============================================================================

output "opensearch_alerting_role_arn" {
  description = "IAM role ARN for OpenSearch alerting to publish to SNS"
  value       = var.enable_opensearch-alerting ? aws_iam_role.opensearch-alerting[0].arn : null
}

output "opensearch_alerting_setup_lambda_arn" {
  description = "Lambda function ARN for OpenSearch alerting setup"
  value       = var.enable_opensearch-alerting ? aws_lambda_function.opensearch-alerting-setup[0].arn : null
}
