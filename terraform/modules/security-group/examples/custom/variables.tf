variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "database_sg_id" {
  description = "Database security group ID for custom ingress rule example"
  type        = string
  default     = "sg-12345678" # 예제용 기본값
}
