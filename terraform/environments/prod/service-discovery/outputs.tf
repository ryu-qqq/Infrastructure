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

locals {
  ssm_parameters = {
    "namespace-id" = {
      description = "Cloud Map namespace ID for cross-stack references"
      value       = aws_service_discovery_private_dns_namespace.main.id
    }
    "namespace-arn" = {
      description = "Cloud Map namespace ARN for cross-stack references"
      value       = aws_service_discovery_private_dns_namespace.main.arn
    }
    "namespace-name" = {
      description = "Cloud Map namespace name for cross-stack references"
      value       = aws_service_discovery_private_dns_namespace.main.name
    }
  }
}

resource "aws_ssm_parameter" "exports" {
  for_each = local.ssm_parameters

  name        = "/shared/service-discovery/${each.key}"
  description = each.value.description
  type        = "String"
  value       = each.value.value

  tags = merge(
    local.required_tags,
    {
      Name      = "service-discovery-${each.key}"
      Component = "service-discovery"
    }
  )
}
