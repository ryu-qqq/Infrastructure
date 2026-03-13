# ========================================
# Outputs
# ========================================

# Stage CloudFront Distribution
output "stage_distribution_id" {
  description = "CloudFront distribution ID for staging (stage.set-of.com)"
  value       = aws_cloudfront_distribution.stage.id
}

output "stage_distribution_domain_name" {
  description = "CloudFront domain name for staging"
  value       = aws_cloudfront_distribution.stage.domain_name
}

# Admin Stage CloudFront Distribution
output "admin_stage_distribution_id" {
  description = "CloudFront distribution ID for stage admin (stage-admin.set-of.com)"
  value       = aws_cloudfront_distribution.admin_stage.id
}

output "admin_stage_distribution_domain_name" {
  description = "CloudFront domain name for stage admin"
  value       = aws_cloudfront_distribution.admin_stage.domain_name
}

# Route53 Records
output "route53_records" {
  description = "Route53 records managed by this module"
  value = {
    stage       = aws_route53_record.stage.fqdn
    admin_stage = aws_route53_record.admin_stage.fqdn
  }
}

# CDN Stage CloudFront Distribution
output "cdn_stage_distribution_id" {
  description = "CloudFront distribution ID for stage CDN (stage-cdn.set-of.com)"
  value       = aws_cloudfront_distribution.cdn_stage.id
}

output "cdn_stage_distribution_domain_name" {
  description = "CloudFront domain name for stage CDN"
  value       = aws_cloudfront_distribution.cdn_stage.domain_name
}

# Routing Summary
output "routing_summary" {
  description = "Summary of CloudFront path-based routing configuration"
  value = {
    staging = {
      domains         = ["stage.set-of.com"]
      default_origin  = "Frontend ALB (Next.js)"
      api_path        = "/api/v1/* → Gateway ALB"
      frontend_origin = data.aws_lb.frontend.dns_name
      gateway_origin  = data.aws_lb.gateway.dns_name
    }
    admin_staging = {
      domains        = ["stage-admin.set-of.com"]
      default_origin = "Gateway ALB (Strangler Fig Pattern)"
      gateway_origin = data.aws_lb.gateway.dns_name
    }
    cdn_staging = {
      domains        = ["stage-cdn.set-of.com"]
      default_origin = "S3 stage-connectly"
      paths = {
        default     = "/* → stage-connectly S3"
        otel_config = "/otel-config/* → stage-connectly S3"
        public      = "/public/* → fileflow-uploads-stage S3"
        internal    = "/internal/* → fileflow-uploads-stage S3 (Signed URL)"
      }
    }
  }
}
