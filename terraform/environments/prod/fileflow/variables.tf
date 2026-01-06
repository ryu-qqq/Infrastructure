variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "646886795421"
}

variable "role_name" {
  description = "IAM role name"
  type        = string
  default     = "atlantis-ecs-task-prod"
}