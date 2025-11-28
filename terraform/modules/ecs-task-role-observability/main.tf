# ECS Task Role with Observability Permissions
# X-Ray, CloudWatch Logs, CloudWatch Metrics for OTEL integration

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
  required_tags = module.tags.tags
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================================================
# IAM Role (ECS Task Role)
# ============================================================================

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.description != "" ? var.description : "ECS Task Role with Observability permissions for ${var.service_name}"
  assume_role_policy   = var.assume_role_policy
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary

  tags = merge(
    local.required_tags,
    {
      Name      = var.role_name
      Component = "ecs-task-role"
    }
  )
}

# ============================================================================
# AWS Managed Policy Attachments
# ============================================================================

resource "aws_iam_role_policy_attachment" "aws-managed" {
  for_each = toset(var.attach_aws_managed_policies)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

# ============================================================================
# X-Ray Tracing Policy
# ============================================================================

resource "aws_iam_role_policy" "xray" {
  count = var.enable_xray_policy ? 1 : 0

  name = "${var.role_name}-xray"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "XRayTracing"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      },
      {
        Sid    = "XRaySampling"
        Effect = "Allow"
        Action = [
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# CloudWatch Logs Policy (for OTEL Collector)
# ============================================================================

resource "aws_iam_role_policy" "cloudwatch-logs" {
  count = var.enable_cloudwatch_logs_policy ? 1 : 0

  name = "${var.role_name}-cloudwatch-logs"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Create log group permission (with prefix restriction)
      var.cloudwatch_allow_create_log_group ? [{
        Sid    = "CreateLogGroup"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup"
        ]
        Resource = length(var.cloudwatch_log_group_prefixes) > 0 ? [
          for prefix in var.cloudwatch_log_group_prefixes :
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:${prefix}*"
        ] : ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/*"]
      }] : [],
      # Log stream operations
      length(var.cloudwatch_log_group_arns) > 0 ? [{
        Sid    = "LogStreamOperations"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams"
        ]
        Resource = var.cloudwatch_log_group_arns
      }] : [],
      # Put log events
      length(var.cloudwatch_log_group_arns) > 0 ? [{
        Sid    = "PutLogEvents"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = [
          for arn in var.cloudwatch_log_group_arns : "${arn}:*"
        ]
      }] : []
    )
  })
}

# ============================================================================
# CloudWatch Metrics Policy (for Micrometer/OTEL)
# ============================================================================

resource "aws_iam_role_policy" "cloudwatch-metrics" {
  count = var.enable_cloudwatch_metrics_policy ? 1 : 0

  name = "${var.role_name}-cloudwatch-metrics"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PutMetricData"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = length(var.cloudwatch_metric_namespaces) > 0 ? {
          StringEquals = {
            "cloudwatch:namespace" = var.cloudwatch_metric_namespaces
          }
        } : null
      }
    ]
  })
}

# ============================================================================
# Combined Observability Policy (All-in-One)
# ============================================================================

resource "aws_iam_role_policy" "observability" {
  count = var.enable_combined_observability_policy ? 1 : 0

  name = "${var.role_name}-observability"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # X-Ray Tracing
      {
        Sid    = "XRayAccess"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      },
      # CloudWatch Logs for OTEL
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = length(var.cloudwatch_log_group_arns) > 0 ? [
          for arn in var.cloudwatch_log_group_arns : "${arn}:*"
        ] : ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.service_name}/*"]
      },
      # CloudWatch Metrics
      {
        Sid    = "CloudWatchMetricsAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = length(var.cloudwatch_metric_namespaces) > 0 ? {
          StringEquals = {
            "cloudwatch:namespace" = var.cloudwatch_metric_namespaces
          }
        } : null
      }
    ]
  })
}

# ============================================================================
# Custom Inline Policies
# ============================================================================

resource "aws_iam_role_policy" "custom" {
  for_each = var.custom_inline_policies

  name   = "${var.role_name}-${each.key}"
  role   = aws_iam_role.this.id
  policy = each.value.policy
}
