# ElastiCache Security Group

resource "aws_security_group" "elasticache" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for staging shared ElastiCache cluster"
  vpc_id      = var.vpc_id

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-sg"
      Component = "security"
    }
  )
}

# Ingress rules for allowed security groups
resource "aws_security_group_rule" "ingress_from_sg" {
  count = length(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.elasticache.id
  description              = "Allow Redis access from security group ${var.allowed_security_group_ids[count.index]}"
}

# Ingress rules for allowed CIDR blocks
resource "aws_security_group_rule" "ingress_from_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.elasticache.id
  description       = "Allow Redis access from CIDR blocks"
}

# Egress rule - allow all outbound traffic
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elasticache.id
  description       = "Allow all outbound traffic"
}
