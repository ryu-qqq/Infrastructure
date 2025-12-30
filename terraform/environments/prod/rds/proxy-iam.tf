# ============================================================================
# RDS Proxy IAM Role Configuration
# ============================================================================
# RDS Proxy가 Secrets Manager에서 DB 자격증명을 읽기 위한 IAM Role
# ============================================================================

module "rds_proxy_role" {
  count = var.enable_rds_proxy ? 1 : 0

  source = "../../../modules/iam-role-policy"

  role_name = "${local.name_prefix}-proxy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
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

  # Custom inline policy for Secrets Manager access
  custom_inline_policies = {
    secrets-manager-access = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "GetSecretValue"
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue"
            ]
            Resource = [
              aws_secretsmanager_secret.db-master-password.arn
            ]
          },
          {
            Sid    = "DecryptSecretValue"
            Effect = "Allow"
            Action = [
              "kms:Decrypt"
            ]
            Resource = [
              data.aws_kms_key.secrets_manager.arn
            ]
            Condition = {
              StringEquals = {
                "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
              }
            }
          }
        ]
      })
    }
  }

  # Additional tags
  additional_tags = merge(
    var.tags,
    {
      Component = "rds-proxy"
    }
  )
}
