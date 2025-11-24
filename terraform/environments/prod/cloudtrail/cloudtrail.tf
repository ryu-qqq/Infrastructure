# CloudTrail Trail Configuration
# Multi-region trail with log file validation and CloudWatch Logs integration

# CloudWatch Logs Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = local.cloudwatch_log_group_name
  retention_in_days = 7 # Short retention in CloudWatch, long-term in S3
  kms_key_id        = aws_kms_key.cloudtrail.arn

  tags = {
    Name        = local.cloudwatch_log_group_name
    Component   = "cloudtrail-logs"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

# IAM Role for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail-cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "cloudtrail-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "cloudtrail-cloudwatch-logs-role"
    Component   = "cloudtrail"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "cloudtrail-cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "cloudtrail-cloudwatch-logs-policy"
  role  = aws_iam_role.cloudtrail-cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
      },
      {
        Sid      = "AWSCloudTrailKmsAccess"
        Effect   = "Allow"
        Action   = "kms:GenerateDataKey*"
        Resource = aws_kms_key.cloudtrail.arn
      }
    ]
  })
}

# CloudTrail Trail
resource "aws_cloudtrail" "main" {
  name                          = var.cloudtrail_name
  s3_bucket_name                = module.cloudtrail_logs_bucket.bucket_id
  s3_key_prefix                 = var.s3_key_prefix
  include_global_service_events = var.include_global_service_events
  is_multi_region_trail         = var.is_multi_region_trail
  enable_log_file_validation    = var.enable_log_file_validation
  kms_key_id                    = aws_kms_key.cloudtrail.arn

  # CloudWatch Logs integration
  cloud_watch_logs_group_arn = var.enable_cloudwatch_logs ? "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*" : null
  cloud_watch_logs_role_arn  = var.enable_cloudwatch_logs ? aws_iam_role.cloudtrail-cloudwatch[0].arn : null

  # Advanced event selectors for detailed logging
  advanced_event_selector {
    name = "Log all management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  # S3 Data Events - Disabled by default due to cost concerns
  dynamic "advanced_event_selector" {
    for_each = var.enable_s3_data_events ? [1] : []
    content {
      name = "Log S3 data events for all buckets"

      field_selector {
        field  = "eventCategory"
        equals = ["Data"]
      }

      field_selector {
        field  = "resources.type"
        equals = ["AWS::S3::Object"]
      }
    }
  }

  # Lambda Data Events - Disabled by default due to cost concerns
  dynamic "advanced_event_selector" {
    for_each = var.enable_lambda_data_events ? [1] : []
    content {
      name = "Log Lambda data events"

      field_selector {
        field  = "eventCategory"
        equals = ["Data"]
      }

      field_selector {
        field  = "resources.type"
        equals = ["AWS::Lambda::Function"]
      }
    }
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail-cloudwatch
  ]

  tags = {
    Name        = var.cloudtrail_name
    Component   = "cloudtrail"
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    ManagedBy   = "terraform"
  }
}
