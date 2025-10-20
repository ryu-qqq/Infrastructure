# ============================================================================
# ALB (Application Load Balancer) Configuration
# ============================================================================

# Security group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for fileflow ALB"
  vpc_id      = var.vpc_id

  # HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  # HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-alb"
      Component = "alb"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
module "alb" {
  source = "../modules/alb"

  # ALB configuration
  name               = "${local.name_prefix}-alb"
  internal           = var.alb_internal
  vpc_id             = var.vpc_id
  subnet_ids         = data.aws_subnets.public.ids
  security_group_ids = [aws_security_group.alb.id]

  # Performance settings
  enable_http2       = true
  enable_deletion_protection = var.environment == "prod" ? true : false
  idle_timeout       = 60

  # HTTP Listener (redirect to HTTPS)
  http_listeners = {
    default = {
      port     = 80
      protocol = "HTTP"
      default_action = {
        type = "redirect"
        redirect = {
          port        = "443"
          protocol    = "HTTPS"
          status_code = "HTTP_301"
        }
      }
    }
  }

  # HTTPS Listener
  https_listeners = {
    default = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = data.terraform_remote_state.monitoring.outputs.acm_certificate_arn  # TODO: Update with actual certificate
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      default_action = {
        type             = "forward"
        target_group_key = "fileflow"
      }
    }
  }

  # Target Group for ECS service
  target_groups = {
    fileflow = {
      name_prefix          = "ff-"
      port                 = var.ecs_container_port
      protocol             = "HTTP"
      target_type          = "ip"
      deregistration_delay = 30

      health_check = {
        enabled             = true
        path                = var.alb_health_check_path
        port                = "traffic-port"
        protocol            = "HTTP"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = var.alb_health_check_interval
        matcher             = "200"
      }

      stickiness = {
        enabled         = true
        type            = "lb_cookie"
        cookie_duration = 86400  # 1 day
      }
    }
  }

  # Access logging
  enable_access_logs = true
  access_logs_bucket = module.fileflow_logs_bucket.bucket_id
  access_logs_prefix = "alb-access-logs"

  # Tags
  common_tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-alb"
      Component = "alb"
    }
  )
}

# ALB DNS Record (CloudFront distribution will point to this)
# TODO: Add Route53 record after domain configuration
# resource "aws_route53_record" "fileflow_alb" {
#   zone_id = data.terraform_remote_state.dns.outputs.public_zone_id
#   name    = "fileflow.${var.environment}.example.com"
#   type    = "A"
#
#   alias {
#     name                   = module.alb.dns_name
#     zone_id                = module.alb.zone_id
#     evaluate_target_health = true
#   }
# }
