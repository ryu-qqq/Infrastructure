# Local Values for Route53 Infrastructure
# Centralizes configuration and computed values for better maintainability

locals {
  # Required tags following v1.0.0 pattern
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project
    DataClass   = var.data_class
    Lifecycle   = "permanent"
    ManagedBy   = "terraform"
  }

  # Domain configuration
  domain_config = {
    domain_name   = var.domain_name
    comment       = "Primary hosted zone for ${var.domain_name}"
    force_destroy = false # Prevent accidental deletion
  }

  # Health check configuration for critical services
  health_check_config = {
    atlantis = {
      fqdn              = "atlantis.${var.domain_name}"
      port              = 443
      type              = "HTTPS"
      resource_path     = "/healthz"
      failure_threshold = 3
      request_interval  = 30
    }
  }

  # CloudWatch log configuration
  log_config = {
    log_group_name    = "/aws/route53/${var.domain_name}"
    retention_in_days = 7 # 7 days retention as per logging standards
  }

  # KMS configuration
  kms_config = {
    description             = "KMS key for Route53 query logs encryption"
    deletion_window_in_days = 30
    enable_key_rotation     = true
  }
}
