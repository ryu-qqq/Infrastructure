# Application Load Balancer Resources

# ============================================================================
# Security Group for ALB
# ============================================================================

resource "aws_security_group" "alb" {
  name        = "fileflow-alb"
  description = "Security group for FileFlow Application Load Balancer"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allow HTTP traffic from internet"
    from_port   = 80
    to_port     = 80
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
    local.required_tags,
    {
      Name      = "fileflow-alb-sg"
      Component = "security-group"
    }
  )
}

# ============================================================================
# Application Load Balancer
# ============================================================================

resource "aws_lb" "fileflow" {
  name               = "fileflow-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection = false
  enable_http2               = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-alb"
      Component = "application-load-balancer"
    }
  )
}

# ============================================================================
# Target Group
# ============================================================================

resource "aws_lb_target_group" "fileflow" {
  name        = "fileflow-tg"
  port        = local.container_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-target-group"
      Component = "target-group"
    }
  )
}

# ============================================================================
# ALB Listener
# ============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.fileflow.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.fileflow.arn
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-http-listener"
      Component = "alb-listener"
    }
  )
}
