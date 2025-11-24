# Elastic IP for NAT Gateway

resource "aws_eip" "nat" {
  domain = "vpc"

  # Note: Imported existing EIP - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(
    local.common_tags,
    {
      Name       = "${var.environment}-nat-eip"
      Owner      = var.team
      CostCenter = var.cost_center
      Lifecycle  = var.lifecycle_stage
      DataClass  = var.data_class
      Service    = var.service_name
      Component  = var.project
    }
  )

  lifecycle {
    ignore_changes = [tags]
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  # Note: Imported existing NAT Gateway - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(
    local.common_tags,
    {
      Name       = "${var.environment}-nat-gateway"
      Owner      = var.team
      CostCenter = var.cost_center
      Lifecycle  = var.lifecycle_stage
      DataClass  = var.data_class
      Service    = var.service_name
      Component  = var.project
    }
  )

  lifecycle {
    ignore_changes = [tags]
  }

  depends_on = [aws_internet_gateway.main]
}
