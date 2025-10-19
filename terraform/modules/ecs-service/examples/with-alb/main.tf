# ALB와 함께 사용하는 ECS Service 예제
#
# 이 예제는 Application Load Balancer와 통합된 ECS Fargate 서비스를 보여줍니다.
# 실제 운영 환경에서 웹 애플리케이션이나 API 서비스를 배포하는 일반적인 시나리오입니다.

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

# 기존 리소스 조회
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

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "public"
  }
}

# 공통 태그 모듈
module "common_tags" {
  source = "../../../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

# ECS 클러스터
resource "aws_ecs_cluster" "main" {
  name = "${var.service_name}-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-${var.environment}"
    }
  )
}

# ALB용 보안 그룹
resource "aws_security_group" "alb" {
  name        = "${var.service_name}-alb-${var.environment}"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-alb-${var.environment}"
    }
  )
}

# ECS Tasks용 보안 그룹
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.service_name}-ecs-tasks-${var.environment}"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-ecs-tasks-${var.environment}"
    }
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.service_name}-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  enable_deletion_protection = false
  enable_http2               = true

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-${var.environment}"
    }
  )
}

# Target Group
resource "aws_lb_target_group" "app" {
  name        = "${var.service_name}-${var.environment}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-${var.environment}"
    }
  )
}

# HTTP Listener (HTTPS로 리다이렉트)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-http-${var.environment}"
    }
  )
}

# HTTPS Listener (ACM 인증서가 있는 경우)
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-3-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-https-${var.environment}"
    }
  )
}

# IAM Role - ECS Task Execution
resource "aws_iam_role" "ecs_execution_role" {
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
    module.common_tags.tags,
    {
      Name = "${var.service_name}-ecs-execution-${var.environment}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role - ECS Task
resource "aws_iam_role" "ecs_task_role" {
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
    module.common_tags.tags,
    {
      Name = "${var.service_name}-ecs-task-${var.environment}"
    }
  )
}

# ECS Service 모듈 - ALB 통합 설정
module "ecs_service" {
  source = "../../"

  # 기본 설정
  name               = var.service_name
  cluster_id         = aws_ecs_cluster.main.id
  container_name     = var.service_name
  container_image    = var.container_image
  container_port     = var.container_port
  cpu                = var.task_cpu
  memory             = var.task_memory
  desired_count      = var.desired_count
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.ecs_tasks.id]
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  # 환경 변수
  container_environment = var.environment_variables

  # 헬스체크 설정
  health_check_command = [
    "CMD-SHELL",
    "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"
  ]
  health_check_interval     = 30
  health_check_timeout      = 5
  health_check_retries      = 3
  health_check_start_period = 60

  # ALB 통합
  load_balancer_config = {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }
  health_check_grace_period_seconds = 60

  # Auto Scaling 설정
  enable_autoscaling       = var.enable_autoscaling
  autoscaling_min_capacity = var.autoscaling_min_capacity
  autoscaling_max_capacity = var.autoscaling_max_capacity
  autoscaling_target_cpu   = var.autoscaling_target_cpu

  # 배포 설정
  deployment_circuit_breaker_enable   = true
  deployment_circuit_breaker_rollback = true

  # ECS Exec 활성화 (디버깅용)
  enable_execute_command = var.enable_ecs_exec

  # 태그
  common_tags = module.common_tags.tags
}
