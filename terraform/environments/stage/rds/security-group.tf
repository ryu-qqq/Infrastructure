# RDS Security Group using security-group module

module "rds_security_group" {
  source = "../../../modules/security-group"

  name        = "${local.name_prefix}-sg"
  description = "Security group for staging shared MySQL RDS instance"
  vpc_id      = var.vpc_id
  type        = "rds"

  # RDS-specific configuration
  rds_port                      = var.port
  rds_additional_ingress_sg_ids = var.allowed_security_group_ids
  rds_ingress_cidr_blocks       = var.allowed_cidr_blocks

  # Required tagging information
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class

  # Additional tags
  additional_tags = var.tags
}
