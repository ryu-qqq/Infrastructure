provider "aws" {
  region = var.region
}

locals {
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.lifecycle
    DataClass   = var.data_class
    Service     = var.service
  }
}

resource "aws_iam_policy" "atlantis_ecs_task_policy" {
  name        = "atlantis-ecs-task-role-policy"
  description = "Policy to allow attaching and detaching policies to CrawlingHub roles"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy"
        ]
        Resource = "arn:aws:iam::646886795421:role/crawlinghub-*"
      }
    ]
  })
  
  tags = merge(local.required_tags, {
    Name = "atlantis-ecs-task-policy"
  })
}

resource "aws_iam_role_policy_attachment" "attach_atlantis_ecs_task_policy" {
  role       = "atlantis-ecs-task-prod"
  policy_arn = aws_iam_policy.atlantis_ecs_task_policy.arn
}