# RDS Security Group

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for shared MySQL RDS instance"
  vpc_id      = var.vpc_id

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-sg"
    }
  )
}

# Ingress rule from allowed security groups
resource "aws_vpc_security_group_ingress_rule" "from-security-groups" {
  count = length(var.allowed_security_group_ids)

  security_group_id = aws_security_group.rds.id

  description                  = "MySQL from application security group ${count.index + 1}"
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.allowed_security_group_ids[count.index]

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-ingress-sg-${count.index + 1}"
    }
  )
}

# Ingress rule from allowed CIDR blocks
resource "aws_vpc_security_group_ingress_rule" "from-cidr-blocks" {
  count = length(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.rds.id

  description = "MySQL from CIDR block ${var.allowed_cidr_blocks[count.index]}"
  from_port   = var.port
  to_port     = var.port
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_cidr_blocks[count.index]

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-ingress-cidr-${count.index + 1}"
    }
  )
}

# Ingress rule from Secrets Manager rotation Lambda
resource "aws_vpc_security_group_ingress_rule" "from-rotation-lambda" {
  count = var.enable_secrets_rotation ? 1 : 0

  security_group_id = aws_security_group.rds.id

  description                  = "MySQL from Secrets Manager rotation Lambda"
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.terraform_remote_state.secrets.outputs.rotation_lambda_security_group_id

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-ingress-rotation-lambda"
    }
  )
}

# Egress rule (allow all outbound - required for maintenance)
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.rds.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(
    local.required_tags,
    {
      Name = "${local.name_prefix}-egress-all"
    }
  )
}
