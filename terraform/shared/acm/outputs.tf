# ============================================================================
# Outputs
# ============================================================================

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "certificate_id" {
  description = "ID of the ACM certificate"
  value       = aws_acm_certificate.main.id
}

output "certificate_domain_name" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = aws_acm_certificate.main.status
}

output "certificate_domain_validation_options" {
  description = "Domain validation options for the certificate"
  value       = aws_acm_certificate.main.domain_validation_options
}

output "subject_alternative_names" {
  description = "Subject Alternative Names (SANs) for the certificate"
  value       = aws_acm_certificate.main.subject_alternative_names
}

# ============================================================================
# SSM Parameters for Cross-Stack References
# ============================================================================

resource "aws_ssm_parameter" "certificate_arn" {
  name        = "/shared/${var.project_name}/certificate/${local.cert_name}/arn"
  description = "ACM certificate ARN for cross-stack references"
  type        = "String"
  value       = aws_acm_certificate.main.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "cert-arn-export"
      Component = "certificate"
    }
  )
}

resource "aws_ssm_parameter" "certificate_domain" {
  name        = "/shared/${var.project_name}/certificate/${local.cert_name}/domain"
  description = "Certificate domain name for cross-stack references"
  type        = "String"
  value       = aws_acm_certificate.main.domain_name

  tags = merge(
    local.required_tags,
    {
      Name      = "cert-domain-export"
      Component = "certificate"
    }
  )
}
