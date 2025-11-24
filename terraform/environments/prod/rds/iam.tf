# IAM Role for Enhanced Monitoring using iam-role-policy module

module "rds_monitoring_role" {
  count = var.enable_enhanced_monitoring ? 1 : 0

  source = "../../../modules/iam-role-policy"

  role_name = "${local.name_prefix}-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  # Required tagging information
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class

  # Attach AWS managed policy for RDS Enhanced Monitoring
  attach_aws_managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  ]

  # Additional tags
  additional_tags = var.tags
}
