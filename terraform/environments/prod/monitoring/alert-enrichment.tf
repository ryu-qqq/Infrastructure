# Alert Enrichment System
# Lambda function that enriches alerts with context before sending to Slack
# IN-XXX: Monitoring system - Alert enrichment

# ============================================================================
# Lambda Deployment Package
# ============================================================================

data "archive_file" "alert_enrichment" {
  count = var.enable_alert_enrichment ? 1 : 0

  type        = "zip"
  source_dir  = "${path.root}/../../../../lambda/alert-enrichment"
  output_path = "${path.root}/.terraform/tmp/alert-enrichment.zip"
}

# ============================================================================
# Alert Enrichment Lambda Function
# ============================================================================

module "alert_enrichment_lambda" {
  count  = var.enable_alert_enrichment ? 1 : 0
  source = "../../../modules/lambda"

  name          = "alert-enrichment"
  function_name = "connectly-alert-enrichment"
  description   = "Enriches alerts with context information before sending to Slack"

  # Runtime configuration
  runtime       = "python3.11"
  handler       = "lambda_function.lambda_handler"
  timeout       = 30
  memory_size   = 256
  architectures = ["arm64"]

  # Code deployment
  filename         = data.archive_file.alert_enrichment[0].output_path
  source_code_hash = data.archive_file.alert_enrichment[0].output_base64sha256

  # Environment variables
  # Note: AWS_REGION is automatically provided by Lambda runtime
  environment_variables = {
    SLACK_WEBHOOK_URL   = var.alert_enrichment_slack_webhook_url
    AMP_ENDPOINT        = aws_prometheus_workspace.main.prometheus_endpoint
    RUNBOOK_TABLE_NAME  = var.enable_runbook_table ? module.runbook_table[0].table_name : ""
    GRAFANA_URL         = var.grafana_url
    CLOUDWATCH_BASE_URL = "https://${var.aws_region}.console.aws.amazon.com"
  }

  # CloudWatch Logs
  create_log_group   = true
  log_retention_days = 14
  log_kms_key_id     = aws_kms_key.monitoring.arn

  # Dead Letter Queue
  create_dlq     = true
  dlq_kms_key_id = aws_kms_key.monitoring.arn

  # X-Ray tracing
  tracing_mode = "Active"

  # Custom inline policy for enrichment permissions
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:FilterLogEvents",
          "logs:GetLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${local.aws_account_id}:log-group:/ecs/*:*",
          "arn:aws:logs:${var.aws_region}:${local.aws_account_id}:log-group:/aws/ecs/*:*"
        ]
      },
      {
        Sid    = "XRayRead"
        Effect = "Allow"
        Action = [
          "xray:GetTraceSummaries",
          "xray:BatchGetTraces",
          "xray:GetTraceGraph"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSRead"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:ListServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeClusters"
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBRead"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = var.enable_runbook_table ? [
          module.runbook_table[0].table_arn,
          "${module.runbook_table[0].table_arn}/index/*"
        ] : []
      },
      {
        Sid    = "AMPQuery"
        Effect = "Allow"
        Action = [
          "aps:QueryMetrics",
          "aps:GetMetricMetadata",
          "aps:GetLabels",
          "aps:GetSeries"
        ]
        Resource = aws_prometheus_workspace.main.arn
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.monitoring.arn
      }
    ]
  })

  # Lambda permissions for SNS invocation
  lambda_permissions = {
    sns_critical = {
      action     = "lambda:InvokeFunction"
      principal  = "sns.amazonaws.com"
      source_arn = module.sns_critical.topic_arn
    }
    sns_warning = {
      action     = "lambda:InvokeFunction"
      principal  = "sns.amazonaws.com"
      source_arn = module.sns_warning.topic_arn
    }
    sns_info = {
      action     = "lambda:InvokeFunction"
      principal  = "sns.amazonaws.com"
      source_arn = module.sns_info.topic_arn
    }
  }

  # Required tags
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = "infrastructure"
  data_class  = var.data_class

  additional_tags = {
    Component = "alerting"
  }
}

# ============================================================================
# SNS Subscriptions for Lambda
# ============================================================================

resource "aws_sns_topic_subscription" "alert_enrichment_critical" {
  count = var.enable_alert_enrichment ? 1 : 0

  topic_arn = module.sns_critical.topic_arn
  protocol  = "lambda"
  endpoint  = module.alert_enrichment_lambda[0].function_arn
}

resource "aws_sns_topic_subscription" "alert_enrichment_warning" {
  count = var.enable_alert_enrichment ? 1 : 0

  topic_arn = module.sns_warning.topic_arn
  protocol  = "lambda"
  endpoint  = module.alert_enrichment_lambda[0].function_arn
}

resource "aws_sns_topic_subscription" "alert_enrichment_info" {
  count = var.enable_alert_enrichment ? 1 : 0

  topic_arn = module.sns_info.topic_arn
  protocol  = "lambda"
  endpoint  = module.alert_enrichment_lambda[0].function_arn
}

# ============================================================================
# Runbook DynamoDB Table
# ============================================================================

module "runbook_table" {
  count  = var.enable_runbook_table ? 1 : 0
  source = "../../../modules/dynamodb"

  table_name = "connectly-alert-runbooks"
  hash_key   = "alert_name"
  range_key  = "service"

  attributes = [
    { name = "alert_name", type = "S" },
    { name = "service", type = "S" }
  ]

  # On-demand billing for unpredictable access patterns
  billing_mode = "PAY_PER_REQUEST"

  # KMS encryption (required)
  kms_key_arn = aws_kms_key.monitoring.arn

  # Point-in-time recovery for data protection
  enable_point_in_time_recovery = true

  # TTL not needed for runbooks
  ttl_attribute_name = null

  # Enable deletion protection in production
  deletion_protection_enabled = var.environment == "prod" ? true : false

  # Required tags
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = "infrastructure"
  data_class  = var.data_class

  additional_tags = {
    Component = "alerting"
    Purpose   = "runbook-mapping"
  }
}

# ============================================================================
# Alert History DynamoDB Table (Optional)
# ============================================================================

module "alert_history_table" {
  count  = var.enable_alert_history_table ? 1 : 0
  source = "../../../modules/dynamodb"

  table_name = "connectly-alert-history"
  hash_key   = "alert_id"
  range_key  = "timestamp"

  attributes = [
    { name = "alert_id", type = "S" },
    { name = "timestamp", type = "N" },
    { name = "service", type = "S" }
  ]

  global_secondary_indexes = [
    {
      name            = "service-timestamp-index"
      hash_key        = "service"
      range_key       = "timestamp"
      projection_type = "ALL"
    }
  ]

  # On-demand billing
  billing_mode = "PAY_PER_REQUEST"

  # KMS encryption
  kms_key_arn = aws_kms_key.monitoring.arn

  # Point-in-time recovery
  enable_point_in_time_recovery = true

  # TTL for automatic cleanup (90 days)
  ttl_attribute_name = "expiry_time"

  # Required tags
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = "infrastructure"
  data_class  = var.data_class

  additional_tags = {
    Component = "alerting"
    Purpose   = "alert-history"
  }
}

# ============================================================================
# CloudWatch Alarms for Lambda Health
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "alert_enrichment_errors" {
  count = var.enable_alert_enrichment ? 1 : 0

  alarm_name          = "${local.name_prefix}-alert-enrichment-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert enrichment Lambda has high error rate"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.alert_enrichment_lambda[0].function_name
  }

  # Send to info topic to avoid infinite loop
  alarm_actions = [module.sns_info.topic_arn]
  ok_actions    = [module.sns_info.topic_arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-alert-enrichment-errors"
      Component = "alerting"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alert_enrichment_duration" {
  count = var.enable_alert_enrichment ? 1 : 0

  alarm_name          = "${local.name_prefix}-alert-enrichment-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 25000 # 25 seconds (timeout is 30s)
  alarm_description   = "Alert enrichment Lambda is approaching timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = module.alert_enrichment_lambda[0].function_name
  }

  alarm_actions = [module.sns_warning.topic_arn]
  ok_actions    = [module.sns_info.topic_arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-alert-enrichment-duration"
      Component = "alerting"
    }
  )
}

# ============================================================================
# SSM Parameters for Cross-Stack Reference
# ============================================================================

resource "aws_ssm_parameter" "alert_enrichment_lambda_arn" {
  count = var.enable_alert_enrichment ? 1 : 0

  name        = "/shared/monitoring/alert-enrichment-lambda-arn"
  type        = "String"
  value       = module.alert_enrichment_lambda[0].function_arn
  description = "Alert enrichment Lambda function ARN"

  tags = merge(
    local.required_tags,
    {
      Name      = "alert-enrichment-lambda-arn"
      Component = "alerting"
    }
  )
}

resource "aws_ssm_parameter" "runbook_table_name" {
  count = var.enable_runbook_table ? 1 : 0

  name        = "/shared/monitoring/runbook-table-name"
  type        = "String"
  value       = module.runbook_table[0].table_name
  description = "Alert runbook DynamoDB table name"

  tags = merge(
    local.required_tags,
    {
      Name      = "runbook-table-name"
      Component = "alerting"
    }
  )
}
