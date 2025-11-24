# Application Load Balancer for Atlantis using module

# Security Groups using module
module "atlantis_alb_sg" {
  source = "../../../modules/security-group"

  name        = "atlantis-alb-${var.environment}"
  description = "Security group for Atlantis Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress_rules = [
    {
      description = "HTTP from allowed sources"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    },
    {
      description = "HTTPS from allowed sources"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  ]

  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

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

  ingress_rules = [
    {
      description     = "Allow traffic from ALB"
      from_port       = var.atlantis_container_port
      to_port         = var.atlantis_container_port
      protocol        = "tcp"
      security_groups = [module.atlantis_alb_sg.security_group_id]
    }
  ]

  egress_rules = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

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
  load_balancer_type = "application"
  security_groups    = [module.atlantis_alb_sg.security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.alb_enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  # Target Group Configuration
  target_group_name_prefix = "atl-"
  target_group_port        = var.atlantis_container_port
  target_group_protocol    = "HTTP"
  vpc_id                   = var.vpc_id
  target_type              = "ip"
  deregistration_delay     = 30

  # Health Check Configuration
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

  # HTTP Listener - Redirect to HTTPS
  http_listener = {
    port     = 80
    protocol = "HTTP"
    redirect = {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  # HTTPS Listener
  https_listener = {
    port            = 443
    protocol        = "HTTPS"
    ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    certificate_arn = var.acm_certificate_arn
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

output "atlantis_target_group_arn" {
  description = "The ARN of the Atlantis target group"
  value       = module.atlantis_alb.target_group_arn
}

output "atlantis_alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = module.atlantis_alb_sg.security_group_id
}

output "atlantis_ecs_tasks_security_group_id" {
  description = "The ID of the ECS tasks security group"
  value       = module.atlantis_ecs_tasks_sg.security_group_id
}
