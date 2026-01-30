# KMS Key for ElastiCache encryption
# Zero-Tolerance: AWS 관리형 키 사용 금지, 고객 관리형 키 필수

resource "aws_kms_key" "elasticache" {
  description             = "KMS key for ElastiCache encryption - ${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 7 # Stage 환경에서는 짧은 삭제 대기 기간

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
        Sid    = "Allow ElastiCache to use the key"
        Effect = "Allow"
        Principal = {
          Service = "elasticache.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-kms"
      Component = "encryption"
    }
  )
}

resource "aws_kms_alias" "elasticache" {
  name          = "alias/${var.environment}-elasticache"
  target_key_id = aws_kms_key.elasticache.key_id
}
