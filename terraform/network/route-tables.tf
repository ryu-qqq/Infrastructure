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

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Subnet Route Table Associations

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Note: Imported existing route table - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(local.required_tags, {
    Name = "${var.environment}-private-rt"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# Private Route - NAT Gateway

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Private Subnet Route Table Associations

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
