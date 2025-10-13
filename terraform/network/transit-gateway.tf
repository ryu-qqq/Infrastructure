# Transit Gateway Configuration
# Purpose: Central network hub for multi-VPC communication

# Transit Gateway Resource
resource "aws_ec2_transit_gateway" "main" {
  count = var.enable_transit_gateway ? 1 : 0

  description                     = "Transit Gateway for ${var.environment} environment"
  amazon_side_asn                 = var.transit_gateway_asn
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(local.required_tags, {
    Name = "${var.environment}-transit-gateway"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# VPC Attachment to Transit Gateway
# Attaches the VPC to the Transit Gateway using private subnets
resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  count = var.enable_transit_gateway ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpc_id             = aws_vpc.main.id
  subnet_ids         = aws_subnet.private[*].id

  dns_support                                     = "enable"
  ipv6_support                                    = "disable"
  appliance_mode_support                          = "disable"
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(local.required_tags, {
    Name = "${var.environment}-vpc-tgw-attachment"
  })

  lifecycle {
    ignore_changes = [tags]
  }
}

# Transit Gateway Route Table (Default)
# Note: Using default route table for simplicity
# For complex scenarios, create custom route tables

# Routes for Transit Gateway
# Add routes to private subnet route tables pointing to Transit Gateway
resource "aws_route" "private_to_tgw" {
  count = var.enable_transit_gateway && length(var.transit_gateway_routes) > 0 ? length(var.private_subnet_cidrs) * length(var.transit_gateway_routes) : 0

  route_table_id         = aws_route_table.private[floor(count.index / length(var.transit_gateway_routes))].id
  destination_cidr_block = var.transit_gateway_routes[count.index % length(var.transit_gateway_routes)]
  transit_gateway_id     = aws_ec2_transit_gateway.main[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.main]
}
