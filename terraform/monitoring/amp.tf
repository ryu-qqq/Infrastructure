# Amazon Managed Prometheus (AMP) Workspace
# IN-117: Monitoring system setup

# ============================================================================
# KMS Key for AMP Encryption
# ============================================================================

# Use existing KMS key from remote state or create new one
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "kms/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "atlantis" {
  backend = "s3"
  config = {
    bucket = var.terraform_state_bucket
    key    = "atlantis/terraform.tfstate"
    region = var.aws_region
  }
}

# ============================================================================
# AMP Workspace
# ============================================================================

resource "aws_prometheus_workspace" "main" {
  alias = "${local.name_prefix}-${var.amp_workspace_alias}"

  # Enable CloudWatch Logs for AMP query logs
  logging_configuration {
    log_group_arn = var.amp_enable_logging ? "${aws_cloudwatch_log_group.amp-query-logs[0].arn}:*" : null
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-amp"
      Component   = "amp"
      Description = "Amazon Managed Prometheus workspace for infrastructure monitoring"
    }
  )
}

# ============================================================================
# CloudWatch Log Group for AMP Query Logs
# ============================================================================

resource "aws_cloudwatch_log_group" "amp-query-logs" {
  count = var.amp_enable_logging ? 1 : 0

  name              = "/aws/prometheus/${var.amp_workspace_alias}/query-logs"
  retention_in_days = 7
  kms_key_id        = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn

  tags = merge(
    local.required_tags,
    {
      Name        = "${local.name_prefix}-amp-query-logs"
      Component   = "amp"
      Description = "AMP query logs for troubleshooting and auditing"
    }
  )
}

# ============================================================================
# AMP Alerting and Recording Rules (Future)
# ============================================================================

# Alert Manager Configuration (commented out for initial setup)
# resource "aws_prometheus_alert_manager_definition" "main" {
#   workspace_id = aws_prometheus_workspace.main.id
#
#   definition = templatefile("${path.module}/configs/alertmanager.yml", {
#     sns_topic_arn = aws_sns_topic.alerts.arn
#   })
# }

# Recording Rules (commented out for initial setup)
# resource "aws_prometheus_rule_group_namespace" "recording_rules" {
#   name         = "recording-rules"
#   workspace_id = aws_prometheus_workspace.main.id
#
#   data = file("${path.module}/configs/recording-rules.yml")
# }

# Alert Rules (commented out for initial setup)
# resource "aws_prometheus_rule_group_namespace" "alert_rules" {
#   name         = "alert-rules"
#   workspace_id = aws_prometheus_workspace.main.id
#
#   data = templatefile("${path.module}/configs/alert-rules.yml", {
#     workspace_id = aws_prometheus_workspace.main.id
#   })
# }
