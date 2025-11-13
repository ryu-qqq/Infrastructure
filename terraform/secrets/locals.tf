# Local Values for Secrets Manager Module

data "aws_caller_identity" "current" {}

# Reference KMS key from remote state
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = "prod-tfstate"
    key    = "kms/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  # Required tags following governance standards
  # Reference: docs/infrastructure_governance.md
  required_tags = {
    Environment = var.environment
    Service     = var.service
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = var.managed_by
    Project     = var.project
    DataClass   = "highly-confidential"
  }

  # Account ID for policies
  account_id = data.aws_caller_identity.current.account_id

  # GitHub Actions Role ARN
  github_actions_role_arn = "arn:aws:iam::${local.account_id}:role/${var.github_actions_role_name}"

  # KMS Key ID from remote state
  secrets_manager_kms_key_id = data.terraform_remote_state.kms.outputs.secrets_manager_key_id

  # Organization name for secret naming
  org_name = "ryuqqq"

  # Example secrets to demonstrate structure
  # In real usage, these would be defined in service-specific modules
  example_secrets = {
    # RDS credentials example
    db_master = {
      name        = "/${local.org_name}/common/${var.environment}/db-master"
      description = "RDS master database credentials"
      type        = "rds"
    }

    # API key example
    api_key = {
      name        = "/${local.org_name}/common/${var.environment}/api-key-example"
      description = "Example API key for external service"
      type        = "api_key"
    }
  }
}
