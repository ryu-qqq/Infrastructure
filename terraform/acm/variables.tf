# Variables for ACM Certificate Management

variable "aws_region" {
  description = "AWS region for ACM certificate (must be us-east-1 for CloudFront)"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Primary domain name for the certificate"
  type        = string
  default     = "set-of.com"
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID for DNS validation. If not provided, will lookup by domain_name (requires Route53:ListHostedZones permission)"
  type        = string
  default     = ""
}

variable "enable_expiration_alarm" {
  description = "Enable CloudWatch alarm for certificate expiration monitoring"
  type        = bool
  default     = true
}

# ==============================================================================
# Tagging Variables (for common-tags module)
# ==============================================================================

variable "service" {
  description = "Service name for tagging"
  type        = string
  default     = "certificate-management"
}

variable "team" {
  description = "Team responsible for the resources"
  type        = string
  default     = "platform-team"
}

variable "owner" {
  description = "Owner email or identifier"
  type        = string
  default     = "fbtkdals2@naver.com"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "infrastructure"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
