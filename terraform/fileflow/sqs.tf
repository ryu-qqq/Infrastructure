# ============================================================================
# SQS Configuration
# ============================================================================

# Main queue for file processing tasks
module "file_processing_queue" {
  source = "../modules/sqs"

  # Queue naming
  name = "${local.name_prefix}-file-processing"

  # Required tags
  environment = var.environment
  service     = local.service_name
  team        = var.tags_team
  owner       = var.tags_owner
  cost_center = var.tags_cost_center
  project     = "fileflow"

  # Encryption
  kms_key_id = data.terraform_remote_state.kms.outputs.sqs_key_arn

  # Queue configuration
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  message_retention_seconds  = var.sqs_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
  max_message_size           = 262144  # 256 KB

  # Dead Letter Queue
  enable_dlq        = true
  max_receive_count = 3

  # CloudWatch monitoring
  enable_cloudwatch_alarms = true
  alarm_actions            = [data.terraform_remote_state.monitoring.outputs.alerts_topic_arn]

  # Message age alarm threshold (5 minutes)
  message_age_threshold = 300

  # Queue depth alarm threshold
  queue_depth_threshold = 1000

  additional_tags = {
    Name      = "${local.name_prefix}-file-processing"
    Component = "queue"
  }
}

# Queue for file upload notifications
module "file_upload_queue" {
  source = "../modules/sqs"

  # Queue naming
  name = "${local.name_prefix}-file-upload"

  # Required tags
  environment = var.environment
  service     = local.service_name
  team        = var.tags_team
  owner       = var.tags_owner
  cost_center = var.tags_cost_center
  project     = "fileflow"

  # Encryption
  kms_key_id = data.terraform_remote_state.kms.outputs.sqs_key_arn

  # Queue configuration
  visibility_timeout_seconds = 60  # Shorter timeout for upload notifications
  message_retention_seconds  = 345600  # 4 days
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
  max_message_size           = 262144

  # Dead Letter Queue
  enable_dlq        = true
  max_receive_count = 5  # More retries for notifications

  # CloudWatch monitoring
  enable_cloudwatch_alarms = true
  alarm_actions            = [data.terraform_remote_state.monitoring.outputs.alerts_topic_arn]

  message_age_threshold = 180  # 3 minutes
  queue_depth_threshold = 500

  additional_tags = {
    Name      = "${local.name_prefix}-file-upload"
    Component = "queue"
  }
}

# Queue for file completion notifications
module "file_completion_queue" {
  source = "../modules/sqs"

  # Queue naming
  name = "${local.name_prefix}-file-completion"

  # Required tags
  environment = var.environment
  service     = local.service_name
  team        = var.tags_team
  owner       = var.tags_owner
  cost_center = var.tags_cost_center
  project     = "fileflow"

  # Encryption
  kms_key_id = data.terraform_remote_state.kms.outputs.sqs_key_arn

  # Queue configuration
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400  # 1 day
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
  max_message_size           = 262144

  # Dead Letter Queue
  enable_dlq        = true
  max_receive_count = 3

  # CloudWatch monitoring
  enable_cloudwatch_alarms = true
  alarm_actions            = [data.terraform_remote_state.monitoring.outputs.alerts_topic_arn]

  message_age_threshold = 120  # 2 minutes
  queue_depth_threshold = 500

  additional_tags = {
    Name      = "${local.name_prefix}-file-completion"
    Component = "queue"
  }
}

# IAM policy for ECS task to access SQS queues
resource "aws_iam_policy" "sqs_access" {
  name        = "${local.name_prefix}-sqs-access"
  description = "Policy for fileflow ECS tasks to access SQS queues"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          module.file_processing_queue.queue_arn,
          module.file_upload_queue.queue_arn,
          module.file_completion_queue.queue_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = data.terraform_remote_state.kms.outputs.sqs_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-sqs-access"
      Component = "iam"
    }
  )
}

# Attach SQS policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_sqs" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.sqs_access.arn
}

# S3 bucket notification to trigger file upload queue
resource "aws_s3_bucket_notification" "file_upload_notification" {
  bucket = module.fileflow_bucket.bucket_id

  queue {
    queue_arn     = module.file_upload_queue.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }
}

# Allow S3 to send messages to SQS
resource "aws_sqs_queue_policy" "file_upload_queue_policy" {
  queue_url = module.file_upload_queue.queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = module.file_upload_queue.queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = module.fileflow_bucket.bucket_arn
          }
        }
      }
    ]
  })
}
