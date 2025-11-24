# ============================================================================
# Outputs
# ============================================================================

output "zone_id" {
  description = "Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_arn" {
  description = "Hosted Zone ARN"
  value       = aws_route53_zone.main.arn
}

output "name_servers" {
  description = "Name servers for the hosted zone"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "Domain name"
  value       = aws_route53_zone.main.name
}

# ============================================================================
# SSM Parameters for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "zone_id" {
  name        = "/shared/${var.project_name}/dns/${local.zone_name}/zone-id"
  description = "Route53 hosted zone ID for cross-stack references"
  type        = "String"
  value       = aws_route53_zone.main.zone_id

  tags = merge(
    local.required_tags,
    {
      Name      = "zone-id-export"
      Component = "dns"
    }
  )
}

resource "aws_ssm_parameter" "name_servers" {
  name        = "/shared/${var.project_name}/dns/${local.zone_name}/name-servers"
  description = "Route53 name servers for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_route53_zone.main.name_servers)

  tags = merge(
    local.required_tags,
    {
      Name      = "name-servers-export"
      Component = "dns"
    }
  )
}
