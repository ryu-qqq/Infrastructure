# ==============================================================================
# Advanced WAF Example
# ==============================================================================
# This example demonstrates a production-ready WAF configuration with:
# - All AWS Managed Rules
# - Geo blocking
# - Kinesis Firehose logging
# - CloudWatch alarms
# - Resource associations
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# ==============================================================================
# Common Tags
# ==============================================================================

module "common_tags" {
  source = "../../../common-tags"

  environment = "prod"
  service     = "api-gateway"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

# ==============================================================================
# S3 Bucket for WAF Logs
# ==============================================================================

module "waf_logs_bucket" {
  source = "../../../s3-bucket"

  bucket_name = "prod-waf-logs-${data.aws_caller_identity.current.account_id}"
  purpose     = "waf-logs"

  versioning_enabled = false
  lifecycle_rules = [
    {
      id      = "archive-old-logs"
      enabled = true
      transitions = [
        {
          days          = 90
          storage_class = "INTELLIGENT_TIERING"
        },
        {
          days          = 365
          storage_class = "GLACIER"
        }
      ]
      expiration_days = 2555 # 7 years
    }
  ]

  common_tags = module.common_tags.tags
}

# ==============================================================================
# IAM Role for Kinesis Firehose
# ==============================================================================

resource "aws_iam_role" "firehose" {
  name = "prod-waf-logs-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    module.common_tags.tags,
    {
      Name = "prod-waf-logs-firehose-role"
    }
  )
}

resource "aws_iam_role_policy" "firehose_s3" {
  name = "firehose-s3-policy"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.waf_logs_bucket.bucket_arn,
          "${module.waf_logs_bucket.bucket_arn}/*"
        ]
      }
    ]
  })
}

# ==============================================================================
# Kinesis Firehose Delivery Stream
# ==============================================================================

resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  name        = "aws-waf-logs-prod"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = module.waf_logs_bucket.bucket_arn
    prefix     = "waf-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    error_output_prefix = "waf-logs-errors/"

    compression_format = "GZIP"

    buffer_size     = 5   # MB
    buffer_interval = 300 # seconds

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/waf-logs"
      log_stream_name = "S3Delivery"
    }
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "aws-waf-logs-prod"
    }
  )
}

# ==============================================================================
# WAF Configuration with All Features
# ==============================================================================

module "waf" {
  source = "../../"

  name        = "prod-api-gateway-waf"
  scope       = "REGIONAL"
  description = "Production WAF for API Gateway with comprehensive security rules"

  # AWS Managed Rules
  enable_owasp_rules   = true
  enable_ip_reputation = true
  enable_anonymous_ip  = true # Block VPN/Proxy/Tor

  # Rate Limiting (3000 requests per 5 minutes per IP)
  enable_rate_limiting = true
  rate_limit           = 3000

  # Geo Blocking (block high-risk countries)
  enable_geo_blocking = true
  blocked_countries = [
    "KP", # North Korea
    "CU", # Cuba
    "IR", # Iran
    "SY"  # Syria
  ]

  # Logging Configuration
  enable_logging      = true
  log_destination_arn = aws_kinesis_firehose_delivery_stream.waf_logs.arn

  redacted_fields = [
    {
      type = "single_header"
      name = "authorization"
    },
    {
      type = "single_header"
      name = "cookie"
    }
  ]

  # CloudWatch Metrics
  enable_cloudwatch_metrics = true
  metric_name               = "prod-api-gateway-waf"
  sampled_requests_enabled  = true

  # Standard Tags
  common_tags = module.common_tags.tags

  depends_on = [
    aws_kinesis_firehose_delivery_stream.waf_logs
  ]
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests_high" {
  alarm_name          = "${module.waf.web_acl_name}-blocked-requests-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000
  alarm_description   = "Alert when WAF blocks more than 1000 requests in 5 minutes"

  dimensions = {
    WebACL = module.waf.web_acl_name
    Region = "ap-northeast-2"
    Rule   = "ALL"
  }

  tags = module.common_tags.tags
}

resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_triggered" {
  alarm_name          = "${module.waf.web_acl_name}-rate-limit-triggered"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Alert when rate limiting blocks requests"

  dimensions = {
    WebACL = module.waf.web_acl_name
    Region = "ap-northeast-2"
    Rule   = "${module.waf.web_acl_name}-rate-limit"
  }

  tags = module.common_tags.tags
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_caller_identity" "current" {}

# ==============================================================================
# Outputs
# ==============================================================================

output "web_acl_arn" {
  description = "ARN of the WAF WebACL (use this to associate with ALB/API Gateway)"
  value       = module.waf.web_acl_arn
}

output "web_acl_id" {
  description = "ID of the WAF WebACL"
  value       = module.waf.web_acl_id
}

output "enabled_features" {
  description = "Summary of enabled WAF features"
  value       = module.waf.enabled_features
}

output "firehose_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.waf_logs.arn
}

output "logs_bucket_name" {
  description = "Name of the S3 bucket storing WAF logs"
  value       = module.waf_logs_bucket.bucket_name
}

output "cloudwatch_alarms" {
  description = "CloudWatch alarm ARNs"
  value = {
    high_blocked_requests = aws_cloudwatch_metric_alarm.waf_blocked_requests_high.arn
    rate_limit_triggered  = aws_cloudwatch_metric_alarm.waf_rate_limit_triggered.arn
  }
}
