locals {
  # Resource naming - stage uses separate KMS key alias
  kms_key_alias = "alias/terraform-state-stage"

  # AWS region
  aws_region = var.aws_region

  # Account ID (dynamically fetched)
  account_id = data.aws_caller_identity.current.account_id
}
