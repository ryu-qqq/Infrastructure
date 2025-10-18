# Variables for Route53 Infrastructure

variable "aws_region" {
  description = "AWS region for Route53 resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Primary domain name for the hosted zone"
  type        = string
  default     = "set-of.com"
}

variable "enable_dnssec" {
  description = "Enable DNSSEC for the hosted zone"
  type        = bool
  default     = false
}

variable "enable_query_logging" {
  description = "Enable query logging for the hosted zone"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
