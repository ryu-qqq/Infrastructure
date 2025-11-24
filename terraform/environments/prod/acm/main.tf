# ACM Certificate Management
#
# This module manages SSL/TLS certificates for the domain using AWS Certificate Manager.
# Certificates are automatically validated via DNS and auto-renewed by AWS.

# ==============================================================================
# ACM Certificate
# ==============================================================================

# Primary wildcard certificate for the domain
# This certificate covers *.set-of.com and set-of.com
resource "aws_acm_certificate" "wildcard" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  # Certificate lifecycle configuration
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.required_tags,
    var.additional_tags,
    {
      Name      = "acm-wildcard-${var.domain_name}"
      Component = "acm"
      Domain    = var.domain_name
      Type      = "wildcard"
    }
  )
}

# Automatic DNS validation using Route53
# Creates DNS records required for certificate validation
resource "aws_route53_record" "certificate-validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.route53_zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate-validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

# CloudWatch Alarm for Certificate Expiration
# AWS ACM automatically renews certificates, but this alarm monitors the renewal process
resource "aws_cloudwatch_metric_alarm" "certificate-expiration" {
  count = var.enable_expiration_alarm ? 1 : 0

  alarm_name          = "acm-certificate-expiration-${var.domain_name}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "days-to-expiry"
  namespace           = "AWS/CertificateManager"
  period              = 86400 # 1 day
  statistic           = "Minimum"
  threshold           = 30 # Alert when less than 30 days to expiry
  alarm_description   = "ACM certificate for ${var.domain_name} is expiring in less than 30 days"
  treat_missing_data  = "notBreaching"

  dimensions = {
    CertificateArn = aws_acm_certificate.wildcard.arn
  }

  tags = merge(
    local.required_tags,
    var.additional_tags,
    {
      Name      = "alarm-acm-expiration-${var.domain_name}"
      Component = "monitoring"
    }
  )
}

# ==============================================================================
# Route53 Zone ID Resolution (Cross-Stack Reference Pattern)
# ==============================================================================

# Lookup Route53 Hosted Zone ID from SSM Parameter Store
# This follows the project's cross-stack reference pattern and avoids
# requiring Route53:ListHostedZones permission for Atlantis
data "aws_ssm_parameter" "route53-zone-id" {
  count = var.route53_zone_id == "" ? 1 : 0
  name  = "/shared/route53/hosted-zone-id"
}
