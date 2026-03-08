# Variables for Stage CloudFront

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "stage"
}

variable "domain_name" {
  description = "Domain name for CloudFront"
  type        = string
  default     = "stage-cdn.set-of.com"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200" # Asia, Europe, North America
}
