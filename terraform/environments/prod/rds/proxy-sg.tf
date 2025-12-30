# ============================================================================
# RDS Proxy Security Group Configuration
# ============================================================================
# RDS Proxy 전용 보안그룹
# - ECS 태스크들이 Proxy에 연결
# - Proxy가 RDS에 연결
# ============================================================================

module "rds_proxy_security_group" {
  count = var.enable_rds_proxy ? 1 : 0

  source = "../../../modules/security-group"

  name        = "${local.name_prefix}-proxy-sg"
  description = "Security group for RDS Proxy - connection pooling for shared MySQL"
  vpc_id      = var.vpc_id
  type        = "custom"

  # Required tagging information
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class

  # Additional tags
  additional_tags = merge(
    var.tags,
    {
      Component = "rds-proxy"
    }
  )
}

# Ingress: Allow MySQL from ECS tasks (VPC CIDR)
# 향후 ECS 태스크 보안그룹 ID로 변경 권장
resource "aws_vpc_security_group_ingress_rule" "proxy-from-vpc" {
  count = var.enable_rds_proxy ? 1 : 0

  security_group_id = module.rds_proxy_security_group[0].security_group_id

  description = "MySQL from VPC (ECS tasks, Lambda, etc.)"
  from_port   = var.port
  to_port     = var.port
  ip_protocol = "tcp"
  cidr_ipv4   = var.proxy_ingress_cidr_block

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
      Name = "${local.name_prefix}-proxy-ingress-vpc"
    }
  )
}

# Egress: Allow MySQL to RDS
resource "aws_vpc_security_group_egress_rule" "proxy-to-rds" {
  count = var.enable_rds_proxy ? 1 : 0

  security_group_id = module.rds_proxy_security_group[0].security_group_id

  description                  = "MySQL to RDS instance"
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.rds_security_group.security_group_id

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
      Name = "${local.name_prefix}-proxy-egress-rds"
    }
  )
}

# RDS Security Group: Allow ingress from Proxy
resource "aws_vpc_security_group_ingress_rule" "rds-from-proxy" {
  count = var.enable_rds_proxy ? 1 : 0

  security_group_id = module.rds_security_group.security_group_id

  description                  = "MySQL from RDS Proxy"
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.rds_proxy_security_group[0].security_group_id

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
      Name = "${local.name_prefix}-rds-ingress-from-proxy"
    }
  )
}
