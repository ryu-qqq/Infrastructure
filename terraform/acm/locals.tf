# Local Values

locals {
  # Required tags for governance compliance
  required_tags = {
    Owner       = "platform-team"
    Team        = "platform-team"
    CostCenter  = "infrastructure"
    Lifecycle   = "production"
    DataClass   = "public"
    Service     = "certificate-management"
    Environment = var.environment
    Project     = "infrastructure"
    Component   = "acm"
  }

  # Certificate configuration
  certificate_config = {
    domain_name       = var.domain_name
    wildcard_domain   = "*.${var.domain_name}"
    validation_method = "DNS"
  }
}
