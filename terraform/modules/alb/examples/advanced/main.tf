provider "aws" {
  region = var.aws_region
}

# VPC and Networking
data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  tags = {
    Type = "public"
  }
}

# Required Tags for Governance
locals {
  required_tags = {
    Environment = var.environment
    Service     = var.name
    Team        = "platform-team"
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "engineering"
    ManagedBy   = "Terraform"
    Project     = "alb-module-advanced-example"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for ALB with HTTPS support"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # WARNING: In production, restrict CIDR blocks to known IP ranges or CloudFront IPs
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    # WARNING: In production, restrict CIDR blocks to known IP ranges or CloudFront IPs
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Allow all outbound traffic within the VPC"
  }

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-alb-sg"
    }
  )
}

# ACM Certificate (example - use existing certificate in production)
data "aws_acm_certificate" "selected" {
  domain   = var.certificate_domain
  statuses = ["ISSUED"]
}

# ALB Module with Advanced Configuration
module "alb" {
  source = "../../"

  name       = var.name
  vpc_id     = data.aws_vpc.selected.id
  subnet_ids = data.aws_subnets.public.ids

  security_group_ids         = [aws_security_group.alb.id]
  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = true
  idle_timeout               = 120

  # HTTP Listener - Redirect to HTTPS
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

  # HTTPS Listener - Default action to primary target group
  https_listeners = {
    default = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = data.aws_acm_certificate.selected.arn
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

      default_action = {
        type             = "forward"
        target_group_key = "primary"
      }
    }
  }

  # Multiple Target Groups
  target_groups = {
    # Primary application target group
    primary = {
      port     = 8080
      protocol = "HTTP"

      health_check = {
        enabled             = true
        path                = "/health"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
        matcher             = "200"
      }

      stickiness = {
        enabled         = true
        type            = "lb_cookie"
        cookie_duration = 86400 # 24 hours
      }
    }

    # API backend target group
    api = {
      port     = 9090
      protocol = "HTTP"

      health_check = {
        enabled             = true
        path                = "/api/health"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        interval            = 15
        matcher             = "200,201"
      }
    }

    # Admin panel target group
    admin = {
      port     = 8081
      protocol = "HTTP"

      health_check = {
        enabled             = true
        path                = "/admin/health"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        interval            = 30
        matcher             = "200"
      }
    }
  }

  # Listener Rules for path-based routing
  listener_rules = {
    # Route API traffic to API target group
    api_routing = {
      listener_key = "default"
      priority     = 100

      conditions = [
        {
          path_pattern = ["/api/*"]
        }
      ]

      actions = [
        {
          type             = "forward"
          target_group_key = "api"
        }
      ]
    }

    # Route admin traffic to admin target group
    admin_routing = {
      listener_key = "default"
      priority     = 200

      conditions = [
        {
          path_pattern = ["/admin/*"]
        }
      ]

      actions = [
        {
          type             = "forward"
          target_group_key = "admin"
        }
      ]
    }

    # Route specific host header to primary target group
    host_based_routing = {
      listener_key = "default"
      priority     = 300

      conditions = [
        {
          host_header = ["app.example.com", "www.example.com"]
        }
      ]

      actions = [
        {
          type             = "forward"
          target_group_key = "primary"
        }
      ]
    }
  }

  # Access Logs Configuration
  access_logs = var.enable_access_logs ? {
    bucket  = var.access_logs_bucket
    enabled = true
    prefix  = "${var.name}/alb"
  } : null

  common_tags = local.required_tags
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = module.alb.alb_arn
}

output "alb_zone_id" {
  description = "Zone ID of the ALB for Route53"
  value       = module.alb.alb_zone_id
}

output "target_group_arns" {
  description = "Map of target group ARNs"
  value       = module.alb.target_group_arns
}

output "https_listener_arns" {
  description = "Map of HTTPS listener ARNs"
  value       = module.alb.https_listener_arns
}

output "listener_rule_arns" {
  description = "Map of listener rule ARNs"
  value       = module.alb.listener_rule_arns
}
