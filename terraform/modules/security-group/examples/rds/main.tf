# RDS Security Group Example

# ECS Security Group 생성 (RDS가 참조하기 위해)
module "ecs_security_group" {
  source = "../../"

  name        = "example-ecs-sg"
  description = "Security group for ECS (for RDS example)"
  vpc_id      = var.vpc_id
  type        = "custom"

  # 커스텀 규칙으로 ECS 포트 열기
  custom_ingress_rules = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "Allow container port from VPC"
    }
  ]

  common_tags = {
    Environment = "example"
    Purpose     = "rds-example"
    ManagedBy   = "terraform"
  }
}

# RDS Security Group 생성
module "rds_security_group" {
  source = "../../"

  name        = "example-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id
  type        = "rds"

  # RDS 구성 - ECS로부터의 트래픽 허용
  rds_ingress_from_ecs_sg_id = module.ecs_security_group.security_group_id
  rds_port                   = 5432

  # 추가 보안 그룹으로부터의 트래픽 허용 (선택사항)
  rds_additional_ingress_sg_ids = []

  # CIDR 블록으로부터의 트래픽 허용 (주의: 가능한 한 사용하지 마세요)
  rds_ingress_cidr_blocks = []

  common_tags = {
    Environment = "example"
    Purpose     = "rds-example"
    ManagedBy   = "terraform"
  }
}

# Outputs
output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.rds_security_group.security_group_id
}

output "rds_security_group_arn" {
  description = "ARN of the RDS security group"
  value       = module.rds_security_group.security_group_arn
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.ecs_security_group.security_group_id
}
