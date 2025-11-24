# S3 Bucket Module
# Provides standardized S3 bucket creation with governance compliance

# Common Tags Module
module "tags" {
  source = "../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = var.additional_tags
}

# S3 Bucket
resource "aws_s3_bucket" "this" {
  bucket              = var.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.enable_object_lock

  tags = merge(
    local.required_tags,
    {
      Name = var.bucket_name
    }
  )
}

# Server-Side Encryption Configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : false
  }
}

# Versioning Configuration
resource "aws_s3_bucket_versioning" "this" {
  count  = var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Object Lock Configuration (requires versioning)
resource "aws_s3_bucket_object_lock_configuration" "this" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode  = var.object_lock_mode
      days  = var.object_lock_retention_days
      years = var.object_lock_retention_years
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# Public Access Block Configuration
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# Logging Configuration
resource "aws_s3_bucket_logging" "this" {
  count  = var.logging_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_target_prefix
}

# Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "filter" {
        for_each = rule.value.prefix != null ? [1] : []
        content {
          prefix = rule.value.prefix
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "transition" {
        for_each = rule.value.transition_to_ia_days != null ? [1] : []
        content {
          days          = rule.value.transition_to_ia_days
          storage_class = "STANDARD_IA"
        }
      }

      dynamic "transition" {
        for_each = rule.value.transition_to_glacier_days != null ? [1] : []
        content {
          days          = rule.value.transition_to_glacier_days
          storage_class = "GLACIER"
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_expiration_days
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_upload_days != null ? [1] : []
        content {
          days_after_initiation = rule.value.abort_incomplete_upload_days
        }
      }
    }
  }
}

# CORS Configuration
resource "aws_s3_bucket_cors_configuration" "this" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# Static Website Configuration
resource "aws_s3_bucket_website_configuration" "this" {
  count  = var.enable_static_website ? 1 : 0
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = var.website_index_document
  }

  error_document {
    key = var.website_error_document
  }
}

# Request Metrics Configuration
resource "aws_s3_bucket_metric" "this" {
  count  = var.enable_request_metrics ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "EntireBucket"

  dynamic "filter" {
    for_each = var.request_metrics_filter_prefix != "" ? [1] : []
    content {
      prefix = var.request_metrics_filter_prefix
    }
  }
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

# Bucket Size Alarm
resource "aws_cloudwatch_metric_alarm" "bucket-size" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.bucket_name}-bucket-size"
  alarm_description   = "S3 bucket ${var.bucket_name} - Storage size exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_bucket_size_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName  = aws_s3_bucket.this.id
    StorageType = "StandardStorage"
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    local.required_tags,
    {
      Name = "${var.bucket_name}-size-alarm"
    }
  )
}

# Object Count Alarm
resource "aws_cloudwatch_metric_alarm" "object-count" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.bucket_name}-object-count"
  alarm_description   = "S3 bucket ${var.bucket_name} - Object count exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfObjects"
  namespace           = "AWS/S3"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_object_count_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName  = aws_s3_bucket.this.id
    StorageType = "AllStorageTypes"
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    local.required_tags,
    {
      Name = "${var.bucket_name}-object-count-alarm"
    }
  )
}
