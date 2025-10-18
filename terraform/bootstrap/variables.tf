variable "aws_region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (prod, dev, staging)"
  type        = string
  default     = "prod"
}

variable "tfstate_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "prod-connectly"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "prod-connectly-tf-lock"
}

variable "service" {
  description = "Service name"
  type        = string
  default     = "terraform-backend"
}

variable "owner" {
  description = "Owner email"
  type        = string
  default     = "platform@ryuqqq.com"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "infrastructure"
}
