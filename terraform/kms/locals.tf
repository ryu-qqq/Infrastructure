# Local Values for KMS Module

data "aws_caller_identity" "current" {}

locals {
  # Required tags for governance compliance
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    Service     = var.service
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }

  # Account ID for policies
  account_id = data.aws_caller_identity.current.account_id

  # GitHub Actions Role ARN (used across multiple KMS policies)
  github_actions_role_arn = "arn:aws:iam::${local.account_id}:role/${var.github_actions_role_name}"
}
