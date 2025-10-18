# ==============================================================================
# WebACL Outputs
# ==============================================================================

output "web_acl_id" {
  description = "The ID of the WAF WebACL"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "The ARN of the WAF WebACL"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_name" {
  description = "The name of the WAF WebACL"
  value       = aws_wafv2_web_acl.this.name
}

output "web_acl_capacity" {
  description = "The web ACL capacity units (WCUs) currently being used by this web ACL"
  value       = aws_wafv2_web_acl.this.capacity
}

# ==============================================================================
# Logging Outputs
# ==============================================================================

output "logging_configuration_id" {
  description = "The ID of the WAF logging configuration (if enabled)"
  value       = try(aws_wafv2_web_acl_logging_configuration.this[0].id, null)
}

# ==============================================================================
# CloudWatch Metrics
# ==============================================================================

output "cloudwatch_metric_name" {
  description = "The CloudWatch metric name for the WebACL"
  value       = local.metric_name
}

output "cloudwatch_namespace" {
  description = "The CloudWatch namespace for WAF metrics"
  value       = "AWS/WAFV2"
}

# ==============================================================================
# Configuration Summary
# ==============================================================================

output "enabled_features" {
  description = "Summary of enabled WAF features"
  value = {
    owasp_rules   = var.enable_owasp_rules
    rate_limiting = var.enable_rate_limiting
    geo_blocking  = var.enable_geo_blocking
    ip_reputation = var.enable_ip_reputation
    anonymous_ip  = var.enable_anonymous_ip
    logging       = var.enable_logging && var.log_destination_arn != null
    custom_rules  = length(var.custom_rules)
  }
}

output "rate_limit_value" {
  description = "Configured rate limit (requests per 5 minutes)"
  value       = var.enable_rate_limiting ? var.rate_limit : null
}

output "blocked_countries" {
  description = "List of blocked country codes"
  value       = var.enable_geo_blocking ? var.blocked_countries : []
}

# ==============================================================================
# Resource Associations
# ==============================================================================

output "associated_resources" {
  description = "ARNs of resources associated with this WAF"
  value       = var.resource_arns
}
