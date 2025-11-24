# ============================================================================
# Local Variables
# ============================================================================

locals {
  name_prefix = "${var.environment}-${var.project_name}"
  zone_name   = replace(var.domain_name, ".", "-")

  required_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    DataClass   = var.data_class
    Lifecycle   = var.resource_lifecycle
    Service     = "dns"
  }
}
