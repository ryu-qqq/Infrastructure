# IAM Roles and Policies for n8n ECS Tasks using modules

# =============================================================================
# ECS Task Execution Role
# =============================================================================

module "n8n_task_execution_role" {
  source = "../../../modules/iam-role-policy"

  role_name   = "${local.name_prefix}-ecs-task-execution"
  description = "ECS task execution role for n8n"

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

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "n8n"
    Description = "ECS task execution role for n8n"
  }
}

# Attach AWS managed policy for ECS Task Execution
resource "aws_iam_role_policy_attachment" "n8n-task-execution-policy" {
  role       = module.n8n_task_execution_role.role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline Policy for Secrets Manager Access
resource "aws_iam_role_policy" "n8n-task-execution-secrets" {
  name = "secrets-access"
  role = module.n8n_task_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.n8n-db-password.arn,
          aws_secretsmanager_secret.n8n-encryption-key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/authhub/security/service-token-secret"
        ]
      }
    ]
  })
}

# Inline Policy for CloudWatch Logs
resource "aws_iam_role_policy" "n8n-task-execution-logs" {
  name = "cloudwatch-logs"
  role = module.n8n_task_execution_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${module.n8n_logs.log_group_arn}:*"
      }
    ]
  })
}

# =============================================================================
# ECS Task Role
# =============================================================================

module "n8n_task_role" {
  source = "../../../modules/iam-role-policy"

  role_name   = "${local.name_prefix}-ecs-task"
  description = "ECS task role for n8n application"

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

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "n8n"
    Description = "ECS task role for n8n application"
  }
}

# n8n Task Role Policy - Basic permissions for n8n operations
resource "aws_iam_role_policy" "n8n-task-operations" {
  name = "n8n-operations"
  role = module.n8n_task_role.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs for application logging
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${module.n8n_logs.log_group_arn}:*"
      },
      # S3 Access for workflow file storage (optional - if needed)
      # Uncomment if you want n8n to store files in S3
      # {
      #   Sid    = "S3Access"
      #   Effect = "Allow"
      #   Action = [
      #     "s3:GetObject",
      #     "s3:PutObject",
      #     "s3:DeleteObject"
      #   ]
      #   Resource = "arn:aws:s3:::n8n-files-${var.environment}/*"
      # }
    ]
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = module.n8n_task_execution_role.role_arn
}

output "task_role_arn" {
  description = "The ARN of the ECS task role"
  value       = module.n8n_task_role.role_arn
}
