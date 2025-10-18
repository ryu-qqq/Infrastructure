# Outputs for Route53 Record Module

output "name" {
  description = "The name of the DNS record"
  value       = aws_route53_record.this.name
}

output "fqdn" {
  description = "The fully qualified domain name of the record"
  value       = aws_route53_record.this.fqdn
}

output "type" {
  description = "The type of the DNS record"
  value       = aws_route53_record.this.type
}

output "records" {
  description = "The values of the DNS record"
  value       = aws_route53_record.this.records
}
