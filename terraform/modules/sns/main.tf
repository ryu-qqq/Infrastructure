# SNS Topic Module
# Creates an SNS topic with KMS encryption, subscriptions, and CloudWatch monitoring

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

  # Generate topic name with .fifo suffix for FIFO topics
  topic_name = var.fifo_topic ? "${var.name}.fifo" : var.name
}

# SNS Topic
resource "aws_sns_topic" "this" {
  name                        = local.topic_name
  display_name                = var.display_name
  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.fifo_topic ? var.content_based_deduplication : null

  # KMS encryption is required for all SNS topics
  kms_master_key_id = var.kms_key_id

  # Delivery policy for message retry
  delivery_policy = var.delivery_policy

  tags = merge(
    local.required_tags,
    {
      Name         = local.topic_name
      TopicType    = var.fifo_topic ? "FIFO" : "Standard"
      KMSEncrypted = "true"
    },
    var.additional_tags
  )
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "this" {
  count = var.topic_policy != null ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = var.topic_policy
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscriptions

  topic_arn            = aws_sns_topic.this.arn
  protocol             = each.value.protocol
  endpoint             = each.value.endpoint
  raw_message_delivery = lookup(each.value, "raw_message_delivery", null)
  filter_policy        = lookup(each.value, "filter_policy", null) != null ? jsonencode(each.value.filter_policy) : null
  filter_policy_scope  = lookup(each.value, "filter_policy_scope", null)
  delivery_policy      = lookup(each.value, "delivery_policy", null)
  redrive_policy       = lookup(each.value, "redrive_policy", null)

  # Subscription confirmation for email/SMS
  confirmation_timeout_in_minutes = lookup(each.value, "confirmation_timeout_in_minutes", null)
}

# CloudWatch Metric Alarm - Number of Messages Published
resource "aws_cloudwatch_metric_alarm" "messages-published" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.topic_name}-messages-published-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "NumberOfMessagesPublished"
  namespace           = "AWS/SNS"
  period              = var.alarm_period
  statistic           = "Sum"
  threshold           = var.alarm_messages_published_threshold
  alarm_description   = "Alerts when message publish rate is unexpectedly low"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TopicName = aws_sns_topic.this.name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_ok_actions

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.topic_name}-messages-published-low"
      AlarmType = "MessagesPublished"
    }
  )
}

# CloudWatch Metric Alarm - Number of Notifications Failed
resource "aws_cloudwatch_metric_alarm" "notifications-failed" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.topic_name}-notifications-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = var.alarm_period
  statistic           = "Sum"
  threshold           = var.alarm_notifications_failed_threshold
  alarm_description   = "Alerts when notifications fail to deliver"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TopicName = aws_sns_topic.this.name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_ok_actions

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.topic_name}-notifications-failed"
      AlarmType = "NotificationsFailed"
    }
  )
}
