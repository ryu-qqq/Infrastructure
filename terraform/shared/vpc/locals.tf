# ============================================================================
# Local Values
# ============================================================================

locals {
  # Resource naming convention: {environment}-{project}-{resource}
  name_prefix = "${var.environment}-${var.project_name}"

  # Required tags for governance compliance
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.resource_lifecycle
    DataClass   = var.data_class
    Service     = "network"
    ManagedBy   = "terraform"
    Project     = var.project_name
  }

  # Number of AZs (used for subnet count calculations)
  az_count = length(var.availability_zones)
}
