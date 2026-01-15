# Variables for CloudFront www Redirect

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "source_domain" {
  description = "Source domain to redirect from (apex domain)"
  type        = string
  default     = "set-of.com"
}

variable "target_domain" {
  description = "Target domain to redirect to (www subdomain)"
  type        = string
  default     = "www.set-of.com"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"
}
