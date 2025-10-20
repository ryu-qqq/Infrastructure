# ============================================================================
# S3 Configuration
# ============================================================================

# Main fileflow storage bucket
module "fileflow_bucket" {
  source = "../modules/s3-bucket"

  # Bucket naming
  bucket_name = "${local.name_prefix}-storage"

  # Required tags
  environment = var.environment
  service     = local.service_name
  team        = var.tags_team
  owner       = var.tags_owner
  cost_center = var.tags_cost_center
  project     = "fileflow"

  # Encryption
  kms_key_id = data.terraform_remote_state.kms.outputs.s3_key_arn

  # Versioning for data protection
  versioning_enabled = var.s3_versioning_enabled

  # Lifecycle policy for cost optimization
  lifecycle_rules = [
    {
      id      = "fileflow-data-lifecycle"
      enabled = true
      prefix  = ""

      # Move to IA after 30 days
      transition_to_ia_days = 30

      # Move to Glacier after configured days
      transition_to_glacier_days = var.s3_lifecycle_glacier_days

      # Keep data for 1 year
      expiration_days = 365

      # Clean up old versions after 30 days
      noncurrent_expiration_days = 30

      # Abort incomplete multipart uploads after 7 days
      abort_incomplete_upload_days = 7
    }
  ]

  # CORS for file upload/download
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
      allowed_origins = ["*"]  # TODO: Restrict to actual domain in production
      expose_headers  = ["ETag", "x-amz-request-id"]
      max_age_seconds = 3600
    }
  ]

  # CloudWatch monitoring
  enable_cloudwatch_alarms      = true
  alarm_bucket_size_threshold   = 107374182400  # 100GB
  alarm_object_count_threshold  = 1000000       # 1M objects
  alarm_actions                 = [data.terraform_remote_state.monitoring.outputs.alerts_topic_arn]

  # Request metrics for monitoring
  enable_request_metrics        = true
  request_metrics_filter_prefix = ""  # Monitor entire bucket

  # Additional tags
  additional_tags = {
    Name      = "${local.name_prefix}-storage"
    Component = "storage"
  }
}

# Logging bucket for S3 access logs
module "fileflow_logs_bucket" {
  source = "../modules/s3-bucket"

  # Bucket naming
  bucket_name = "${local.name_prefix}-logs"

  # Required tags
  environment = var.environment
  service     = local.service_name
  team        = var.tags_team
  owner       = var.tags_owner
  cost_center = var.tags_cost_center
  project     = "fileflow"

  # Encryption
  kms_key_id = data.terraform_remote_state.kms.outputs.s3_key_arn

  # No versioning needed for logs
  versioning_enabled = false

  # Aggressive lifecycle for logs
  lifecycle_rules = [
    {
      id      = "logs-lifecycle"
      enabled = true
      prefix  = ""

      # Move to IA after 7 days
      transition_to_ia_days = 7

      # Move to Glacier after 30 days
      transition_to_glacier_days = 30

      # Delete after 90 days
      expiration_days = 90

      # Abort incomplete uploads after 1 day
      abort_incomplete_upload_days = 1
    }
  ]

  # Additional tags
  additional_tags = {
    Name      = "${local.name_prefix}-logs"
    Component = "logging"
  }
}

# Enable access logging on main bucket
resource "aws_s3_bucket_logging" "fileflow_bucket_logging" {
  bucket = module.fileflow_bucket.bucket_id

  target_bucket = module.fileflow_logs_bucket.bucket_id
  target_prefix = "access-logs/"
}

# Bucket policy for ECS task role access
resource "aws_s3_bucket_policy" "fileflow_bucket_policy" {
  bucket = module.fileflow_bucket.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTaskAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.fileflow_bucket.bucket_arn,
          "${module.fileflow_bucket.bucket_arn}/*"
        ]
      }
    ]
  })
}
