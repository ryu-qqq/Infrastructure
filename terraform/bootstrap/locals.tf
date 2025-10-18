locals {
  # Required tags for all resources
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = "permanent"
    DataClass   = "internal"
    Service     = var.service
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }

  # Resource naming
  kms_key_alias = "alias/terraform-state"
}
