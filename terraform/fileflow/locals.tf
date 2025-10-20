# Local variables for common naming and tagging

locals {
  # Organization and service naming
  org_name     = "connectly"
  service_name = "fileflow"

  # Name prefix for resources
  name_prefix = "${var.environment}-${local.service_name}"

  # Account ID
  account_id = data.aws_caller_identity.current.account_id

  # Required tags for all resources (governance standard)
  required_tags = {
    Owner       = var.tags_owner
    CostCenter  = var.tags_cost_center
    Environment = var.environment
    Lifecycle   = var.environment == "prod" ? "production" : var.environment
    Service     = local.service_name
    Team        = var.tags_team
    DataClass   = "sensitive"
  }
}
