# Outputs for ACM Certificate Management

output "certificate_arn" {
  description = "ARN of the wildcard certificate"
  value       = aws_acm_certificate.wildcard.arn
}

output "certificate_id" {
  description = "ID of the wildcard certificate"
  value       = aws_acm_certificate.wildcard.id
}

output "certificate_domain_name" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.wildcard.domain_name
}

output "certificate_status" {
  description = "Status of the certificate"
  value       = aws_acm_certificate.wildcard.status
}

output "certificate_subject_alternative_names" {
  description = "Subject Alternative Names (SANs) for the certificate"
  value       = aws_acm_certificate.wildcard.subject_alternative_names
}

output "certificate_validation_method" {
  description = "Validation method used for the certificate"
  value       = aws_acm_certificate.wildcard.validation_method
}

output "certificate_not_after" {
  description = "Expiration date of the certificate"
  value       = aws_acm_certificate.wildcard.not_after
}

output "certificate_not_before" {
  description = "Start date of the certificate validity"
  value       = aws_acm_certificate.wildcard.not_before
}

output "validation_record_fqdns" {
  description = "FQDNs of the DNS validation records"
  value       = aws_acm_certificate_validation.wildcard.validation_record_fqdns
}

output "expiration_alarm_arn" {
  description = "ARN of the certificate expiration CloudWatch alarm"
  value       = var.enable_expiration_alarm ? aws_cloudwatch_metric_alarm.certificate-expiration[0].arn : null
}
