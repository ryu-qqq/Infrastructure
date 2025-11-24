# ============================================================================
# GitHub Actions IAM Role and Policies
# ============================================================================

# Data source for existing GitHub OIDC provider
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# GitHub Actions IAM Role using iam-role-policy module
module "github_actions_role" {
  source = "../../modules/iam-role-policy"

  role_name    = "GitHubActionsRole"
  description  = "IAM role for GitHub Actions workflows to deploy infrastructure"
  environment  = var.environment
  service_name = "github-actions"
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class

  # Assume role policy for GitHub OIDC
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:ryu-qqq/Infrastructure:*",
              "repo:ryu-qqq/fileflow:*"
            ]
          }
        }
      }
    ]
  })

  # Custom inline policies
  custom_inline_policies = {
    terraform-state = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "TerraformStateS3Access"
            Effect = "Allow"
            Action = [
              "s3:ListBucket",
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = [
              module.terraform_state_bucket.bucket_arn,
              "${module.terraform_state_bucket.bucket_arn}/*"
            ]
          },
          {
            Sid    = "TerraformStateLocking"
            Effect = "Allow"
            Action = [
              "dynamodb:GetItem",
              "dynamodb:PutItem",
              "dynamodb:DeleteItem",
              "dynamodb:DescribeTable"
            ]
            Resource = aws_dynamodb_table.terraform-lock.arn
          },
          {
            Sid    = "DynamoDBListTables"
            Effect = "Allow"
            Action = [
              "dynamodb:ListTables"
            ]
            Resource = "*"
          }
        ]
      })
    }
    ssm-access = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
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
              "ssm:RemoveTagsFromResource"
            ]
            Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/shared/*"
          },
          {
            Sid    = "SSMDescribe"
            Effect = "Allow"
            Action = [
              "ssm:DescribeParameters"
            ]
            Resource = "*"
          }
        ]
      })
    }
    kms-access = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "KMSKeyManagement"
            Effect = "Allow"
            Action = [
              "kms:Decrypt",
              "kms:Encrypt",
              "kms:DescribeKey",
              "kms:CreateGrant",
              "kms:ListGrants",
              "kms:RevokeGrant",
              "kms:GetKeyPolicy",
              "kms:GetKeyRotationStatus"
            ]
            Resource = [
              aws_kms_key.terraform-state.arn,
              "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
            ]
          },
          {
            Sid    = "KMSList"
            Effect = "Allow"
            Action = [
              "kms:ListKeys",
              "kms:ListAliases"
            ]
            Resource = "*"
          }
        ]
      })
    }
    resource-management = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "EC2ReadOnly"
            Effect = "Allow"
            Action = [
              "ec2:Describe*",
              "ec2:Get*"
            ]
            Resource = "*"
          },
          {
            Sid    = "VPCManagement"
            Effect = "Allow"
            Action = [
              "ec2:CreateVpc",
              "ec2:DeleteVpc",
              "ec2:ModifyVpcAttribute",
              "ec2:CreateSubnet",
              "ec2:DeleteSubnet",
              "ec2:CreateInternetGateway",
              "ec2:DeleteInternetGateway",
              "ec2:AttachInternetGateway",
              "ec2:DetachInternetGateway",
              "ec2:CreateRouteTable",
              "ec2:DeleteRouteTable",
              "ec2:CreateRoute",
              "ec2:DeleteRoute",
              "ec2:AssociateRouteTable",
              "ec2:DisassociateRouteTable",
              "ec2:CreateNatGateway",
              "ec2:DeleteNatGateway",
              "ec2:AllocateAddress",
              "ec2:ReleaseAddress",
              "ec2:CreateTags",
              "ec2:DeleteTags"
            ]
            Resource = "*"
          },
          {
            Sid    = "KMSManagement"
            Effect = "Allow"
            Action = [
              "kms:CreateKey",
              "kms:CreateAlias",
              "kms:DeleteAlias",
              "kms:UpdateAlias",
              "kms:EnableKeyRotation",
              "kms:DisableKeyRotation",
              "kms:GetKeyRotationStatus",
              "kms:GetKeyPolicy",
              "kms:PutKeyPolicy",
              "kms:ScheduleKeyDeletion",
              "kms:CancelKeyDeletion",
              "kms:TagResource",
              "kms:UntagResource"
            ]
            Resource = "*"
          },
          {
            Sid    = "IAMReadOnly"
            Effect = "Allow"
            Action = [
              "iam:GetRole",
              "iam:GetRolePolicy",
              "iam:GetPolicy",
              "iam:GetPolicyVersion",
              "iam:ListRolePolicies",
              "iam:ListAttachedRolePolicies",
              "iam:ListPolicyVersions",
              "iam:ListInstanceProfilesForRole"
            ]
            Resource = "*"
          },
          {
            Sid    = "IAMManagement"
            Effect = "Allow"
            Action = [
              "iam:CreateRole",
              "iam:DeleteRole",
              "iam:UpdateRole",
              "iam:PutRolePolicy",
              "iam:DeleteRolePolicy",
              "iam:AttachRolePolicy",
              "iam:DetachRolePolicy",
              "iam:TagRole",
              "iam:UntagRole",
              "iam:PassRole"
            ]
            Resource = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/atlantis-*",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-ecs-*",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-execution-role",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-task-role"
            ]
          }
        ]
      })
    }
  }

  # Additional tags
  additional_tags = {
    Component = "ci-cd"
  }
}

# Managed Policy for FileFlow infrastructure
resource "aws_iam_policy" "github-actions-fileflow" {
  name        = "GitHubActionsFileFlowPolicy"
  description = "Permissions for deploying FileFlow infrastructure"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ElastiCacheManagement"
        Effect = "Allow"
        Action = [
          "elasticache:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsManagement"
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Management"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "SQSManagement"
        Effect = "Allow"
        Action = [
          "sqs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSManagement"
        Effect = "Allow"
        Action = [
          "ecs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ALBManagement"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityGroupManagement"
        Effect = "Allow"
        Action = [
          "ec2:*SecurityGroup*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Owner       = var.owner
      CostCenter  = var.cost_center
      Environment = var.environment
      Lifecycle   = var.lifecycle
      DataClass   = var.data_class
      Service     = var.service
      ManagedBy   = "terraform"
      Project     = var.project
    },
    {
      Name      = "github-actions-fileflow-policy"
      Component = "ci-cd"
    }
  )
}

# Attach FileFlow policy to GitHubActionsRole
resource "aws_iam_role_policy_attachment" "github-actions-fileflow" {
  role       = module.github_actions_role.role_name
  policy_arn = aws_iam_policy.github-actions-fileflow.arn
}

# Outputs
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = module.github_actions_role.role_arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = module.github_actions_role.role_name
}
