# S3 Bucket for CloudTrail Logs
# Central repository for all CloudTrail logs with encryption and lifecycle policies

# CloudTrail Logs Bucket
resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.cloudtrail_bucket_name

  tags = merge(
    local.required_tags,
    {
      Name      = local.cloudtrail_bucket_name
      DataClass = "confidential"
      Component = "cloudtrail-storage"
    }
  )
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for audit trail
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.cloudtrail.arn
    }
    bucket_key_enabled = true
  }
}

# Lifecycle policy for log retention
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "cloudtrail-log-retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Transition to Glacier after 30 days
    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    # Delete after retention period
    expiration {
      days = var.log_retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/${var.s3_key_prefix}/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "DenyUnencryptedObjectUploads"
        Effect = "Deny"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Athena Query Results Bucket
resource "aws_s3_bucket" "athena-results" {
  count  = var.enable_athena ? 1 : 0
  bucket = local.athena_result_bucket_name

  tags = merge(
    local.required_tags,
    {
      Name      = local.athena_result_bucket_name
      DataClass = "internal"
      Component = "athena-results"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "athena-results" {
  count  = var.enable_athena ? 1 : 0
  bucket = aws_s3_bucket.athena-results[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena-results" {
  count  = var.enable_athena ? 1 : 0
  bucket = aws_s3_bucket.athena-results[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy for Athena query results
resource "aws_s3_bucket_lifecycle_configuration" "athena-results" {
  count  = var.enable_athena ? 1 : 0
  bucket = aws_s3_bucket.athena-results[0].id

  rule {
    id     = "athena-results-cleanup"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7
    }
  }
}
