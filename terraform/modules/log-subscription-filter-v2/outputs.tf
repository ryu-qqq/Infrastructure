# ============================================================================
# Log Subscription Filter V2 Outputs
# ============================================================================

output "subscription_filter_name" {
  description = "Name of the created subscription filter"
  value       = aws_cloudwatch_log_subscription_filter.to_kinesis.name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis Data Stream destination"
  value       = data.aws_ssm_parameter.kinesis_stream_arn.value
}
