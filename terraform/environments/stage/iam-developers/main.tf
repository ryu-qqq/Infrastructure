# IAM User for Frontend Developer - Stage RDS Access
# Purpose: Minimal permissions for SSM port forwarding to Stage RDS

# Data Sources
data "aws_caller_identity" "current" {}

# Common Tags Module
module "common_tags" {
  source = "../../../modules/common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
}

locals {
  required_tags = module.common_tags.tags
}

# ============================================================================
# IAM User
# ============================================================================

resource "aws_iam_user" "developer" {
  name = var.developer_username
  path = "/developers/"

  tags = merge(
    local.required_tags,
    {
      Name      = var.developer_username
      Email     = var.developer_email
      Purpose   = "Stage RDS access via SSM port forwarding"
      Component = "iam-user"
    }
  )
}

# ============================================================================
# IAM Policy - Stage RDS Access via SSM Port Forwarding
# ============================================================================

resource "aws_iam_policy" "stage_rds_access" {
  name        = "stage-rds-ssm-port-forwarding"
  description = "Minimal permissions for Stage RDS access via SSM port forwarding"
  path        = "/developers/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMGetBastionParameter"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/shared/bastion/instance-id"
        ]
      },
      {
        Sid    = "SSMStartSession"
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
        Condition = {
          StringLike = {
            "ssm:resourceTag/Name" = "*bastion*"
          }
        }
      },
      {
        Sid    = "SSMSessionDocument"
        Effect = "Allow"
        Action = [
          "ssm:StartSession"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}::document/AWS-StartPortForwardingSessionToRemoteHost"
        ]
      },
      {
        Sid    = "SSMTerminateSession"
        Effect = "Allow"
        Action = [
          "ssm:TerminateSession",
          "ssm:ResumeSession"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:session/${var.developer_username}-*"
        ]
      },
      {
        Sid    = "EC2DescribeInstances"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSDescribeStageInstance"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances"
        ]
        Resource = [
          "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:staging-shared-mysql"
        ]
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "stage-rds-ssm-port-forwarding"
      Component = "iam-policy"
    }
  )
}

# ============================================================================
# Attach Policy to User
# ============================================================================

resource "aws_iam_user_policy_attachment" "developer_stage_rds" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.stage_rds_access.arn
}

# ============================================================================
# Access Key for CLI Access
# ============================================================================

resource "aws_iam_access_key" "developer" {
  user = aws_iam_user.developer.name
}
