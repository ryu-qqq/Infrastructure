# KMS Key for ECR Encryption
# Following governance standards for data-class based key separation

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "ecr-atlantis"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "infrastructure"
    Component   = "atlantis"
    Service     = "atlantis"
    DataClass   = "confidential"
  }
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/ecr-atlantis"
  target_key_id = aws_kms_key.ecr.key_id
}

# KMS Key Policy
resource "aws_kms_key_policy" "ecr" {
  key_id = aws_kms_key.ecr.id

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
        Sid    = "Allow ECR to use the key"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow ECS tasks to decrypt images"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

output "ecr_kms_key_id" {
  description = "The ID of the KMS key for ECR encryption"
  value       = aws_kms_key.ecr.key_id
}

output "ecr_kms_key_arn" {
  description = "The ARN of the KMS key for ECR encryption"
  value       = aws_kms_key.ecr.arn
}
