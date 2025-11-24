# ============================================================================
# VPC Outputs
# ============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "VPC ARN"
  value       = aws_vpc.main.arn
}

# ============================================================================
# Subnet Outputs
# ============================================================================

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

# ============================================================================
# Gateway Outputs
# ============================================================================

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

# ============================================================================
# Route Table Outputs
# ============================================================================

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

# ============================================================================
# SSM Parameter Store Exports for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "vpc_id" {
  name        = "/shared/${var.project_name}/network/vpc-id"
  description = "VPC ID for cross-stack references"
  type        = "String"
  value       = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name      = "vpc-id-export"
      Component = "network"
    }
  )
}

resource "aws_ssm_parameter" "vpc_cidr" {
  name        = "/shared/${var.project_name}/network/vpc-cidr"
  description = "VPC CIDR block for cross-stack references"
  type        = "String"
  value       = aws_vpc.main.cidr_block

  tags = merge(
    local.required_tags,
    {
      Name      = "vpc-cidr-export"
      Component = "network"
    }
  )
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name        = "/shared/${var.project_name}/network/public-subnet-ids"
  description = "Public subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.public[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "public-subnet-ids-export"
      Component = "network"
    }
  )
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name        = "/shared/${var.project_name}/network/private-subnet-ids"
  description = "Private subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.private[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "private-subnet-ids-export"
      Component = "network"
    }
  )
}
