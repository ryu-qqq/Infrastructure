# Common Tags Module
# Provides standardized tagging schema for all AWS resources

locals {
  # Core required tags following governance standards
  required_tags = {
    Environment = var.environment
    Service     = var.service
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = var.managed_by
    Project     = var.project
  }

  # Optional tags that can be added per resource
  optional_tags = var.additional_tags

  # Final merged tags
  tags = merge(local.required_tags, local.optional_tags)
}
