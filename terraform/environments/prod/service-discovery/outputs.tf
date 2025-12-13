# Outputs for Service Discovery

output "namespace_id" {
  description = "Cloud Map namespace ID"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "namespace_arn" {
  description = "Cloud Map namespace ARN"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "namespace_name" {
  description = "Cloud Map namespace name"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "namespace_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the namespace"
  value       = aws_service_discovery_private_dns_namespace.main.hosted_zone
}

# ============================================================================
# SSM Parameter Store Exports for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "namespace_id" {
  name        = "/shared/service-discovery/namespace-id"
  description = "Cloud Map namespace ID for cross-stack references"
  type        = "String"
  value       = aws_service_discovery_private_dns_namespace.main.id

  tags = merge(
    local.required_tags,
    {
      Name      = "service-discovery-namespace-id"
      Component = "service-discovery"
    }
  )
}

resource "aws_ssm_parameter" "namespace_arn" {
  name        = "/shared/service-discovery/namespace-arn"
  description = "Cloud Map namespace ARN for cross-stack references"
  type        = "String"
  value       = aws_service_discovery_private_dns_namespace.main.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "service-discovery-namespace-arn"
      Component = "service-discovery"
    }
  )
}

resource "aws_ssm_parameter" "namespace_name" {
  name        = "/shared/service-discovery/namespace-name"
  description = "Cloud Map namespace name for cross-stack references"
  type        = "String"
  value       = aws_service_discovery_private_dns_namespace.main.name

  tags = merge(
    local.required_tags,
    {
      Name      = "service-discovery-namespace-name"
      Component = "service-discovery"
    }
  )
}
