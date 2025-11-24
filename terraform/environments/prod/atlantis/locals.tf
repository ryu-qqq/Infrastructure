# Local variables for Atlantis stack

locals {
  # Common naming prefix
  name_prefix = "atlantis-${var.environment}"

  # Common tags to be merged with module-specific tags
  common_tags = {
    Environment = var.environment
    ServiceName = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }
}
