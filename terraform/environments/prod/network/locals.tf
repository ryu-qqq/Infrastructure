# Local Values

locals {
  # Common naming prefix
  name_prefix = "${var.environment}-${var.service_name}"

  # Required tags following project governance standards
  required_tags = {
    Owner       = var.team
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = var.lifecycle_stage
    DataClass   = var.data_class
    Service     = var.service_name
  }

  # Legacy common_tags for backward compatibility (will be deprecated)
  common_tags = local.required_tags
}
