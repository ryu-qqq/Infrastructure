# Local Values for KMS Module

data "aws_caller_identity" "current" {}

locals {
  # Account ID for policies
  account_id = data.aws_caller_identity.current.account_id

  # GitHub Actions Role ARN (used across multiple KMS policies)
  github_actions_role_arn = "arn:aws:iam::${local.account_id}:role/${var.github_actions_role_name}"
}
