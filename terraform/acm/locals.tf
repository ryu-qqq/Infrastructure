# Local Values

locals {
  # Certificate configuration
  certificate_config = {
    domain_name       = var.domain_name
    wildcard_domain   = "*.${var.domain_name}"
    validation_method = "DNS"
  }
}
