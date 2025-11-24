# ============================================================================
# Public Route Table
# ============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-public-rt"
      Type = "Public"
    }
  )

  # Imported existing route table - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}

# Public Route - Internet Gateway
resource "aws_route" "public-internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Subnet Route Table Associations
resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================================================
# Private Route Tables
# ============================================================================

# Private route table per AZ (for HA) or single table (for cost optimization)
resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : local.az_count

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name = var.single_nat_gateway ? "${local.name_prefix}-private-rt" : "${local.name_prefix}-private-rt-${count.index + 1}"
      Type = "Private"
    }
  )

  # Imported existing route table - preserve existing tags
  lifecycle {
    ignore_changes = [tags]
  }
}

# Private Route - NAT Gateway
resource "aws_route" "private-nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Private Subnet Route Table Associations
resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
