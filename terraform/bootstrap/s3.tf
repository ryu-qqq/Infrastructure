# S3 Bucket for Terraform State Storage
#
# This bucket stores Terraform state files for all environments.
# Features:
# - Versioning enabled for state history and rollback
# - KMS encryption for data at rest
# - Lifecycle policies for cost optimization
# - Public access blocked for security
# - Bucket policy for least-privilege access

resource "aws_s3_bucket" "terraform-state" {
  bucket = local.bucket_name

  tags = merge(
    local.required_tags,
    {
      Name        = local.bucket_name
      Component   = "terraform-backend"
      Description = "Terraform state storage for all environments"
    }
  )
}

# Enable versioning for state file history
resource "aws_s3_bucket_versioning" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  versioning_configuration {
    status = var.state_bucket_versioning ? "Enabled" : "Suspended"
  }
}

# Enable KMS encryption for state files
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform-state.arn
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = var.state_bucket_lifecycle_days
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.state_bucket_expiration_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Bucket policy for least-privilege access
resource "aws_s3_bucket_policy" "terraform-state" {
  bucket = aws_s3_bucket.terraform-state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform-state.arn,
          "${aws_s3_bucket.terraform-state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.terraform-state.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

output "state_bucket_id" {
  description = "The ID of the Terraform state S3 bucket"
  value       = aws_s3_bucket.terraform-state.id
}

output "state_bucket_arn" {
  description = "The ARN of the Terraform state S3 bucket"
  value       = aws_s3_bucket.terraform-state.arn
}

output "state_bucket_region" {
  description = "The region of the Terraform state S3 bucket"
  value       = aws_s3_bucket.terraform-state.region
}
