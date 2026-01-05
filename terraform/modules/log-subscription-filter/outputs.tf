# ============================================================================
# Outputs
# ============================================================================

output "subscription_filter_name" {
  description = "Name of the created CloudWatch Log Subscription Filter"
  value       = aws_cloudwatch_log_subscription_filter.this.name
}

output "log_group_name" {
  description = "Name of the log group being streamed"
  value       = var.log_group_name
}

output "firehose_arn" {
  description = "ARN of the Kinesis Firehose destination (from SSM)"
  value       = data.aws_ssm_parameter.firehose_arn.value
}

output "filter_pattern" {
  description = "Filter pattern applied to the subscription"
  value       = var.filter_pattern != "" ? var.filter_pattern : "(all logs)"
}
