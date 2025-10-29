# Basic Example - Minimal ECS Service Configuration
#
# This example demonstrates the minimum required configuration
# to deploy an ECS Fargate service.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "private"
  }
}

# Required Tags for Governance
locals {
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = "platform-team"
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
    Project     = "ecs-service-example"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.service_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    local.required_tags,
    {
      Name = "${var.service_name}-${var.environment}"
    }
  )
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs-tasks" {
  name        = "${var.service_name}-ecs-tasks-${var.environment}"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  # NOTE: For production environments, restrict egress to specific services
  # using VPC endpoints (ECR, S3, CloudWatch Logs, Secrets Manager)
  # instead of allowing all outbound traffic.
  # See: https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.required_tags,
    {
      Name = "${var.service_name}-ecs-tasks-${var.environment}"
    }
  )
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs-execution-role" {
  name = "${var.service_name}-ecs-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "${var.service_name}-ecs-execution-${var.environment}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs-execution-role-policy" {
  role       = aws_iam_role.ecs-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs-task-role" {
  name = "${var.service_name}-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(
    local.required_tags,
    {
      Name = "${var.service_name}-ecs-task-${var.environment}"
    }
  )
}

# ECS Service Module - Basic Configuration
module "ecs_service" {
  source = "../../"

  # Required variables
  name               = var.service_name
  cluster_id         = aws_ecs_cluster.main.id
  container_name     = var.service_name
  container_image    = var.container_image
  container_port     = var.container_port
  cpu                = 256
  memory             = 512
  desired_count      = 1
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.ecs-tasks.id]
  execution_role_arn = aws_iam_role.ecs-execution-role.arn
  task_role_arn      = aws_iam_role.ecs-task-role.arn

  # Tags
  common_tags = local.required_tags
}

# Outputs
output "service_name" {
  description = "The name of the ECS service"
  value       = module.ecs_service.service_name
}

output "task_definition_arn" {
  description = "The ARN of the task definition"
  value       = module.ecs_service.task_definition_arn
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = module.ecs_service.cloudwatch_log_group_name
}
