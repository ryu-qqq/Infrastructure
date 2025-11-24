# Local Values

locals {
  # Certificate configuration
  certificate_config = {
    domain_name       = var.domain_name
    wildcard_domain   = "*.${var.domain_name}"
    validation_method = "DNS"
  }

  # Environment to Lifecycle mapping
  lifecycle_mapping = {
    prod    = "production"
    staging = "staging"
    dev     = "development"
  }

  lifecycle = lookup(local.lifecycle_mapping, var.environment, "temporary")

  # Required tags following governance standards
  required_tags = {
    Owner       = var.owner
    CostCenter  = var.cost_center
    Environment = var.environment
    Lifecycle   = local.lifecycle
    DataClass   = var.data_class
    Service     = var.service
    ManagedBy   = var.managed_by
    Project     = var.project
  }

  # Route53 Zone ID Resolution (Cross-Stack Reference Pattern)
  # Use provided zone_id or lookup from SSM Parameter Store
  route53_zone_id = var.route53_zone_id != "" ? var.route53_zone_id : data.aws_ssm_parameter.route53-zone-id[0].value
}
