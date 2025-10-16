provider "aws" {
  region = "ap-northeast-2"
}

# VPC and Networking (for example purposes)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Required Tags for Governance
locals {
  required_tags = {
    Environment = "dev"
    Service     = "alb-example"
    Team        = "platform-team"
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    ManagedBy   = "Terraform"
    Project     = "alb-module-example"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "example-alb-sg"
  description = "Security group for ALB example"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # WARNING: In production, restrict CIDR blocks to known IP ranges or CloudFront IPs
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "Allow all outbound traffic within the VPC"
  }

  tags = merge(
    local.required_tags,
    {
      Name = "alb-example-sg"
    }
  )
}

# ALB Module
module "alb" {
  source = "../../"

  name       = "example-alb"
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  security_group_ids = [aws_security_group.alb.id]

  # HTTP Listener with redirect to HTTPS (example)
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

  # Target Group for backend services
  target_groups = {
    app = {
      port     = 8080
      protocol = "HTTP"

      health_check = {
        enabled             = true
        path                = "/health"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        interval            = 30
        matcher             = "200"
      }
    }
  }

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

output "target_group_arns" {
  description = "Target group ARNs"
  value       = module.alb.target_group_arns
}
