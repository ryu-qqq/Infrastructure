# S3 Buckets for CloudTrail
# Using s3-bucket module v1.0.0 for standardized configuration

# CloudTrail Logs Bucket
module "cloudtrail_logs_bucket" {
  source = "../../../modules/s3-bucket"

  bucket_name  = local.cloudtrail_bucket_name
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = "confidential"

  # KMS encryption (required for governance)
  kms_key_id = aws_kms_key.cloudtrail.arn

  # Enable versioning for audit trail
  versioning_enabled = true

  # Lifecycle policy for log retention
  lifecycle_rules = [
    {
      id      = "cloudtrail-log-retention"
      enabled = true
      prefix  = ""

      # Transition to Glacier after 30 days
      transition_to_glacier_days = 30

      # Delete after retention period
      expiration_days = var.log_retention_days

      # Clean up incomplete multipart uploads
      abort_incomplete_upload_days = 7
    }
  ]

  # Additional tags
  additional_tags = {
    Name      = local.cloudtrail_bucket_name
    Component = "cloudtrail-storage"
  }
}

# Bucket policy to allow CloudTrail to write logs
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = module.cloudtrail_logs_bucket.bucket_id

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
        Resource = module.cloudtrail_logs_bucket.bucket_arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${module.cloudtrail_logs_bucket.bucket_arn}/${var.s3_key_prefix}/AWSLogs/${var.aws_account_id}/*"
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
        Resource = "${module.cloudtrail_logs_bucket.bucket_arn}/*"
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
          module.cloudtrail_logs_bucket.bucket_arn,
          "${module.cloudtrail_logs_bucket.bucket_arn}/*"
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
module "athena_results_bucket" {
  count  = var.enable_athena ? 1 : 0
  source = "../../../modules/s3-bucket"

  bucket_name  = local.athena_result_bucket_name
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = "internal"

  # Note: Using AES256 for Athena results (Athena limitation)
  # KMS encryption is not supported for Athena query results
  kms_key_id = null

  # Versioning not needed for temporary query results
  versioning_enabled = false

  # Lifecycle policy for Athena query results
  lifecycle_rules = [
    {
      id                           = "athena-results-cleanup"
      enabled                      = true
      prefix                       = ""
      expiration_days              = 7
      abort_incomplete_upload_days = 3
    }
  ]

  # Additional tags
  additional_tags = {
    Name      = local.athena_result_bucket_name
    Component = "athena-results"
  }
}
