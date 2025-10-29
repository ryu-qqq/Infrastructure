# ==============================================================================
# Basic WAF Example
# ==============================================================================
# This example demonstrates the simplest WAF configuration with:
# - OWASP Top 10 protection
# - Basic rate limiting
# - CloudWatch metrics
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# ==============================================================================
# Common Tags
# ==============================================================================

module "common_tags" {
  source = "../../../common-tags"

  environment = "dev"
  service     = "example-api"
  team        = "platform-team"
  owner       = "fbtkdals2@naver.com"
  cost_center = "engineering"
}

# ==============================================================================
# WAF Configuration
# ==============================================================================

module "waf" {
  source = "../../"

  name  = "dev-example-api-waf"
  scope = "REGIONAL" # REGIONAL for ALB/API Gateway

  # Enable OWASP Top 10 protection
  enable_owasp_rules = true

  # Enable basic rate limiting (2000 requests per 5 minutes per IP)
  enable_rate_limiting = true
  rate_limit           = 2000

  # Enable IP reputation filtering
  enable_ip_reputation = true

  # CloudWatch metrics
  enable_cloudwatch_metrics = true
  sampled_requests_enabled  = true

  # Standard tags
  common_tags = module.common_tags.tags
}

# ==============================================================================
# Outputs
# ==============================================================================

output "web_acl_arn" {
  description = "ARN of the WAF WebACL"
  value       = module.waf.web_acl_arn
}

output "web_acl_id" {
  description = "ID of the WAF WebACL"
  value       = module.waf.web_acl_id
}

output "cloudwatch_metric_name" {
  description = "CloudWatch metric name"
  value       = module.waf.cloudwatch_metric_name
}

output "enabled_features" {
  description = "Summary of enabled WAF features"
  value       = module.waf.enabled_features
}
