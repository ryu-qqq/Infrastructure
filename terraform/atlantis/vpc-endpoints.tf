# VPC Endpoints Configuration
# This file defines VPC endpoints to optimize AWS service access from private subnets

# Data sources for existing VPC resources
data "aws_vpc" "main" {
  id = "vpc-0f162b9e588276e09"
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

data "aws_route_tables" "private" {
  vpc_id = data.aws_vpc.main.id

  filter {
    name   = "association.subnet-id"
    values = data.aws_subnets.private.ids
  }
}

# Security Group for VPC Endpoints (Interface type)
resource "aws_security_group" "vpc-endpoints" {
  name        = "vpc-endpoint-sg"
  description = "Security group for VPC Interface Endpoints"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  # No egress rules needed - VPC Interface Endpoints only handle inbound traffic from VPC to AWS services
  # AWS services respond through the same interface without requiring explicit egress rules

  tags = merge(
    local.required_tags,
    {
      Name        = "vpc-endpoint-sg"
      Environment = "prod"
      Component   = "vpc-endpoints"
      Description = "Security group for VPC Interface Endpoints"
    }
  )
}

# S3 Gateway Endpoint (Free)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids

  tags = merge(
    local.required_tags,
    {
      Name        = "s3-gateway-endpoint"
      Environment = "prod"
      Component   = "vpc-endpoints"
      Purpose     = "Cost optimization for S3 access"
    }
  )
}

# ECR API Interface Endpoint
resource "aws_vpc_endpoint" "ecr-api" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.vpc-endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.required_tags,
    {
      Name        = "ecr-api-endpoint"
      Environment = "prod"
      Component   = "vpc-endpoints"
      Purpose     = "ECS container image pull optimization"
    }
  )
}

# ECR DKR Interface Endpoint
resource "aws_vpc_endpoint" "ecr-dkr" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.vpc-endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.required_tags,
    {
      Name        = "ecr-dkr-endpoint"
      Environment = "prod"
      Component   = "vpc-endpoints"
      Purpose     = "ECS Docker registry access optimization"
    }
  )
}

# Secrets Manager Interface Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.vpc-endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.required_tags,
    {
      Name        = "secretsmanager-endpoint"
      Environment = "prod"
      Component   = "vpc-endpoints"
      Purpose     = "Secure secrets access from private subnets"
    }
  )
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = data.aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.vpc-endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.required_tags,
    {
      Name        = "logs-endpoint"
      Environment = "prod"
      Component   = "vpc-endpoints"
      Purpose     = "CloudWatch Logs optimization"
    }
  )
}

# Outputs
output "vpc_endpoint_s3_id" {
  description = "ID of S3 Gateway Endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "vpc_endpoint_ecr_api_id" {
  description = "ID of ECR API Interface Endpoint"
  value       = aws_vpc_endpoint.ecr-api.id
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "ID of ECR DKR Interface Endpoint"
  value       = aws_vpc_endpoint.ecr-dkr.id
}

output "vpc_endpoint_secretsmanager_id" {
  description = "ID of Secrets Manager Interface Endpoint"
  value       = aws_vpc_endpoint.secretsmanager.id
}

output "vpc_endpoint_logs_id" {
  description = "ID of CloudWatch Logs Interface Endpoint"
  value       = aws_vpc_endpoint.logs.id
}

output "vpc_endpoint_sg_id" {
  description = "Security Group ID for VPC Endpoints"
  value       = aws_security_group.vpc-endpoints.id
}
