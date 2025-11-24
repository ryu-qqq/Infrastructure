# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Resource naming
  name_prefix = "${var.environment}-${var.project_name}"

  # Certificate name (sanitized domain name)
  cert_name = replace(var.domain_name, "*.", "wildcard-")

  # Required governance tags
  required_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    CostCenter  = var.cost_center
    DataClass   = var.data_class
    Lifecycle   = var.resource_lifecycle
    Service     = "certificate"
  }

  # All domains (primary + SANs)
  all_domains = concat([var.domain_name], var.subject_alternative_names)
}
