# ECS Security Group Example

# 먼저 ALB Security Group 생성 (ECS가 참조하기 위해)
module "alb_security_group" {
  source = "../../"

  name        = "example-alb-sg"
  description = "Security group for ALB (for ECS example)"
  vpc_id      = var.vpc_id
  type        = "alb"

  alb_enable_http         = true
  alb_enable_https        = true
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]

  common_tags = {
    Environment = "example"
    Purpose     = "ecs-example"
    ManagedBy   = "terraform"
  }
}

# ECS Security Group 생성
module "ecs_security_group" {
  source = "../../"

  name        = "example-ecs-sg"
  description = "Security group for ECS service"
  vpc_id      = var.vpc_id
  type        = "ecs"

  # ECS 구성 - ALB로부터의 트래픽 허용
  ecs_ingress_from_alb_sg_id = module.alb_security_group.security_group_id
  ecs_container_port         = 8080

  # 추가 보안 그룹으로부터의 트래픽 허용 (선택사항)
  ecs_additional_ingress_sg_ids = []

  common_tags = {
    Environment = "example"
    Purpose     = "ecs-example"
    ManagedBy   = "terraform"
  }
}

# Outputs
output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.ecs_security_group.security_group_id
}

output "ecs_security_group_arn" {
  description = "ARN of the ECS security group"
  value       = module.ecs_security_group.security_group_arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.alb_security_group.security_group_id
}
