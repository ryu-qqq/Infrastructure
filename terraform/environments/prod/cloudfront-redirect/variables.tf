# Variables for CloudFront Redirect

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "source_domain" {
  description = "Source domain to redirect from"
  type        = string
  default     = "server.set-of.net"
}

variable "target_domain" {
  description = "Target domain to redirect to"
  type        = string
  default     = "www.set-of.com"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200" # Asia, Europe, North America
}
