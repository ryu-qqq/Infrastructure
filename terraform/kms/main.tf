# KMS Keys for Common Platform Infrastructure
# Following governance standards for data-class based key separation

# ============================================================================
# 1. Terraform State Encryption Key (Highest Priority)
# ============================================================================

resource "aws_kms_key" "terraform-state" {
  description             = "KMS key for Terraform state file encryption in S3"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.required_tags,
    {
      Name      = "terraform-state"
      DataClass = "confidential"
      Component = "terraform-backend"
    }
  )
}

resource "aws_kms_alias" "terraform-state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform-state.key_id
}

# ============================================================================
# 2. RDS Encryption Key (Future-ready)
# ============================================================================

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS instance encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-encryption"
      DataClass = "highly-confidential"
      Component = "database"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds-encryption"
  target_key_id = aws_kms_key.rds.key_id
}

# ============================================================================
# 3. ECS Secrets Encryption Key (Short-term Priority)
# ============================================================================

resource "aws_kms_key" "ecs-secrets" {
  description             = "KMS key for ECS task secrets and environment variables encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.required_tags,
    {
      Name      = "ecs-secrets"
      DataClass = "confidential"
      Component = "ecs"
    }
  )
}

resource "aws_kms_alias" "ecs-secrets" {
  name          = "alias/ecs-secrets"
  target_key_id = aws_kms_key.ecs-secrets.key_id
}

# ============================================================================
# 4. Secrets Manager Encryption Key (Short-term Priority)
# ============================================================================

resource "aws_kms_key" "secrets-manager" {
  description             = "KMS key for AWS Secrets Manager encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  tags = merge(
    local.required_tags,
    {
      Name      = "secrets-manager"
      DataClass = "highly-confidential"
      Component = "secrets-manager"
    }
  )
}

resource "aws_kms_alias" "secrets-manager" {
  name          = "alias/secrets-manager"
  target_key_id = aws_kms_key.secrets-manager.key_id
}

# ============================================================================
# 5. CloudWatch Logs Encryption Key (IN-116)
# ============================================================================

resource "aws_kms_key" "cloudwatch-logs" {
  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

  # KMS key policy to allow CloudWatch Logs service to use the key
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
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudwatch-logs"
      DataClass = "confidential"
      Component = "cloudwatch-logs"
    }
  )
}

resource "aws_kms_alias" "cloudwatch-logs" {
  name          = "alias/cloudwatch-logs"
  target_key_id = aws_kms_key.cloudwatch-logs.key_id
}

# ============================================================================
# 6. S3 Encryption Key
# ============================================================================

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

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
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "s3-encryption"
      DataClass = "confidential"
      Component = "s3"
    }
  )
}

resource "aws_kms_alias" "s3" {
  name          = "alias/s3-encryption"
  target_key_id = aws_kms_key.s3.key_id
}

# ============================================================================
# 7. SQS Encryption Key
# ============================================================================

resource "aws_kms_key" "sqs" {
  description             = "KMS key for SQS queue encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

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
        Sid    = "Allow SQS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "sqs-encryption"
      DataClass = "confidential"
      Component = "sqs"
    }
  )
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/sqs-encryption"
  target_key_id = aws_kms_key.sqs.key_id
}

# ============================================================================
# 8. SSM Parameter Store Encryption Key
# ============================================================================

resource "aws_kms_key" "ssm" {
  description             = "KMS key for SSM Parameter Store encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

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
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "ssm-encryption"
      DataClass = "confidential"
      Component = "ssm"
    }
  )
}

resource "aws_kms_alias" "ssm" {
  name          = "alias/ssm-encryption"
  target_key_id = aws_kms_key.ssm.key_id
}

# ============================================================================
# 9. ElastiCache Encryption Key
# ============================================================================

resource "aws_kms_key" "elasticache" {
  description             = "KMS key for ElastiCache cluster encryption"
  deletion_window_in_days = var.key_deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation

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
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "elasticache-encryption"
      DataClass = "confidential"
      Component = "elasticache"
    }
  )
}

resource "aws_kms_alias" "elasticache" {
  name          = "alias/elasticache-encryption"
  target_key_id = aws_kms_key.elasticache.key_id
}
