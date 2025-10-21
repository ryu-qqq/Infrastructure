# Network Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table ID"
  value       = aws_route_table.private.id
}

# Transit Gateway Outputs

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway.main[0].id : null
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN"
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway.main[0].arn : null
}

output "transit_gateway_vpc_attachment_id" {
  description = "Transit Gateway VPC Attachment ID"
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway_vpc_attachment.main[0].id : null
}

output "transit_gateway_route_table_id" {
  description = "Transit Gateway default route table ID"
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway.main[0].association_default_route_table_id : null
}

# ============================================================================
# SSM Parameter Store Exports for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "vpc_id" {
  name        = "/shared/network/vpc-id"
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

resource "aws_ssm_parameter" "public_subnet_ids" {
  name        = "/shared/network/public-subnet-ids"
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
  name        = "/shared/network/private-subnet-ids"
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
