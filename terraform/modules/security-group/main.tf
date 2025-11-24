# Common Tags Module
module "tags" {
  source = "../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = var.additional_tags
}

locals {
  # Required tags for governance compliance
  required_tags = module.tags.tags
}

# Security Group
resource "aws_security_group" "this" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  revoke_rules_on_delete = var.revoke_rules_on_delete

  tags = merge(
    local.required_tags,
    {
      Name        = var.name
      Description = var.description
      Type        = var.type
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# --- ALB Security Group Rules ---

resource "aws_vpc_security_group_ingress_rule" "alb-http" {
  for_each = var.type == "alb" && var.alb_enable_http ? toset(var.alb_ingress_cidr_blocks) : []

  security_group_id = aws_security_group.this.id
  from_port         = var.alb_http_port
  to_port           = var.alb_http_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Allow HTTP traffic from internet"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-http-ingress-${replace(each.value, "/", "-")}"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb-https" {
  for_each = var.type == "alb" && var.alb_enable_https ? toset(var.alb_ingress_cidr_blocks) : []

  security_group_id = aws_security_group.this.id
  from_port         = var.alb_https_port
  to_port           = var.alb_https_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Allow HTTPS traffic from internet"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-https-ingress-${replace(each.value, "/", "-")}"
    }
  )
}

# --- ECS Security Group Rules ---

resource "aws_vpc_security_group_ingress_rule" "ecs-from-alb" {
  count = var.type == "ecs" && var.ecs_ingress_from_alb_sg_id != null ? 1 : 0

  security_group_id            = aws_security_group.this.id
  from_port                    = var.ecs_container_port
  to_port                      = var.ecs_container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.ecs_ingress_from_alb_sg_id
  description                  = "Allow traffic from ALB to ECS container"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-from-alb-ingress"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "ecs-additional" {
  for_each = var.type == "ecs" ? toset(var.ecs_additional_ingress_sg_ids) : []

  security_group_id            = aws_security_group.this.id
  from_port                    = var.ecs_container_port
  to_port                      = var.ecs_container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow traffic from additional security group"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-additional-ingress-${each.value}"
    }
  )
}

# --- RDS Security Group Rules ---

resource "aws_vpc_security_group_ingress_rule" "rds-from-ecs" {
  count = var.type == "rds" && var.rds_ingress_from_ecs_sg_id != null ? 1 : 0

  security_group_id            = aws_security_group.this.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.rds_ingress_from_ecs_sg_id
  description                  = "Allow traffic from ECS to RDS"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-from-ecs-ingress"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "rds-additional" {
  for_each = var.type == "rds" ? toset(var.rds_additional_ingress_sg_ids) : []

  security_group_id            = aws_security_group.this.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow traffic from additional security group"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-additional-ingress-${each.value}"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "rds-cidr" {
  for_each = var.type == "rds" ? toset(var.rds_ingress_cidr_blocks) : []

  security_group_id = aws_security_group.this.id
  from_port         = var.rds_port
  to_port           = var.rds_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Allow traffic from CIDR block"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-cidr-ingress-${each.value}"
    }
  )
}

# --- VPC Endpoint Security Group Rules ---

resource "aws_vpc_security_group_ingress_rule" "vpc-endpoint-cidr" {
  for_each = var.type == "vpc-endpoint" ? toset(var.vpc_endpoint_ingress_cidr_blocks) : []

  security_group_id = aws_security_group.this.id
  from_port         = var.vpc_endpoint_port
  to_port           = var.vpc_endpoint_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Allow traffic from CIDR block to VPC endpoint"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-cidr-ingress-${each.value}"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "vpc-endpoint-sg" {
  for_each = var.type == "vpc-endpoint" ? toset(var.vpc_endpoint_ingress_sg_ids) : []

  security_group_id            = aws_security_group.this.id
  from_port                    = var.vpc_endpoint_port
  to_port                      = var.vpc_endpoint_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow traffic from security group to VPC endpoint"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-sg-ingress-${each.value}"
    }
  )
}

# --- Custom Ingress Rules ---

resource "aws_vpc_security_group_ingress_rule" "custom" {
  for_each = { for idx, rule in var.custom_ingress_rules : idx => rule }

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol

  cidr_ipv4                    = each.value.cidr_block
  cidr_ipv6                    = each.value.ipv6_cidr_block
  referenced_security_group_id = each.value.source_security_group_id

  description = coalesce(each.value.description, "Custom ingress rule ${each.key}")

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-custom-ingress-${each.key}"
    }
  )

  lifecycle {
    precondition {
      condition = (
        (each.value.cidr_block != null ? 1 : 0) +
        (each.value.ipv6_cidr_block != null ? 1 : 0) +
        (each.value.source_security_group_id != null ? 1 : 0)
      ) == 1
      error_message = "Exactly one of cidr_block, ipv6_cidr_block, or source_security_group_id must be specified for custom ingress rule ${each.key}."
    }
  }
}

# --- Default Egress Rule ---

resource "aws_vpc_security_group_egress_rule" "default" {
  count = var.enable_default_egress ? 1 : 0

  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic"

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-default-egress"
    }
  )
}

# --- Custom Egress Rules ---

resource "aws_vpc_security_group_egress_rule" "custom" {
  for_each = { for idx, rule in var.custom_egress_rules : idx => rule }

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol

  cidr_ipv4                    = each.value.cidr_block
  cidr_ipv6                    = each.value.ipv6_cidr_block
  referenced_security_group_id = each.value.destination_security_group_id

  description = coalesce(each.value.description, "Custom egress rule ${each.key}")

  tags = merge(
    local.required_tags,
    {
      Name = "${var.name}-custom-egress-${each.key}"
    }
  )

  lifecycle {
    precondition {
      condition = (
        (each.value.cidr_block != null ? 1 : 0) +
        (each.value.ipv6_cidr_block != null ? 1 : 0) +
        (each.value.destination_security_group_id != null ? 1 : 0)
      ) == 1
      error_message = "Exactly one of cidr_block, ipv6_cidr_block, or destination_security_group_id must be specified for custom egress rule ${each.key}."
    }
  }
}
