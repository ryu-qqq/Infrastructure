# Local Values

locals {
  # Required tags for governance compliance
  required_tags = {
    Owner       = "platform-team"
    Team        = "platform-team"
    CostCenter  = "infrastructure"
    Lifecycle   = "production"
    DataClass   = "public"
    Service     = "dns"
    Environment = var.environment
    Project     = "infrastructure"
    Component   = "route53"
  }

  # Common domain configurations
  domain_config = {
    domain_name   = var.domain_name
    comment       = "Managed by Terraform - ${var.domain_name} DNS zone"
    force_destroy = false # Prevent accidental deletion
  }
}
