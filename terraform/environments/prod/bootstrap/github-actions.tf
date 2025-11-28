# ============================================================================
# GitHub Actions IAM Role and Policies
# Centralized role for all project repositories
# ============================================================================

# Data source for existing GitHub OIDC provider
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Local values for GitHub Actions
locals {
  github_org = "ryu-qqq"

  # Generate repo conditions from variable
  repo_conditions = [
    for repo in var.allowed_github_repos : "repo:${local.github_org}/${repo}:*"
  ]

  # Common tags for GitHub Actions resources
  github_actions_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    Service     = var.service
    Team        = var.team
    ManagedBy   = "terraform"
    Project     = var.project
    Component   = "ci-cd"
  }
}

# ============================================================================
# GitHub Actions IAM Role (existing - keep PascalCase name for compatibility)
# ============================================================================
resource "aws_iam_role" "github-actions" {
  name        = "GitHubActionsRole"
  description = "Centralized IAM role for GitHub Actions workflows across all projects"

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
            # Dynamic repo list from variable
            "token.actions.githubusercontent.com:sub" = local.repo_conditions
          }
        }
      }
    ]
  })

  tags = merge(local.github_actions_tags, {
    Name = "GitHubActionsRole"
  })
}

# ============================================================================
# Managed Policies - Terraform State & Core Access
# ============================================================================
resource "aws_iam_policy" "github-actions-terraform-state" {
  name        = "GitHubActionsTerraformStatePolicy"
  description = "Terraform state management permissions"

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
          "arn:aws:s3:::prod-connectly",
          "arn:aws:s3:::prod-connectly/*",
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
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/prod-connectly-tf-lock",
          aws_dynamodb_table.terraform-lock.arn
        ]
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

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-terraform-state-policy"
  })
}

resource "aws_iam_policy" "github-actions-ssm" {
  name        = "GitHubActionsSSMPolicy"
  description = "SSM parameter management permissions"

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
        Resource = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/*"
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

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-ssm-policy"
  })
}

resource "aws_iam_policy" "github-actions-kms" {
  name        = "GitHubActionsKMSPolicy"
  description = "KMS key management permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KMSKeyManagement"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:CreateKey",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias",
          "kms:EnableKeyRotation",
          "kms:DisableKeyRotation",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:TagResource",
          "kms:UntagResource"
        ]
        Resource = [
          aws_kms_key.terraform-state.arn,
          "arn:aws:kms:${var.aws_region}:${local.account_id}:key/*"
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

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-kms-policy"
  })
}

# Policy Attachments for Core Access
resource "aws_iam_role_policy_attachment" "github-actions-terraform-state" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-terraform-state.arn
}

resource "aws_iam_role_policy_attachment" "github-actions-ssm" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-ssm.arn
}

resource "aws_iam_role_policy_attachment" "github-actions-kms" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-kms.arn
}

# ============================================================================
# Managed Policies - Infrastructure (VPC, EC2, IAM)
# ============================================================================
resource "aws_iam_policy" "github-actions-infrastructure" {
  name        = "GitHubActionsInfrastructurePolicy"
  description = "Shared infrastructure permissions for all projects"

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
        Sid    = "SecurityGroupManagement"
        Effect = "Allow"
        Action = [
          "ec2:*SecurityGroup*"
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
          "iam:ListRoles",
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
          # All naming patterns for prod roles
          "arn:aws:iam::${local.account_id}:role/*-prod-*",
          "arn:aws:iam::${local.account_id}:role/*-prod",
          "arn:aws:iam::${local.account_id}:role/prod-*",
          "arn:aws:iam::${local.account_id}:role/*-role-prod",
          "arn:aws:iam::${local.account_id}:role/atlantis-*"
        ]
      }
    ]
  })

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-infrastructure-policy"
  })
}

# ============================================================================
# Managed Policies - ECS
# ============================================================================
resource "aws_iam_policy" "github-actions-ecs" {
  name        = "GitHubActionsECSPolicy"
  description = "ECS management permissions for all projects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSReadOnly"
        Effect = "Allow"
        Action = [
          "ecs:Describe*",
          "ecs:List*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSManagement"
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster",
          "ecs:DeleteCluster",
          "ecs:UpdateCluster",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:TagResource",
          "ecs:UntagResource",
          "ecs:PutClusterCapacityProviders"
        ]
        Resource = "*"
      },
      {
        Sid    = "ApplicationAutoScaling"
        Effect = "Allow"
        Action = [
          "application-autoscaling:RegisterScalableTarget",
          "application-autoscaling:DeregisterScalableTarget",
          "application-autoscaling:DescribeScalableTargets",
          "application-autoscaling:DescribeScalingActivities",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DeleteScalingPolicy",
          "application-autoscaling:DescribeScalingPolicies",
          "application-autoscaling:PutScheduledAction",
          "application-autoscaling:DeleteScheduledAction",
          "application-autoscaling:DescribeScheduledActions",
          "application-autoscaling:TagResource",
          "application-autoscaling:UntagResource",
          "application-autoscaling:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "CodeDeployECS"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateApplication",
          "codedeploy:DeleteApplication",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:CreateDeploymentGroup",
          "codedeploy:DeleteDeploymentGroup",
          "codedeploy:GetDeploymentGroup",
          "codedeploy:UpdateDeploymentGroup",
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:ListDeploymentConfigs",
          "codedeploy:StopDeployment",
          "codedeploy:ContinueDeployment",
          "codedeploy:BatchGetDeploymentGroups",
          "codedeploy:BatchGetDeployments",
          "codedeploy:BatchGetApplications",
          "codedeploy:ListApplications",
          "codedeploy:ListDeploymentGroups",
          "codedeploy:ListDeployments",
          "codedeploy:TagResource",
          "codedeploy:UntagResource",
          "codedeploy:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-ecs-policy"
  })
}

# ============================================================================
# Managed Policies - ECR
# ============================================================================
resource "aws_iam_policy" "github-actions-ecr" {
  name        = "GitHubActionsECRPolicy"
  description = "ECR management permissions for all projects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRReadOnly"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages",
          "ecr:ListTagsForResource",
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:PutLifecyclePolicy",
          "ecr:GetLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:SetRepositoryPolicy",
          "ecr:GetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/*"
      }
    ]
  })

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-ecr-policy"
  })
}

# ============================================================================
# Managed Policies - CloudWatch & Logs
# ============================================================================
resource "aws_iam_policy" "github-actions-cloudwatch" {
  name        = "GitHubActionsCloudWatchPolicy"
  description = "CloudWatch and logging permissions for all projects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsManagement"
        Effect = "Allow"
        Action = [
          "logs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchAlarmsManagement"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-cloudwatch-policy"
  })
}

# ============================================================================
# Managed Policies - S3
# ============================================================================
resource "aws_iam_policy" "github-actions-s3" {
  name        = "GitHubActionsS3Policy"
  description = "S3 management permissions for all projects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Management"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-s3-policy"
  })
}

# ============================================================================
# Managed Policies - Additional Services (SQS, ElastiCache, ALB, Route53, AMP, Grafana, SNS, Chatbot)
# ============================================================================
resource "aws_iam_policy" "github-actions-services" {
  name        = "GitHubActionsServicesPolicy"
  description = "Additional AWS services permissions for all projects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SQSManagement"
        Effect = "Allow"
        Action = [
          "sqs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "ElastiCacheManagement"
        Effect = "Allow"
        Action = [
          "elasticache:*"
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
        Sid    = "Route53Management"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Sid    = "PrometheusManagement"
        Effect = "Allow"
        Action = [
          "aps:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "GrafanaManagement"
        Effect = "Allow"
        Action = [
          "grafana:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchTagging"
        Effect = "Allow"
        Action = [
          "cloudwatch:ListTagsForResource",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "SNSManagement"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:SetTopicAttributes",
          "sns:ListTopics",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:TagResource",
          "sns:UntagResource",
          "sns:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "ChatbotManagement"
        Effect = "Allow"
        Action = [
          "chatbot:CreateSlackChannelConfiguration",
          "chatbot:DeleteSlackChannelConfiguration",
          "chatbot:DescribeSlackChannelConfigurations",
          "chatbot:UpdateSlackChannelConfiguration",
          "chatbot:DescribeSlackWorkspaces",
          "chatbot:ListMicrosoftTeamsChannelConfigurations",
          "chatbot:TagResource",
          "chatbot:UntagResource",
          "chatbot:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-services-policy"
  })
}

# ============================================================================
# Policy Attachments
# ============================================================================
resource "aws_iam_role_policy_attachment" "github-actions-infrastructure" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-infrastructure.arn
}

resource "aws_iam_role_policy_attachment" "github-actions-ecs" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-ecs.arn
}

resource "aws_iam_role_policy_attachment" "github-actions-ecr" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-ecr.arn
}

resource "aws_iam_role_policy_attachment" "github-actions-cloudwatch" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-cloudwatch.arn
}

resource "aws_iam_role_policy_attachment" "github-actions-s3" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-s3.arn
}

resource "aws_iam_role_policy_attachment" "github-actions-services" {
  role       = aws_iam_role.github-actions.name
  policy_arn = aws_iam_policy.github-actions-services.arn
}

# ============================================================================
# SSM Parameters for GitHub Actions Configuration
# ============================================================================
resource "aws_ssm_parameter" "github-actions-role-arn" {
  name        = "/github-actions/role-arn"
  description = "GitHub Actions IAM Role ARN for CI/CD workflows"
  type        = "String"
  value       = aws_iam_role.github-actions.arn

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-role-arn"
  })
}

resource "aws_ssm_parameter" "github-actions-allowed-repos" {
  name        = "/github-actions/allowed-repos"
  description = "List of GitHub repositories allowed to use the GitHub Actions role"
  type        = "StringList"
  value       = join(",", var.allowed_github_repos)

  tags = merge(local.github_actions_tags, {
    Name = "github-actions-allowed-repos"
  })
}

# ============================================================================
# Outputs
# ============================================================================
output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = aws_iam_role.github-actions.arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = aws_iam_role.github-actions.name
}

output "allowed_repositories" {
  description = "List of GitHub repositories allowed to use this role"
  value       = var.allowed_github_repos
}

output "github_actions_role_arn_ssm_parameter" {
  description = "SSM Parameter name for GitHub Actions Role ARN"
  value       = aws_ssm_parameter.github-actions-role-arn.name
}

# ============================================================================
# Slack Webhook URL for Deployment Notifications
# ============================================================================
resource "aws_ssm_parameter" "slack-webhook-deployments" {
  name        = "/github-actions/slack-webhook-deployments"
  description = "Slack Incoming Webhook URL for deployment notifications"
  type        = "SecureString"
  value       = var.slack_webhook_url

  tags = merge(local.github_actions_tags, {
    Name      = "slack-webhook-deployments"
    Component = "notifications"
  })
}

output "slack_webhook_ssm_parameter" {
  description = "SSM Parameter name for Slack Webhook URL"
  value       = aws_ssm_parameter.slack-webhook-deployments.name
}
