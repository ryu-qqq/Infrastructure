# Public Subnets

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  # Note: Imported existing subnet - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(local.required_tags, {
    Name = "${var.environment}-public-subnet-${count.index + 1}"
    Type = "Public"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# Private Subnets

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Note: Imported existing subnet - tags defined for governance compliance
  # Tags are not modified in AWS due to IAM permission constraints
  tags = merge(local.required_tags, {
    Name = "${var.environment}-private-subnet-${count.index + 1}"
    Type = "Private"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}
