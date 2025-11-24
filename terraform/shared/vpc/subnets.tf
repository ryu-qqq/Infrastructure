# ============================================================================
# Public Subnets
# ============================================================================

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
      Type = "Public"
      Tier = "public"
    }
  )

  # Imported existing subnets - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}

# ============================================================================
# Private Subnets
# ============================================================================

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-private-subnet-${count.index + 1}"
      Type = "Private"
      Tier = "private"
    }
  )

  # Imported existing subnets - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}
