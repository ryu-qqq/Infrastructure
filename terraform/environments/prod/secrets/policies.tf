# IAM Policies for Secrets Manager

# Policy for service applications to read secrets
data "aws_iam_policy_document" "service_read_secrets" {
  # Allow reading secrets
  statement {
    sid    = "AllowReadSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:/${local.org_name}/*"
    ]
  }

  # Allow KMS decryption via Secrets Manager
  statement {
    sid    = "AllowKMSDecryptViaSecretsManager"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]

    resources = [
      data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }
}

# Example: Crawler service specific policy
resource "aws_iam_policy" "crawler-secrets-read" {
  name        = "crawler-secrets-read-policy"
  description = "Policy for crawler service to read its secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadCrawlerSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:/${local.org_name}/crawler/*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:/${local.org_name}/common/*"
        ]
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "crawler-secrets-read-policy"
    }
  )
}

# Market service specific policy
resource "aws_iam_policy" "market-secrets-read" {
  name        = "market-secrets-read-policy"
  description = "Policy for market service to read its secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadMarketSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:/${local.org_name}/market/*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:/${local.org_name}/common/*"
        ]
      },
      {
        Sid    = "AllowKMSDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "market-secrets-read-policy"
    }
  )
}

# Policy for DevOps team to manage secrets
data "aws_iam_policy_document" "devops_manage_secrets" {
  # Full secrets management
  statement {
    sid    = "AllowManageSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:RotateSecret",
      "secretsmanager:CancelRotateSecret",
      "secretsmanager:ListSecrets",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]

    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:/${local.org_name}/*"
    ]
  }

  # KMS key access for encryption/decryption
  statement {
    sid    = "AllowKMSOperations"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
      "kms:CreateGrant"
    ]

    resources = [
      data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
    ]
  }
}

resource "aws_iam_policy" "devops-secrets-management" {
  name        = "devops-secrets-management-policy"
  description = "Policy for DevOps team to manage all secrets"
  policy      = data.aws_iam_policy_document.devops_manage_secrets.json

  tags = merge(
    local.required_tags,
    {
      Name = "devops-secrets-management-policy"
    }
  )
}

# GitHub Actions policy for CI/CD
resource "aws_iam_policy" "github-actions-secrets" {
  name        = "github-actions-secrets-policy"
  description = "Policy for GitHub Actions to read and create secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadAndCreateSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:/${local.org_name}/*"
      },
      {
        Sid    = "AllowKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "github-actions-secrets-policy"
    }
  )
}
