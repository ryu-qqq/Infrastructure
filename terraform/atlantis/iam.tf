# IAM Roles and Policies for Atlantis ECS Tasks

# ECS Task Execution Role
# This role is used by ECS to pull container images and publish logs
resource "aws_iam_role" "ecs-task-execution" {
  name = "atlantis-ecs-task-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-ecs-task-execution-${var.environment}"
      Component   = "atlantis"
      Description = "ECS task execution role for Atlantis"
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs-task-execution-policy" {
  role       = aws_iam_role.ecs-task-execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for KMS decryption (ECR permissions already in AmazonECSTaskExecutionRolePolicy)
resource "aws_iam_role_policy" "ecs-task-execution-kms" {
  name = "atlantis-ecs-task-execution-kms"
  role = aws_iam_role.ecs-task-execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.ecr.arn
      }
    ]
  })
}

# Policy for Secrets Manager access (GitHub App credentials and webhook secret)
resource "aws_iam_role_policy" "ecs-task-execution-secrets" {
  name = "atlantis-ecs-task-execution-secrets"
  role = aws_iam_role.ecs-task-execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.atlantis-github-app.arn,
          aws_secretsmanager_secret.atlantis-webhook-secret.arn
        ]
      }
    ]
  })
}

# ECS Task Role
# This role is used by the Atlantis container for AWS API operations
resource "aws_iam_role" "ecs-task" {
  name = "atlantis-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-ecs-task-${var.environment}"
      Component   = "atlantis"
      Description = "ECS task role for Atlantis Terraform operations"
    }
  )
}

# Policy for Atlantis to manage Terraform state and resources
resource "aws_iam_role_policy" "atlantis-terraform-operations" {
  name = "atlantis-terraform-operations"
  role = aws_iam_role.ecs-task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        # Wildcard pattern is intentional: Atlantis manages multiple projects' state files
        # across different S3 buckets following the naming pattern: terraform-state-*
        # This allows Atlantis to automate Terraform operations for all managed projects
        # Also includes legacy bucket for backward compatibility
        Resource = [
          "arn:aws:s3:::${var.terraform_state_bucket_prefix}-*",
          "arn:aws:s3:::${var.terraform_state_bucket_prefix}-*/*",
          "arn:aws:s3:::${var.legacy_terraform_state_bucket}",
          "arn:aws:s3:::${var.legacy_terraform_state_bucket}/*"
        ]
      },
      {
        Sid    = "DynamoDBLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        # Allows access to standard lock table and legacy lock table for backward compatibility
        Resource = [
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.terraform_state_lock_table}",
          "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.legacy_terraform_lock_table}"
        ]
      },
      {
        Sid    = "TerraformPlanOperations"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:DescribeVpcEndpoints",
          "ecs:Describe*",
          "ecr:Describe*",
          "ecr:DescribeRepositories",
          "ecr:GetLifecyclePolicy",
          "ecr:GetRepositoryPolicy",
          "ecr:ListTagsForResource",
          "elasticloadbalancing:Describe*",
          "elasticfilesystem:Describe*",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeFileSystemPolicy",
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeMountTargets",
          "kms:Describe*",
          "kms:List*",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "logs:Describe*",
          "logs:ListTagsForResource",
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters",
          "rds:DescribeDBInstances",
          "rds:ListTagsForResource",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:ListSecretVersionIds",
          "s3:List*",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters",
          "ssm:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadOnlyForTerraformResources"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListPolicyVersions"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/atlantis-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-shared-*-monitoring-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/atlantis-*"
        ]
      },
      {
        Sid    = "IAMOIDCProviderReadOnly"
        Effect = "Allow"
        Action = [
          "iam:ListOpenIDConnectProviders",
          "iam:GetOpenIDConnectProvider"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Logs policy for task role
resource "aws_iam_role_policy" "atlantis-cloudwatch-logs" {
  name = "atlantis-cloudwatch-logs"
  role = aws_iam_role.ecs-task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/atlantis-${var.environment}:*"
      }
    ]
  })
}

# EFS access policy for task role
resource "aws_iam_role_policy" "atlantis-efs-access" {
  name = "atlantis-efs-access"
  role = aws_iam_role.ecs-task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = aws_efs_file_system.atlantis.arn
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = aws_efs_access_point.atlantis.arn
          }
        }
      }
    ]
  })
}

# Outputs
output "atlantis_ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = aws_iam_role.ecs-task-execution.arn
}

output "atlantis_ecs_task_role_arn" {
  description = "The ARN of the ECS task role"
  value       = aws_iam_role.ecs-task.arn
}
