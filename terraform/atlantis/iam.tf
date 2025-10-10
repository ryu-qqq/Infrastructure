# IAM Roles and Policies for Atlantis ECS Tasks

# ECS Task Execution Role
# This role is used by ECS to pull container images and publish logs
resource "aws_iam_role" "ecs_task_execution" {
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
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for ECR access with KMS decryption
resource "aws_iam_role_policy" "ecs_task_execution_ecr_kms" {
  name = "atlantis-ecs-task-execution-ecr-kms"
  role = aws_iam_role.ecs_task_execution.id

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
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# ECS Task Role
# This role is used by the Atlantis container for AWS API operations
resource "aws_iam_role" "ecs_task" {
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
resource "aws_iam_role_policy" "atlantis_terraform_operations" {
  name = "atlantis-terraform-operations"
  role = aws_iam_role.ecs_task.id

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
        Resource = [
          "arn:aws:s3:::terraform-state-*",
          "arn:aws:s3:::terraform-state-*/*"
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
        Resource = "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/terraform-state-lock"
      },
      {
        Sid    = "TerraformPlanOperations"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ecs:Describe*",
          "ecr:Describe*",
          "iam:Get*",
          "iam:List*",
          "kms:Describe*",
          "kms:List*",
          "logs:Describe*",
          "s3:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Logs policy for task role
resource "aws_iam_role_policy" "atlantis_cloudwatch_logs" {
  name = "atlantis-cloudwatch-logs"
  role = aws_iam_role.ecs_task.id

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
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/atlantis-*:*"
      }
    ]
  })
}

# Outputs
output "atlantis_ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "atlantis_ecs_task_role_arn" {
  description = "The ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}
