# VPC Resource

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  # Note: Imported existing VPC - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = {
    Name        = "${var.environment}-server-vpc"
    Owner       = var.team
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.lifecycle_stage
    DataClass   = var.data_class
    Service     = var.service_name
    Team        = var.team
    ManagedBy   = "terraform"
    Project     = var.project
    Component   = var.project
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
