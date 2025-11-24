# S3 bucket for Terraform state using s3-bucket module
module "terraform_state_bucket" {
  source = "../../../modules/s3-bucket"

  bucket_name  = var.tfstate_bucket_name
  environment  = var.environment
  service_name = var.service
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class

  # Encryption configuration
  kms_key_id = aws_kms_key.terraform-state.arn

  # Versioning
  versioning_enabled = true

  # Lifecycle rules
  lifecycle_rules = [
    {
      id                           = "expire-old-versions"
      enabled                      = true
      prefix                       = null
      expiration_days              = null
      transition_to_ia_days        = null
      transition_to_glacier_days   = null
      noncurrent_expiration_days   = 90
      abort_incomplete_upload_days = null
    },
    {
      id                           = "delete-incomplete-multipart-uploads"
      enabled                      = true
      prefix                       = null
      expiration_days              = null
      transition_to_ia_days        = null
      transition_to_glacier_days   = null
      noncurrent_expiration_days   = null
      abort_incomplete_upload_days = 7
    }
  ]

  # Additional tags
  additional_tags = {
    Component = "s3"
  }
}

# Bucket policy for terraform state bucket
resource "aws_s3_bucket_policy" "terraform-state" {
  bucket = module.terraform_state_bucket.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          module.terraform_state_bucket.bucket_arn,
          "${module.terraform_state_bucket.bucket_arn}/*"
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
        Resource  = "${module.terraform_state_bucket.bucket_arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}
