# SQS Queue Module
# Creates an SQS queue with optional DLQ, KMS encryption, and CloudWatch monitoring

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

  # Generate queue name with .fifo suffix for FIFO queues
  queue_name     = var.fifo_queue ? "${var.name}.fifo" : var.name
  dlq_queue_name = var.fifo_queue ? "${var.name}-dlq.fifo" : "${var.name}-dlq"
}

# Dead Letter Queue (DLQ)
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0

  name                        = local.dlq_queue_name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  # KMS encryption is required
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds

  # Message retention for DLQ (typically longer than main queue)
  message_retention_seconds = var.dlq_message_retention_seconds

  tags = merge(
    local.required_tags,
    {
      Name         = local.dlq_queue_name
      QueueType    = var.fifo_queue ? "FIFO" : "Standard"
      QueueRole    = "DLQ"
      KMSEncrypted = "true"
    },
    var.additional_tags
  )
}

# Main SQS Queue
resource "aws_sqs_queue" "this" {
  name                        = local.queue_name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  # KMS encryption is required
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds

  # Message configuration
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  # Redrive policy for DLQ
  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  # Allow redrive from DLQ back to main queue
  redrive_allow_policy = var.enable_dlq ? jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.dlq[0].arn]
  }) : null

  # FIFO-specific configuration
  deduplication_scope   = var.fifo_queue ? var.deduplication_scope : null
  fifo_throughput_limit = var.fifo_queue ? var.fifo_throughput_limit : null

  tags = merge(
    local.required_tags,
    {
      Name         = local.queue_name
      QueueType    = var.fifo_queue ? "FIFO" : "Standard"
      QueueRole    = "Main"
      KMSEncrypted = "true"
      DLQEnabled   = var.enable_dlq ? "true" : "false"
    },
    var.additional_tags
  )
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "this" {
  count = var.queue_policy != null ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  policy    = var.queue_policy
}

# CloudWatch Metric Alarm - Queue Depth (Age of Oldest Message)
resource "aws_cloudwatch_metric_alarm" "message-age" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.queue_name}-message-age-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = var.alarm_period
  statistic           = "Maximum"
  threshold           = var.alarm_message_age_threshold
  alarm_description   = "Alerts when messages are not being processed (old messages accumulating)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.this.name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_ok_actions

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.queue_name}-message-age-high"
      AlarmType = "MessageAge"
    }
  )
}

# CloudWatch Metric Alarm - Number of Messages Visible
resource "aws_cloudwatch_metric_alarm" "messages-visible" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.queue_name}-messages-visible-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_messages_visible_threshold
  alarm_description   = "Alerts when queue depth is too high (backlog building up)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.this.name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_ok_actions

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.queue_name}-messages-visible-high"
      AlarmType = "MessagesVisible"
    }
  )
}

# CloudWatch Metric Alarm - DLQ Depth
resource "aws_cloudwatch_metric_alarm" "dlq-messages" {
  count = var.enable_dlq && var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.dlq_queue_name}-messages-visible"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_dlq_messages_threshold
  alarm_description   = "Alerts when DLQ receives messages (processing failures)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq[0].name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_ok_actions

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.dlq_queue_name}-messages-visible"
      AlarmType = "DLQMessages"
    }
  )
}
