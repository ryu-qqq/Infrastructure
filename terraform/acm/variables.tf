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

variable "enable_expiration_alarm" {
  description = "Enable CloudWatch alarm for certificate expiration monitoring"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
