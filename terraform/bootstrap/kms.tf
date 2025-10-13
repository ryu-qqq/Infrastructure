# KMS Key for Terraform State Encryption
# Following governance standards for data-class based key separation

data "aws_caller_identity" "current" {}

# KMS key for S3 state bucket encryption
resource "aws_kms_key" "terraform-state" {
  description             = "KMS key for Terraform state S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "terraform-state-${var.environment}"
      Component = "terraform-backend"
    }
  )
}

resource "aws_kms_alias" "terraform-state" {
  name          = "alias/terraform-state-${var.environment}"
  target_key_id = aws_kms_key.terraform-state.key_id
}

# KMS Key Policy
resource "aws_kms_key_policy" "terraform-state" {
  key_id = aws_kms_key.terraform-state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Terraform state access"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

output "kms_key_id" {
  description = "The ID of the KMS key for Terraform state encryption"
  value       = aws_kms_key.terraform-state.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key for Terraform state encryption"
  value       = aws_kms_key.terraform-state.arn
}
