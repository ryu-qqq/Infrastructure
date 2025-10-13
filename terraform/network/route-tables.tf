# Public Route Table

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Note: Imported existing route table - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(local.required_tags, {
    Name = "${var.environment}-public-rt"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# Public Route - Internet Gateway
# Note: aws_route resources do not support tags - they inherit from route table

resource "aws_route" "public-internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Subnet Route Table Associations

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  # Note: Imported existing route table - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(local.required_tags, {
    Name = "${var.environment}-private-rt-${var.availability_zones[count.index]}"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# Private Route - NAT Gateway
# Note: aws_route resources do not support tags - they inherit from route table

resource "aws_route" "private-nat" {
  count                  = length(var.private_subnet_cidrs)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Private Subnet Route Table Associations

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
