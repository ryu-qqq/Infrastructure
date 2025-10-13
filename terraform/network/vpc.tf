# VPC Resource

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  # Note: Imported existing VPC - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(local.required_tags, {
    Name = "${var.environment}-server-vpc"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}
