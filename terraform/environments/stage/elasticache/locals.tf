# Local Variables

locals {
  # Common naming prefix
  name_prefix = "${var.environment}-${var.cluster_id}"

  # Required tags for all resources
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
  }
}
