# Outputs for Route53 Infrastructure

output "hosted_zone_id" {
  description = "The Hosted Zone ID for set-of.com"
  value       = aws_route53_zone.primary.zone_id
}

output "hosted_zone_name" {
  description = "The Hosted Zone name"
  value       = aws_route53_zone.primary.name
}

output "name_servers" {
  description = "The name servers for the hosted zone"
  value       = aws_route53_zone.primary.name_servers
}

output "zone_arn" {
  description = "The ARN of the hosted zone"
  value       = aws_route53_zone.primary.arn
}

output "atlantis_health_check_id" {
  description = "The ID of the Atlantis health check"
  value       = aws_route53_health_check.atlantis.id
}

output "query_log_group_name" {
  description = "The CloudWatch Log Group name for query logs"
  value       = var.enable_query_logging ? aws_cloudwatch_log_group.route53_query_logs[0].name : null
}

output "query_log_group_arn" {
  description = "The CloudWatch Log Group ARN for query logs"
  value       = var.enable_query_logging ? aws_cloudwatch_log_group.route53_query_logs[0].arn : null
}
