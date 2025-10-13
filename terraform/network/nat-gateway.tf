# Elastic IP for NAT Gateway

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
    Component   = "shared-infrastructure"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.environment}-nat-gateway"
    Environment = var.environment
    Component   = "shared-infrastructure"
  }

  depends_on = [aws_internet_gateway.main]
}
