# ============================================================================
# CloudWatch Log Subscription Filter Module
# ============================================================================
# Creates a subscription filter to stream logs from CloudWatch to
# the centralized Kinesis Firehose (managed by Infrastructure repo)
#
# Prerequisites:
# - Central log streaming infrastructure must be enabled
#   (enable_log_streaming = true in terraform/environments/prod/logging)
# - SSM Parameters must exist:
#   - /shared/logging/firehose-arn
#   - /shared/logging/cloudwatch-to-firehose-role-arn
# ============================================================================

# ============================================================================
# Data Sources - Fetch central infrastructure references from SSM
# ============================================================================

data "aws_ssm_parameter" "firehose_arn" {
  name = "/shared/logging/firehose-arn"
}

data "aws_ssm_parameter" "cloudwatch_to_firehose_role_arn" {
  name = "/shared/logging/cloudwatch-to-firehose-role-arn"
}

# ============================================================================
# CloudWatch Log Subscription Filter
# ============================================================================

resource "aws_cloudwatch_log_subscription_filter" "this" {
  name            = var.filter_name != "" ? var.filter_name : "${var.service_name}-to-opensearch"
  log_group_name  = var.log_group_name
  filter_pattern  = var.filter_pattern
  destination_arn = data.aws_ssm_parameter.firehose_arn.value
  role_arn        = data.aws_ssm_parameter.cloudwatch_to_firehose_role_arn.value

  # Prevent recreation on filter pattern changes if distribution is set
  distribution = var.distribution
}
