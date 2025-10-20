# SNS Topic Module Outputs

output "topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.this.arn
}

output "topic_id" {
  description = "ID of the SNS topic"
  value       = aws_sns_topic.this.id
}

output "topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.this.name
}

output "topic_owner" {
  description = "AWS account ID of the SNS topic owner"
  value       = aws_sns_topic.this.owner
}

output "subscription_arns" {
  description = "ARNs of the SNS topic subscriptions"
  value = {
    for idx, sub in aws_sns_topic_subscription.this : idx => sub.arn
  }
}

output "subscription_ids" {
  description = "IDs of the SNS topic subscriptions"
  value = {
    for idx, sub in aws_sns_topic_subscription.this : idx => sub.id
  }
}

output "cloudwatch_alarm_arns" {
  description = "ARNs of CloudWatch alarms for monitoring"
  value = {
    messages_published   = try(aws_cloudwatch_metric_alarm.messages_published[0].arn, null)
    notifications_failed = try(aws_cloudwatch_metric_alarm.notifications_failed[0].arn, null)
  }
}
