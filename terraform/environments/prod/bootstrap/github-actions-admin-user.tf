# ============================================================================
# GitHub Actions Admin IAM User
# IAM User for GitHub Actions with programmatic access (Access Keys)
# Used for workflows that cannot use OIDC-based authentication
# ============================================================================

# ============================================================================
# IAM User Definition
# ============================================================================
resource "aws_iam_user" "github-actions-admin" {
  name = "github-actions-admin"
  path = "/"

  tags = merge(local.github_actions_tags, {
    Name        = "github-actions-admin"
    Description = "IAM User for GitHub Actions CI/CD workflows"
  })
}

# ============================================================================
# IAM User Policy - Terraform Backend Access
# Provides permissions for Terraform state management and infrastructure ops
# ============================================================================
resource "aws_iam_user_policy" "github-actions-admin-terraform-backend" {
  name = "TerraformBackendAccess"
  user = aws_iam_user.github-actions-admin.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::prod-connectly",
          "arn:aws:s3:::prod-connectly/*"
        ]
      },
      {
        Sid    = "DynamoDBTerraformLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/prod-connectly-tf-lock"
      },
      {
        Sid    = "KMSDecryptEncrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:AddTagsToResource",
          "ssm:ListTagsForResource",
          "ssm:RemoveTagsFromResource",
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = [
          "rds:Describe*",
          "rds:ListTagsForResource",
          "rds:ModifyDBInstance"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchAlarmsAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# Outputs
# ============================================================================
output "github_actions_admin_user_name" {
  description = "Name of the GitHub Actions Admin IAM User"
  value       = aws_iam_user.github-actions-admin.name
}

output "github_actions_admin_user_arn" {
  description = "ARN of the GitHub Actions Admin IAM User"
  value       = aws_iam_user.github-actions-admin.arn
}
