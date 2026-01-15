# Environment Configuration
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# Governance Tags
variable "team" {
  description = "Team responsible for this resource"
  type        = string
  default     = "platform-team"
}

variable "owner" {
  description = "Owner email"
  type        = string
  default     = "platform@ryuqqq.com"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

variable "service_name" {
  description = "Service name"
  type        = string
  default     = "iam-developers"
}

# Developer Configuration
variable "developer_username" {
  description = "IAM username for the developer"
  type        = string
  default     = "frontend-developer"
}

variable "developer_email" {
  description = "Developer email for identification"
  type        = string
  default     = "frontend@ryuqqq.com"
}
