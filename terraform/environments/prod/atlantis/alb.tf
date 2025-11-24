# Application Load Balancer for Atlantis using module

# Security Groups using module
module "atlantis_alb_sg" {
  source = "../../../modules/security-group"

  name        = "atlantis-alb-${var.environment}"
  description = "Security group for Atlantis Application Load Balancer"
  vpc_id      = var.vpc_id
  type        = "alb"

  # ALB Configuration
  alb_ingress_cidr_blocks = var.allowed_cidr_blocks
  alb_enable_http         = true
  alb_enable_https        = true

  # Enable default egress
  enable_default_egress = true

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "atlantis"
    Description = "Security group for Atlantis Application Load Balancer"
  }
}

module "atlantis_ecs_tasks_sg" {
  source = "../../../modules/security-group"

  name        = "atlantis-ecs-tasks-${var.environment}"
  description = "Security group for Atlantis ECS tasks"
  vpc_id      = var.vpc_id
  type        = "custom"

  # Custom ingress rule from ALB
  custom_ingress_rules = [
    {
      description              = "Allow traffic from ALB to ECS container"
      from_port                = var.atlantis_container_port
      to_port                  = var.atlantis_container_port
      protocol                 = "tcp"
      source_security_group_id = module.atlantis_alb_sg.security_group_id
    }
  ]

  # Enable default egress
  enable_default_egress = true

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "atlantis"
    Description = "Security group for Atlantis ECS tasks"
  }
}

# Application Load Balancer using module
module "atlantis_alb" {
  source = "../../../modules/alb"

  name               = "atlantis-${var.environment}"
  internal           = false
  subnet_ids         = var.public_subnet_ids
  security_group_ids = [module.atlantis_alb_sg.security_group_id]
  vpc_id             = var.vpc_id

  enable_deletion_protection = var.alb_enable_deletion_protection
  enable_http2               = true

  # Target Groups
  target_groups = {
    atlantis = {
      port                 = var.atlantis_container_port
      protocol             = "HTTP"
      target_type          = "ip"
      deregistration_delay = 30
      health_check = {
        enabled             = true
        healthy_threshold   = var.alb_health_check_healthy_threshold
        unhealthy_threshold = var.alb_health_check_unhealthy_threshold
        timeout             = var.alb_health_check_timeout
        interval            = var.alb_health_check_interval
        path                = var.alb_health_check_path
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  }

  # HTTP Listeners - Redirect to HTTPS
  http_listeners = {
    http = {
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

  # HTTPS Listeners
  https_listeners = {
    https = {
      port            = 443
      protocol        = "HTTPS"
      ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      certificate_arn = var.acm_certificate_arn
      default_action = {
        type             = "forward"
        target_group_key = "atlantis"
      }
    }
  }

  # Tags
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center

  additional_tags = {
    Component   = "atlantis"
    Description = "Application Load Balancer for Atlantis Terraform automation server"
  }
}

# Outputs
output "atlantis_alb_arn" {
  description = "The ARN of the Atlantis Application Load Balancer"
  value       = module.atlantis_alb.alb_arn
}

output "atlantis_alb_dns_name" {
  description = "The DNS name of the Atlantis Application Load Balancer"
  value       = module.atlantis_alb.alb_dns_name
}

output "atlantis_alb_zone_id" {
  description = "The zone ID of the Atlantis Application Load Balancer"
  value       = module.atlantis_alb.alb_zone_id
}

output "atlantis_target_group_arns" {
  description = "Map of Atlantis target group ARNs"
  value       = module.atlantis_alb.target_group_arns
}

output "atlantis_target_group_arn" {
  description = "The ARN of the Atlantis target group"
  value       = module.atlantis_alb.target_group_arns["atlantis"]
}

output "atlantis_alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = module.atlantis_alb_sg.security_group_id
}

output "atlantis_ecs_tasks_security_group_id" {
  description = "The ID of the ECS tasks security group"
  value       = module.atlantis_ecs_tasks_sg.security_group_id
}
