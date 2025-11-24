# Common Tags Module
# Provides standardized tagging schema for all AWS resources

locals {
  # Environment to Lifecycle mapping
  lifecycle_mapping = {
    prod    = "production"
    staging = "staging"
    dev     = "development"
  }

  lifecycle = lookup(local.lifecycle_mapping, var.environment, "temporary")

  # Core required tags following governance standards (8 required tags)
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = local.lifecycle
    DataClass   = var.data_class
    Service     = var.service
    ManagedBy   = var.managed_by
    Project     = var.project
  }

  # Optional tags that can be added per resource
  optional_tags = var.additional_tags

  # Final merged tags
  tags = merge(local.required_tags, local.optional_tags)
}
