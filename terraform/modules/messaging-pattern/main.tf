# Messaging Pattern Module - Fan-out Pattern
# Creates SNS topic with multiple SQS queue subscriptions with filter policies

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

# SNS Topic for Fan-out
module "sns_topic" {
  source = "../sns"

  name         = var.sns_topic_name
  display_name = var.sns_display_name
  fifo_topic   = var.fifo_topic

  # Required tags
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project

  # Security
  kms_key_id   = var.kms_key_id
  topic_policy = var.sns_topic_policy

  # CloudWatch alarms
  enable_cloudwatch_alarms = var.enable_cloudwatch_alarms
  alarm_actions            = var.alarm_actions
  alarm_ok_actions         = var.alarm_ok_actions

  # No direct subscriptions here - managed separately below
  subscriptions = []

  additional_tags = merge(
    {
      Pattern = "Fan-out"
    },
    var.additional_tags
  )
}

# SQS Queues for Fan-out subscribers
module "sqs_queues" {
  source = "../sqs"

  for_each = { for idx, queue in var.sqs_queues : queue.name => queue }

  name       = each.value.name
  fifo_queue = var.fifo_topic

  # Required tags
  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project

  # Security
  kms_key_id = var.kms_key_id

  # Queue configuration
  visibility_timeout_seconds = lookup(each.value, "visibility_timeout_seconds", 30)
  message_retention_seconds  = lookup(each.value, "message_retention_seconds", 345600)
  max_message_size           = lookup(each.value, "max_message_size", 262144)
  receive_wait_time_seconds  = lookup(each.value, "receive_wait_time_seconds", 0)

  # DLQ configuration
  enable_dlq        = lookup(each.value, "enable_dlq", true)
  max_receive_count = lookup(each.value, "max_receive_count", 3)

  # CloudWatch alarms
  enable_cloudwatch_alarms = var.enable_cloudwatch_alarms
  alarm_actions            = var.alarm_actions
  alarm_ok_actions         = var.alarm_ok_actions

  additional_tags = merge(
    {
      Pattern         = "Fan-out"
      SubscribedTopic = module.sns_topic.topic_name
    },
    lookup(each.value, "additional_tags", {})
  )
}

# SQS Queue Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "sns-to-sqs" {
  for_each = { for idx, queue in var.sqs_queues : queue.name => queue }

  queue_url = module.sqs_queues[each.key].queue_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowSNSToSendMessages"
      Effect = "Allow"
      Principal = {
        Service = "sns.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = module.sqs_queues[each.key].queue_arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = module.sns_topic.topic_arn
        }
      }
    }]
  })
}

# SNS Topic Subscriptions to SQS Queues
resource "aws_sns_topic_subscription" "sqs" {
  for_each = { for idx, queue in var.sqs_queues : queue.name => queue }

  topic_arn            = module.sns_topic.topic_arn
  protocol             = "sqs"
  endpoint             = module.sqs_queues[each.key].queue_arn
  raw_message_delivery = lookup(each.value, "raw_message_delivery", false)

  # Filter policy for selective message routing
  filter_policy = lookup(each.value, "filter_policy", null) != null ? jsonencode(each.value.filter_policy) : null

  depends_on = [module.sqs_queues]
}
