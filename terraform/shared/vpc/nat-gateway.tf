# ============================================================================
# NAT Gateway
# ============================================================================

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  domain = "vpc"

  tags = merge(
    local.required_tags,
    {
      Name = var.single_nat_gateway ? "${local.name_prefix}-nat-eip" : "${local.name_prefix}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]

  # Imported existing EIP - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    local.required_tags,
    {
      Name = var.single_nat_gateway ? "${local.name_prefix}-nat-gateway" : "${local.name_prefix}-nat-gateway-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]

  # Imported existing NAT Gateway - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}
