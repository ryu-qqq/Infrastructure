# Local variables for Atlantis stack

locals {
  # Common naming prefix
  name_prefix = "atlantis-${var.environment}"

  # Required tags following governance standards
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }

  # Common tags to be merged with module-specific tags (alias for compatibility)
  common_tags = local.required_tags
}
