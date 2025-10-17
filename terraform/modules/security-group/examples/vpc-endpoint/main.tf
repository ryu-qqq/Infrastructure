# VPC Endpoint Security Group Example

# ECS Security Group 생성 (VPC Endpoint가 참조하기 위해)
module "ecs_security_group" {
  source = "../../"

  name        = "example-ecs-sg"
  description = "Security group for ECS (for VPC Endpoint example)"
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
    Purpose     = "vpc-endpoint-example"
    ManagedBy   = "terraform"
  }
}

# VPC Endpoint Security Group 생성
module "vpc_endpoint_security_group" {
  source = "../../"

  name        = "example-vpc-endpoint-sg"
  description = "Security group for VPC endpoints (S3, ECR, etc.)"
  vpc_id      = var.vpc_id
  type        = "vpc-endpoint"

  # VPC Endpoint 구성
  vpc_endpoint_port = 443

  # 보안 그룹으로부터의 트래픽 허용
  vpc_endpoint_ingress_sg_ids = [
    module.ecs_security_group.security_group_id
  ]

  # CIDR 블록으로부터의 트래픽 허용 (선택사항)
  vpc_endpoint_ingress_cidr_blocks = [
    "10.0.0.0/16"
  ]

  common_tags = {
    Environment = "example"
    Purpose     = "vpc-endpoint-example"
    ManagedBy   = "terraform"
  }
}

# Outputs
output "vpc_endpoint_security_group_id" {
  description = "ID of the VPC endpoint security group"
  value       = module.vpc_endpoint_security_group.security_group_id
}

output "vpc_endpoint_security_group_arn" {
  description = "ARN of the VPC endpoint security group"
  value       = module.vpc_endpoint_security_group.security_group_arn
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.ecs_security_group.security_group_id
}
