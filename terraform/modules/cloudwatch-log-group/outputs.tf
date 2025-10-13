# CloudWatch Log Group Module Outputs

output "log_group_name" {
  description = "Name of the created CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the created CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.this.arn
}

output "log_group_id" {
  description = "ID of the created CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.this.id
}

output "retention_in_days" {
  description = "Retention period in days"
  value       = aws_cloudwatch_log_group.this.retention_in_days
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = aws_cloudwatch_log_group.this.kms_key_id
}

output "tags" {
  description = "Tags applied to the log group"
  value       = aws_cloudwatch_log_group.this.tags
}

output "sentry_subscription_filter_name" {
  description = "Name of the Sentry subscription filter (if enabled)"
  value       = var.sentry_sync_status == "enabled" ? aws_cloudwatch_log_subscription_filter.sentry[0].name : null
}

output "langfuse_subscription_filter_name" {
  description = "Name of the Langfuse subscription filter (if enabled)"
  value       = var.langfuse_sync_status == "enabled" ? aws_cloudwatch_log_subscription_filter.langfuse[0].name : null
}
