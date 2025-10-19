# AWS 리전
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# 환경
variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# 서비스 이름
variable "service_name" {
  description = "서비스 이름 (리소스 명명에 사용)"
  type        = string
  default     = "microservices"
}

# VPC ID
variable "vpc_id" {
  description = "ALB가 배포될 VPC ID"
  type        = string
}

# ACM 인증서
variable "certificate_arn" {
  description = "ACM 인증서 ARN (HTTPS 리스너용, null이면 HTTPS 리스너 생성 안 함)"
  type        = string
  default     = null
}
