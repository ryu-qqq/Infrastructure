# ============================================================================
# Bastion Host Security Group
# ============================================================================

resource "aws_security_group" "bastion" {
  name        = "${var.environment}-bastion-sg"
  description = "Security group for bastion host with SSM Session Manager"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.environment}-bastion-sg"
    }
  )
}

# Egress rule: Allow all outbound traffic for SSM endpoints and package updates
resource "aws_security_group_rule" "bastion_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
  description       = "Allow all outbound traffic for SSM and updates"
}

# Note: No ingress rules needed for SSM Session Manager
# All access is through AWS Systems Manager Session Manager
