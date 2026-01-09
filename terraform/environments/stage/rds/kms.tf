# Customer-managed KMS Keys
# Zero-Tolerance: AWS 관리형 키(alias/aws/*) 사용 금지 - 고객 관리형 KMS 키 필수

# RDS 암호화용 고객 관리형 KMS 키
resource "aws_kms_key" "rds" {
  description             = "Customer-managed KMS key for staging RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # KMS 키 정책 - RDS 서비스 접근 허용
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "rds-key-policy"
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
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name    = "${local.name_prefix}-rds-kms"
      Purpose = "RDS encryption"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# Secrets Manager 암호화용 고객 관리형 KMS 키
resource "aws_kms_key" "secrets_manager" {
  description             = "Customer-managed KMS key for staging Secrets Manager encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # KMS 키 정책 - Secrets Manager 서비스 접근 허용
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "secrets-manager-key-policy"
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
        Sid    = "Allow Secrets Manager to use the key"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name    = "${local.name_prefix}-secrets-manager-kms"
      Purpose = "Secrets Manager encryption"
    }
  )
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/${local.name_prefix}-secrets-manager"
  target_key_id = aws_kms_key.secrets_manager.key_id
}
