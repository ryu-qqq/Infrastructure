# 다중 Target Group을 사용하는 ALB 예제
#
# 이 예제는 하나의 ALB에서 경로 기반 라우팅으로 여러 Target Group을 사용하는 방법을 보여줍니다.
# 마이크로서비스 아키텍처에서 API Gateway 역할을 하는 ALB 구성에 적합합니다.

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

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.service_name}-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-${var.environment}"
    }
  )
}

# Target Group 1 - API 서비스
resource "aws_lb_target_group" "api" {
  name        = "${var.service_name}-api-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/api/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    module.common_tags.tags,
    {
      Name      = "${var.service_name}-api-${var.environment}"
      Component = "api"
    }
  )
}

# Target Group 2 - Web 서비스
resource "aws_lb_target_group" "web" {
  name        = "${var.service_name}-web-${var.environment}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    module.common_tags.tags,
    {
      Name      = "${var.service_name}-web-${var.environment}"
      Component = "web"
    }
  )
}

# Target Group 3 - Admin 서비스
resource "aws_lb_target_group" "admin" {
  name        = "${var.service_name}-admin-${var.environment}"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/admin/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    module.common_tags.tags,
    {
      Name      = "${var.service_name}-admin-${var.environment}"
      Component = "admin"
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

# HTTPS Listener (기본 액션: Web Target Group으로 전달)
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-https-${var.environment}"
    }
  )
}

# Listener Rule 1 - API 경로 라우팅
resource "aws_lb_listener_rule" "api" {
  count = var.certificate_arn != null ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-api-rule-${var.environment}"
    }
  )
}

# Listener Rule 2 - Admin 경로 라우팅
resource "aws_lb_listener_rule" "admin" {
  count = var.certificate_arn != null ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin.arn
  }

  condition {
    path_pattern {
      values = ["/admin/*"]
    }
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-admin-rule-${var.environment}"
    }
  )
}

# Listener Rule 3 - 고정 응답 (헬스체크용)
resource "aws_lb_listener_rule" "health" {
  count = var.certificate_arn != null ? 1 : 0

  listener_arn = aws_lb_listener.https[0].arn
  priority     = 300

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "OK"
      status_code  = "200"
    }
  }

  condition {
    path_pattern {
      values = ["/health", "/healthz"]
    }
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.service_name}-health-rule-${var.environment}"
    }
  )
}
