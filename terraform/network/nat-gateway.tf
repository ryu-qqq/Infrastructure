# Elastic IP for NAT Gateway

resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  # Note: Imported existing EIP - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(local.required_tags, {
    Name = "${var.environment}-nat-eip-${var.availability_zones[count.index]}"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# NAT Gateway

resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  # Note: Imported existing NAT Gateway - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(local.required_tags, {
    Name = "${var.environment}-nat-gateway-${var.availability_zones[count.index]}"
  })

  lifecycle {
    ignore_changes = [tags]
  }

  depends_on = [aws_internet_gateway.main]
}
