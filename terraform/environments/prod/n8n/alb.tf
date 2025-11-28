# Application Load Balancer for n8n using modules

# =============================================================================
# Security Groups
# =============================================================================

# ALB Security Group
module "n8n_alb_sg" {
  source = "../../../modules/security-group"

  name        = "${local.name_prefix}-alb"
  description = "Security group for n8n Application Load Balancer"
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
    Component   = "n8n"
    Description = "Security group for n8n Application Load Balancer"
  }
}

# ECS Tasks Security Group
module "n8n_ecs_tasks_sg" {
  source = "../../../modules/security-group"

  name        = "${local.name_prefix}-ecs-tasks"
  description = "Security group for n8n ECS tasks"
  vpc_id      = var.vpc_id
  type        = "custom"

  # Custom ingress rule from ALB
  custom_ingress_rules = [
    {
      description              = "Allow traffic from ALB to ECS container"
      from_port                = local.n8n_container_port
      to_port                  = local.n8n_container_port
      protocol                 = "tcp"
      source_security_group_id = module.n8n_alb_sg.security_group_id
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
    Component   = "n8n"
    Description = "Security group for n8n ECS tasks"
  }
}

# =============================================================================
# Application Load Balancer
# =============================================================================

module "n8n_alb" {
  source = "../../../modules/alb"

  name               = local.name_prefix
  internal           = false
  subnet_ids         = var.public_subnet_ids
  security_group_ids = [module.n8n_alb_sg.security_group_id]
  vpc_id             = var.vpc_id

  enable_deletion_protection = var.alb_enable_deletion_protection
  enable_http2               = true

  # Target Groups
  target_groups = {
    n8n = {
      port                 = local.n8n_container_port
      protocol             = "HTTP"
      target_type          = "ip"
      deregistration_delay = 30
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
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
        target_group_key = "n8n"
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
    Component   = "n8n"
    Description = "Application Load Balancer for n8n workflow automation"
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "alb_arn" {
  description = "The ARN of the n8n Application Load Balancer"
  value       = module.n8n_alb.alb_arn
}

output "alb_dns_name" {
  description = "The DNS name of the n8n Application Load Balancer"
  value       = module.n8n_alb.alb_dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the n8n Application Load Balancer"
  value       = module.n8n_alb.alb_zone_id
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = module.n8n_alb_sg.security_group_id
}

output "ecs_tasks_security_group_id" {
  description = "The ID of the ECS tasks security group"
  value       = module.n8n_ecs_tasks_sg.security_group_id
}
