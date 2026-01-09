locals {
  # Resource naming - stage uses separate KMS key alias
  kms_key_alias = "alias/terraform-state-stage"

  # AWS region
  aws_region = var.aws_region

  # Account ID (dynamically fetched)
  account_id = data.aws_caller_identity.current.account_id

  # Zero-Tolerance: 모든 리소스에 필수 태그 적용
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    Service     = var.service
    Team        = var.team
    ManagedBy   = "terraform"
    Project     = var.project
  }
}
