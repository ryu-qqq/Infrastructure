# SQS Queue Module Outputs

output "queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.this.arn
}

output "queue_id" {
  description = "ID (URL) of the SQS queue"
  value       = aws_sqs_queue.this.id
}

output "queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.this.url
}

output "queue_name" {
  description = "Name of the SQS queue"
  value       = aws_sqs_queue.this.name
}

output "dlq_arn" {
  description = "ARN of the Dead Letter Queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_id" {
  description = "ID (URL) of the Dead Letter Queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].id : null
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}

output "dlq_name" {
  description = "Name of the Dead Letter Queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].name : null
}

output "cloudwatch_alarm_arns" {
  description = "ARNs of CloudWatch alarms for monitoring"
  value = {
    message_age      = try(aws_cloudwatch_metric_alarm.message_age[0].arn, null)
    messages_visible = try(aws_cloudwatch_metric_alarm.messages_visible[0].arn, null)
    dlq_messages     = try(aws_cloudwatch_metric_alarm.dlq_messages[0].arn, null)
  }
}
