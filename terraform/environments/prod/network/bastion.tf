# ============================================================================
# Bastion Host Module
# ============================================================================

module "bastion" {
  source = "../../../modules/bastion-ssm"

  # Only create bastion if enabled
  count = var.enable_bastion ? 1 : 0

  # Required parameters
  environment = var.environment
  vpc_id      = data.aws_vpc.main.id
  vpc_cidr    = data.aws_vpc.main.cidr_block
  subnet_id   = data.aws_subnet.private[0].id
  aws_region  = var.aws_region

  # Private subnet IDs for VPC endpoints
  private_subnet_ids = data.aws_subnet.private[*].id

  # Common tags (required for governance)
  common_tags = local.required_tags

  # Optional parameters
  instance_type              = var.bastion_instance_type
  volume_size                = var.bastion_volume_size
  enable_session_logging     = var.enable_bastion_session_logging
  session_log_retention_days = var.bastion_session_log_retention_days
  enable_detailed_monitoring = true
}
