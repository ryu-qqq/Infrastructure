# ALB Security Group Example

module "alb_security_group" {
  source = "../../"

  name        = "example-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id
  type        = "alb"

  # ALB 구성 - HTTP와 HTTPS 모두 활성화
  alb_enable_http         = true
  alb_enable_https        = true
  alb_http_port           = 80
  alb_https_port          = 443
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]

  common_tags = {
    Environment = "example"
    Purpose     = "alb-example"
    ManagedBy   = "terraform"
  }
}

# Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb_security_group.security_group_id
}

output "alb_security_group_arn" {
  description = "ARN of the ALB security group"
  value       = module.alb_security_group.security_group_arn
}
