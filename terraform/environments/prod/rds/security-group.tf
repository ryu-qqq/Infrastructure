# RDS Security Group using security-group module

module "rds_security_group" {
  source = "../../../modules/security-group"

  name        = "${local.name_prefix}-sg"
  description = "Security group for shared MySQL RDS instance"
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

# Additional ingress rule for Secrets Manager rotation Lambda
# This is created separately because it's conditional and depends on remote state
resource "aws_vpc_security_group_ingress_rule" "from-rotation-lambda" {
  count = var.enable_secrets_rotation && try(data.terraform_remote_state.secrets.outputs.rotation_lambda_security_group_id, null) != null ? 1 : 0

  security_group_id = module.rds_security_group.security_group_id

  description                  = "MySQL from Secrets Manager rotation Lambda"
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = try(data.terraform_remote_state.secrets.outputs.rotation_lambda_security_group_id, null)

  tags = merge(
    {
      Environment = var.environment
      Service     = var.service_name
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "Terraform"
      Project     = var.project
      DataClass   = var.data_class
      Stack       = "rds"
    },
    var.tags,
    {
      Name = "${local.name_prefix}-ingress-rotation-lambda"
    }
  )
}
