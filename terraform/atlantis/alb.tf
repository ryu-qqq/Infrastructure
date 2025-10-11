# Application Load Balancer for Atlantis

# Security Group for ALB
resource "aws_security_group" "atlantis-alb" {
  name_prefix = "atlantis-alb-${var.environment}-"
  description = "Security group for Atlantis Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP ingress from allowed CIDR blocks
  ingress {
    description = "HTTP from allowed sources"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # HTTPS ingress from allowed CIDR blocks
  ingress {
    description = "HTTPS from allowed sources"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow all outbound traffic
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
      Name        = "atlantis-alb-${var.environment}"
      Component   = "atlantis"
      Description = "Security group for Atlantis Application Load Balancer"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "atlantis-ecs-tasks" {
  name_prefix = "atlantis-ecs-tasks-${var.environment}-"
  description = "Security group for Atlantis ECS tasks"
  vpc_id      = var.vpc_id

  # Allow inbound from ALB on container port
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.atlantis_container_port
    to_port         = var.atlantis_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.atlantis-alb.id]
  }

  # Allow all outbound traffic
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
      Name        = "atlantis-ecs-tasks-${var.environment}"
      Component   = "atlantis"
      Description = "Security group for Atlantis ECS tasks"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "atlantis" {
  name               = "atlantis-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.atlantis-alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.alb_enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-${var.environment}"
      Component   = "atlantis"
      Description = "Application Load Balancer for Atlantis Terraform automation server"
    }
  )
}

# Target Group for Atlantis
resource "aws_lb_target_group" "atlantis" {
  name_prefix          = "atl-"
  port                 = var.atlantis_container_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = var.alb_health_check_healthy_threshold
    unhealthy_threshold = var.alb_health_check_unhealthy_threshold
    timeout             = var.alb_health_check_timeout
    interval            = var.alb_health_check_interval
    path                = var.alb_health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-${var.environment}"
      Component   = "atlantis"
      Description = "Target group for Atlantis ECS service"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# HTTP Listener - Redirect to HTTPS
resource "aws_lb_listener" "atlantis-http" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "80"
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
    local.required_tags,
    {
      Name        = "atlantis-http-${var.environment}"
      Component   = "atlantis"
      Description = "HTTP listener for Atlantis ALB redirects to HTTPS"
    }
  )
}

# HTTPS Listener
resource "aws_lb_listener" "atlantis-https" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }

  tags = merge(
    local.required_tags,
    {
      Name        = "atlantis-https-${var.environment}"
      Component   = "atlantis"
      Description = "HTTPS listener for Atlantis ALB"
    }
  )
}

# Outputs
output "atlantis_alb_arn" {
  description = "The ARN of the Atlantis Application Load Balancer"
  value       = aws_lb.atlantis.arn
}

output "atlantis_alb_dns_name" {
  description = "The DNS name of the Atlantis Application Load Balancer"
  value       = aws_lb.atlantis.dns_name
}

output "atlantis_alb_zone_id" {
  description = "The zone ID of the Atlantis Application Load Balancer"
  value       = aws_lb.atlantis.zone_id
}

output "atlantis_target_group_arn" {
  description = "The ARN of the Atlantis target group"
  value       = aws_lb_target_group.atlantis.arn
}

output "atlantis_alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.atlantis-alb.id
}

output "atlantis_ecs_tasks_security_group_id" {
  description = "The ID of the ECS tasks security group"
  value       = aws_security_group.atlantis-ecs-tasks.id
}
