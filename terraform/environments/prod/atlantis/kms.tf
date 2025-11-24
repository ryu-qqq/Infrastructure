# KMS Keys for Atlantis
# Note: KMS resources kept as raw resources (no module available)

data "aws_caller_identity" "current" {}

# KMS Key for ECR Encryption
resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name      = "ecr-atlantis"
      Component = "atlantis"
    }
  )
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/ecr-atlantis"
  target_key_id = aws_kms_key.ecr.key_id
}

# KMS Key Policy for ECR
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

# KMS Key for EFS Encryption
resource "aws_kms_key" "efs" {
  description             = "KMS key for EFS file system encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name      = "efs-atlantis"
      Component = "atlantis"
    }
  )
}

resource "aws_kms_alias" "efs" {
  name          = "alias/efs-atlantis"
  target_key_id = aws_kms_key.efs.key_id
}

# KMS Key Policy for EFS
resource "aws_kms_key_policy" "efs" {
  key_id = aws_kms_key.efs.id

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
        Sid    = "Allow GitHub Actions to manage the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitHubActionsRole"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow EFS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "elasticfilesystem.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow EFS service-linked role to use the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/elasticfilesystem.amazonaws.com/AWSServiceRoleForAmazonElasticFileSystem"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow ECS tasks to use the key for EFS"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

output "efs_kms_key_id" {
  description = "The ID of the KMS key for EFS encryption"
  value       = aws_kms_key.efs.key_id
}

output "efs_kms_key_arn" {
  description = "The ARN of the KMS key for EFS encryption"
  value       = aws_kms_key.efs.arn
}
