locals {
  # Resource naming
  kms_key_alias = "alias/terraform-state"

  # AWS region
  aws_region = var.aws_region

  # Account ID (dynamically fetched)
  account_id = data.aws_caller_identity.current.account_id
}
