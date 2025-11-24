# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Resource naming
  name_prefix = "${var.environment}-${var.project_name}"

  # Required governance tags
  required_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    DataClass   = var.data_class
    Lifecycle   = var.resource_lifecycle
    Service     = "database"
  }

  # Database port based on engine
  db_port = var.engine == "mysql" ? 3306 : 5432
}
