# Custom Security Group Example

module "custom_security_group" {
  source = "../../"

  name        = "example-custom-sg"
  description = "Custom security group with specific rules"
  vpc_id      = var.vpc_id
  type        = "custom"

  # 커스텀 인그레스 규칙
  custom_ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_block  = "10.0.0.0/16"
      description = "Allow SSH from VPC"
    },
    {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_block  = "10.0.0.0/16"
      description = "Allow application port from VPC"
    },
    {
      from_port                = 5432
      to_port                  = 5432
      protocol                 = "tcp"
      source_security_group_id = var.database_sg_id
      description              = "Allow PostgreSQL from database security group"
    }
  ]

  # 커스텀 이그레스 규칙
  custom_egress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
      description = "Allow HTTPS outbound"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_block  = "0.0.0.0/0"
      description = "Allow HTTP outbound"
    },
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_block  = "10.0.0.0/16"
      description = "Allow PostgreSQL to VPC"
    }
  ]

  # 기본 이그레스 규칙 비활성화 (커스텀 규칙만 사용)
  enable_default_egress = false

  common_tags = {
    Environment = "example"
    Purpose     = "custom-example"
    ManagedBy   = "terraform"
  }
}

# Outputs
output "custom_security_group_id" {
  description = "ID of the custom security group"
  value       = module.custom_security_group.security_group_id
}

output "custom_security_group_arn" {
  description = "ARN of the custom security group"
  value       = module.custom_security_group.security_group_arn
}
