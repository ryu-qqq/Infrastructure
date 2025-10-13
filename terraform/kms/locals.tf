# Local Values for KMS Module

data "aws_caller_identity" "current" {}

locals {
  # Required tags following governance standards
  # Reference: docs/TAGGING_STANDARDS.md
  required_tags = {
    Environment = var.environment
    Service     = var.service
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = var.managed_by
    Project     = var.project
  }

  # Account ID for policies
  account_id = data.aws_caller_identity.current.account_id

  # GitHub Actions Role ARN (used across multiple KMS policies)
  github_actions_role_arn = "arn:aws:iam::${local.account_id}:role/${var.github_actions_role_name}"
}
