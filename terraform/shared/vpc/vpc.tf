# ============================================================================
# VPC
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  instance_tenancy     = "default"

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )

  # Imported existing VPC - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}

# ============================================================================
# Internet Gateway
# ============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-igw"
    }
  )

  # Imported existing IGW - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}
