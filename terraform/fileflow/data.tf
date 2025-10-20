# Data sources for existing shared resources

# Current AWS account and region
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# VPC information (shared infrastructure)
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Subnets (shared infrastructure)
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Type"
    values = ["public"]
  }
}

# KMS Keys (shared infrastructure)
data "terraform_remote_state" "kms" {
  backend = "s3"

  config = {
    bucket = "${var.environment}-${local.org_name}"
    key    = "kms/terraform.tfstate"
    region = var.aws_region
  }
}

# RDS (shared MySQL database)
data "terraform_remote_state" "rds" {
  backend = "s3"

  config = {
    bucket = "${var.environment}-${local.org_name}"
    key    = "rds/terraform.tfstate"
    region = var.aws_region
  }
}

# Monitoring (shared infrastructure)
data "terraform_remote_state" "monitoring" {
  backend = "s3"

  config = {
    bucket = "${var.environment}-${local.org_name}"
    key    = "monitoring/terraform.tfstate"
    region = var.aws_region
  }
}
