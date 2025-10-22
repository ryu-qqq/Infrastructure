# Atlantis Basic Example
#
# 이 예제는 최소한의 설정으로 Atlantis를 배포하는 방법을 보여줍니다.
# 실제 프로덕션 환경에서는 추가 보안 설정 및 고가용성 구성이 필요합니다.

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 기존 VPC 참조
data "aws_vpc" "selected" {
  tags = {
    Environment = var.environment
  }
}

# 기존 Public 서브넷 참조
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    Type = "Public"
  }
}

# 기존 Private 서브넷 참조
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    Type = "Private"
  }
}

# Locals for required tags
locals {
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    Service     = var.service
  }
}

# Atlantis ALB
resource "aws_lb" "atlantis" {
  name               = "atlantis-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  tags = merge(
    local.required_tags,
    {
      Name      = "alb-atlantis-${var.environment}"
      Component = "loadbalancer"
    }
  )
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "atlantis-alb-${var.environment}"
  description = "Security group for Atlantis ALB"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "sg-atlantis-alb-${var.environment}"
      Component = "security"
    }
  )
}

# ECS Task Security Group
resource "aws_security_group" "ecs-task" {
  name        = "atlantis-ecs-task-${var.environment}"
  description = "Security group for Atlantis ECS tasks"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 4141
    to_port         = 4141
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "sg-atlantis-ecs-${var.environment}"
      Component = "security"
    }
  )
}

# ECS Cluster
resource "aws_ecs_cluster" "atlantis" {
  name = "atlantis-${var.environment}"

  tags = merge(
    local.required_tags,
    {
      Name      = "ecs-atlantis-${var.environment}"
      Component = "compute"
    }
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/atlantis-${var.environment}"
  retention_in_days = 7

  tags = merge(
    local.required_tags,
    {
      Name      = "logs-atlantis-${var.environment}"
      Component = "logging"
    }
  )
}

# ECS Task Definition
resource "aws_ecs_task_definition" "atlantis" {
  family                   = "atlantis-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"

  container_definitions = jsonencode([
    {
      name  = "atlantis"
      image = "ghcr.io/runatlantis/atlantis:${var.atlantis_version}"

      portMappings = [
        {
          containerPort = 4141
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ATLANTIS_REPO_ALLOWLIST"
          value = var.github_repo_allowlist
        },
        {
          name  = "ATLANTIS_PORT"
          value = "4141"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "atlantis"
        }
      }
    }
  ])

  tags = merge(
    local.required_tags,
    {
      Name      = "task-atlantis-${var.environment}"
      Component = "compute"
    }
  )
}

# ECS Service
resource "aws_ecs_service" "atlantis" {
  name            = "atlantis-${var.environment}"
  cluster         = aws_ecs_cluster.atlantis.id
  task_definition = aws_ecs_task_definition.atlantis.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.ecs-task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.atlantis.arn
    container_name   = "atlantis"
    container_port   = 4141
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "service-atlantis-${var.environment}"
      Component = "compute"
    }
  )
}

# ALB Target Group
resource "aws_lb_target_group" "atlantis" {
  name        = "atlantis-${var.environment}"
  port        = 4141
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/healthz"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "tg-atlantis-${var.environment}"
      Component = "loadbalancer"
    }
  )
}

# ALB Listener (HTTPS)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "listener-atlantis-${var.environment}"
      Component = "loadbalancer"
    }
  )
}
