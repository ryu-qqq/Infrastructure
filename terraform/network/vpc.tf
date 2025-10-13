# VPC Resource

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name        = "${var.environment}-server-vpc"
    Environment = var.environment
    Component   = "shared-infrastructure"
  }
}
