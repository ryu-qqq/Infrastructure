# Route53 Hosted Zone for set-of.com
#
# IMPORTANT: This hosted zone already exists in AWS Console.
# To import the existing zone, use:
# terraform import aws_route53_zone.primary <ZONE_ID>
#
# Find your zone ID with: aws route53 list-hosted-zones | grep set-of.com

resource "aws_route53_zone" "primary" {
  name    = local.domain_config.domain_name
  comment = local.domain_config.comment

  # Prevent accidental deletion of the zone
  force_destroy = local.domain_config.force_destroy

  tags = merge(
    local.required_tags,
    {
      Name      = "route53-${var.domain_name}"
      Domain    = var.domain_name
      Component = "hosted-zone"
    },
    var.additional_tags
  )

  # Lifecycle block to handle existing resources
  lifecycle {
    # Prevent replacement of the zone after import
    prevent_destroy = true
  }
}

# Query Logging Configuration
# Logs all DNS queries to CloudWatch Logs for monitoring and analysis
resource "aws_route53_query_log" "primary" {
  count = var.enable_query_logging ? 1 : 0

  zone_id                  = aws_route53_zone.primary.zone_id
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53-query-logs[0].arn

  depends_on = [aws_cloudwatch_log_group.route53-query-logs]
}

# KMS Key Policy Document for CloudWatch Logs
data "aws_iam_policy_document" "route53-logs-kms" {
  count = var.enable_query_logging ? 1 : 0

  # Enable IAM User Permissions
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow CloudWatch Logs Service
  statement {
    sid    = "Allow CloudWatch Logs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/route53/*"]
    }
  }
}

# KMS Key for CloudWatch Logs Encryption
resource "aws_kms_key" "route53-logs" {
  count = var.enable_query_logging ? 1 : 0

  description             = local.kms_config.description
  deletion_window_in_days = local.kms_config.deletion_window_in_days
  enable_key_rotation     = local.kms_config.enable_key_rotation
  policy                  = data.aws_iam_policy_document.route53-logs-kms[0].json

  tags = merge(
    local.required_tags,
    {
      Name      = "route53-logs-encryption"
      Component = "kms"
    }
  )
}

resource "aws_kms_alias" "route53-logs" {
  count = var.enable_query_logging ? 1 : 0

  name          = "alias/route53-logs"
  target_key_id = aws_kms_key.route53-logs[0].key_id
}

# CloudWatch Log Group for Query Logs
resource "aws_cloudwatch_log_group" "route53-query-logs" {
  count = var.enable_query_logging ? 1 : 0

  name              = local.log_config.log_group_name
  retention_in_days = local.log_config.retention_in_days
  kms_key_id        = aws_kms_key.route53-logs[0].arn

  tags = merge(
    local.required_tags,
    {
      Name      = "route53-query-logs-${var.domain_name}"
      Component = "dns-logging"
    }
  )

  depends_on = [aws_kms_key.route53-logs]
}

# Health Check for Atlantis Server
# Monitors the availability of atlantis.set-of.com
resource "aws_route53_health_check" "atlantis" {
  fqdn              = local.health_check_config.atlantis.fqdn
  port              = local.health_check_config.atlantis.port
  type              = local.health_check_config.atlantis.type
  resource_path     = local.health_check_config.atlantis.resource_path
  failure_threshold = local.health_check_config.atlantis.failure_threshold
  request_interval  = local.health_check_config.atlantis.request_interval

  # SNS topic for health check alarms (optional, can be added later)
  # cloudwatch_alarm_name   = aws_cloudwatch_metric_alarm.atlantis_health.alarm_name
  # cloudwatch_alarm_region = var.aws_region

  tags = merge(
    local.required_tags,
    {
      Name      = "healthcheck-atlantis-${var.domain_name}"
      Component = "health-monitoring"
      Endpoint  = local.health_check_config.atlantis.fqdn
    }
  )
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# ==============================================================================
# SSM Parameter Store Exports (for cross-stack references)
# ==============================================================================

# Export Hosted Zone ID for other stacks (e.g., ACM certificate validation)
resource "aws_ssm_parameter" "hosted-zone-id" {
  name        = "/shared/route53/hosted-zone-id"
  description = "Route53 Hosted Zone ID for ${var.domain_name}"
  type        = "String"
  value       = aws_route53_zone.primary.zone_id

  tags = merge(
    local.required_tags,
    {
      Name      = "ssm-route53-zone-id"
      Component = "parameter-store"
      Export    = "hosted-zone-id"
    }
  )
}

# DNS Records Management
# Note: Existing DNS records should be imported or managed separately
# Use the route53-record module for adding new records

# Example A Record for Atlantis (will be managed via ALB in atlantis module)
# resource "aws_route53_record" "atlantis" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = "atlantis.${var.domain_name}"
#   type    = "A"
#
#   alias {
#     name                   = var.atlantis_alb_dns_name
#     zone_id                = var.atlantis_alb_zone_id
#     evaluate_target_health = true
#   }
# }
