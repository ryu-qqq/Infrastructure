# Network Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = data.aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = data.aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = data.aws_subnet.private[*].id
}

# Bastion Outputs

output "bastion_instance_id" {
  description = "Bastion EC2 instance ID"
  value       = var.enable_bastion ? module.bastion[0].instance_id : null
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = var.enable_bastion ? module.bastion[0].security_group_id : null
}

output "bastion_private_ip" {
  description = "Bastion private IP address"
  value       = var.enable_bastion ? module.bastion[0].private_ip : null
}

# ============================================================================
# SSM Parameter Store Exports for Cross-Stack References
# ============================================================================

# Import existing SSM parameters as data sources
data "aws_ssm_parameter" "vpc-id" {
  name = "/shared/network/vpc-id"
}

data "aws_ssm_parameter" "public-subnet-ids" {
  name = "/shared/network/public-subnet-ids"
}

data "aws_ssm_parameter" "private-subnet-ids" {
  name = "/shared/network/private-subnet-ids"
}

# ============================================================================
# Bastion Host SSM Parameters (enable_bastion이 true일 때만 생성)
# ============================================================================

resource "aws_ssm_parameter" "bastion-instance-id" {
  count = var.enable_bastion ? 1 : 0

  name        = "/shared/bastion/instance-id"
  description = "Bastion host instance ID for SSM Session Manager access"
  type        = "String"
  value       = module.bastion[0].instance_id

  tags = merge(
    local.required_tags,
    {
      Name      = "bastion-instance-id-export"
      Component = "bastion"
    }
  )
}

resource "aws_ssm_parameter" "bastion-security-group-id" {
  count = var.enable_bastion ? 1 : 0

  name        = "/shared/bastion/security-group-id"
  description = "Bastion host security group ID"
  type        = "String"
  value       = module.bastion[0].security_group_id

  tags = merge(
    local.required_tags,
    {
      Name      = "bastion-security-group-id-export"
      Component = "bastion"
    }
  )
}

resource "aws_ssm_parameter" "bastion-private-ip" {
  count = var.enable_bastion ? 1 : 0

  name        = "/shared/bastion/private-ip"
  description = "Bastion host private IP address"
  type        = "String"
  value       = module.bastion[0].private_ip

  tags = merge(
    local.required_tags,
    {
      Name      = "bastion-private-ip-export"
      Component = "bastion"
    }
  )
}
