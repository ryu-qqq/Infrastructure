# Messaging Pattern Module Outputs

# SNS Topic Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = module.sns_topic.topic_arn
}

output "sns_topic_id" {
  description = "ID of the SNS topic"
  value       = module.sns_topic.topic_id
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = module.sns_topic.topic_name
}

# SQS Queue Outputs
output "sqs_queue_arns" {
  description = "Map of SQS queue names to their ARNs"
  value = {
    for name, queue in module.sqs_queues : name => queue.queue_arn
  }
}

output "sqs_queue_urls" {
  description = "Map of SQS queue names to their URLs"
  value = {
    for name, queue in module.sqs_queues : name => queue.queue_url
  }
}

output "sqs_dlq_arns" {
  description = "Map of SQS queue names to their DLQ ARNs"
  value = {
    for name, queue in module.sqs_queues : name => queue.dlq_arn
  }
}

# Subscription Outputs
output "subscription_arns" {
  description = "Map of subscription ARNs for each queue"
  value = {
    for name, sub in aws_sns_topic_subscription.sqs : name => sub.arn
  }
}

# Monitoring Outputs
output "sns_cloudwatch_alarm_arns" {
  description = "CloudWatch alarm ARNs for SNS topic"
  value       = module.sns_topic.cloudwatch_alarm_arns
}

output "sqs_cloudwatch_alarm_arns" {
  description = "Map of CloudWatch alarm ARNs for each SQS queue"
  value = {
    for name, queue in module.sqs_queues : name => queue.cloudwatch_alarm_arns
  }
}
