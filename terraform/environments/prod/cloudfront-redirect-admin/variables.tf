# Variables for Admin Server API Proxy

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
  description = "Source domain to proxy"
  type        = string
  default     = "admin-server.set-of.net"
}

variable "gateway_alb_domain" {
  description = "Gateway ALB domain name"
  type        = string
  default     = "gateway-alb-prod-1837698569.ap-northeast-2.elb.amazonaws.com"
}

variable "cors_response_headers_policy_id" {
  description = "CloudFront Response Headers Policy ID for CORS"
  type        = string
  default     = "fd37cd93-5c19-475d-a9be-1edbe3ea0e8d" # Custom CORS policy from set-of.com
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200" # Asia, Europe, North America
}
