# Basic Example - Minimal RDS Configuration
#
# This example demonstrates the minimum required configuration
# to deploy an RDS MySQL instance.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Type = "private"
  }
}

# Required Tags for Governance
locals {
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = "platform-team"
    Owner       = "fbtkdals2@naver.com"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
    Project     = "rds-module-example"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.service_name}-rds-${var.environment}"
  description = "Security group for RDS MySQL instance"
  vpc_id      = var.vpc_id

  # NOTE: For production environments, restrict ingress to specific
  # application security groups instead of allowing all traffic from VPC
  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  # NOTE: RDS does not require egress rules as it's managed by AWS
  # Egress rules are automatically managed

  tags = merge(
    local.required_tags,
    {
      Name = "${var.service_name}-rds-${var.environment}"
    }
  )
}

# RDS Module - Basic MySQL Configuration
module "rds_mysql" {
  source = "../../"

  # Required variables
  identifier        = "${var.service_name}-mysql-${var.environment}"
  engine            = "mysql"
  engine_version    = "8.0.35"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  # Database Configuration
  db_name         = var.db_name
  master_username = var.master_username
  master_password = var.master_password

  # Network Configuration
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.rds.id]

  # Tags
  common_tags = local.required_tags
}

# Outputs
output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = module.rds_mysql.db_instance_endpoint
}

output "db_address" {
  description = "The hostname of the RDS instance"
  value       = module.rds_mysql.db_instance_address
}

output "db_port" {
  description = "The port on which the DB accepts connections"
  value       = module.rds_mysql.db_instance_port
}

output "db_name" {
  description = "The database name"
  value       = module.rds_mysql.db_instance_name
}

output "db_instance_id" {
  description = "The identifier of the RDS instance"
  value       = module.rds_mysql.db_instance_id
}
