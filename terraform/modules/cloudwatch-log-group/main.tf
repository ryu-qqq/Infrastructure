# CloudWatch Log Group Module
# Creates a CloudWatch Log Group with KMS encryption, retention policy, and standard tagging

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
}

resource "aws_cloudwatch_log_group" "this" {
  name              = var.name
  retention_in_days = var.retention_in_days
  kms_key_id        = var.kms_key_id

  tags = merge(
    local.required_tags,
    {
      Name          = var.name
      LogType       = var.log_type
      RetentionDays = tostring(var.retention_in_days)
      KMSEncrypted  = var.kms_key_id != null ? "true" : "false"
      ExportToS3    = var.export_to_s3_enabled ? "enabled" : "disabled"
      SentrySync    = var.sentry_sync_status
      LangfuseSync  = var.langfuse_sync_status
    }
  )
}

# Optional: Subscription Filter for Sentry integration (future)
resource "aws_cloudwatch_log_subscription_filter" "sentry" {
  count = var.sentry_sync_status == "enabled" ? 1 : 0

  name            = "${var.name}-sentry-filter"
  log_group_name  = aws_cloudwatch_log_group.this.name
  filter_pattern  = var.sentry_filter_pattern
  destination_arn = var.sentry_lambda_arn

  depends_on = [aws_cloudwatch_log_group.this]
}

# Optional: Subscription Filter for Langfuse integration (future)
resource "aws_cloudwatch_log_subscription_filter" "langfuse" {
  count = var.langfuse_sync_status == "enabled" ? 1 : 0

  name            = "${var.name}-langfuse-filter"
  log_group_name  = aws_cloudwatch_log_group.this.name
  filter_pattern  = var.langfuse_filter_pattern
  destination_arn = var.langfuse_lambda_arn

  depends_on = [aws_cloudwatch_log_group.this]
}

# Optional: Metric Filter for Error Rate Monitoring
resource "aws_cloudwatch_log_metric_filter" "error_rate" {
  count = var.enable_error_rate_metric ? 1 : 0

  name           = "${var.name}-error-rate"
  log_group_name = aws_cloudwatch_log_group.this.name
  pattern        = var.error_metric_pattern

  metric_transformation {
    name      = "${replace(var.name, "/", "-")}-errors"
    namespace = var.metric_namespace
    value     = "1"
    unit      = "Count"
  }
}
