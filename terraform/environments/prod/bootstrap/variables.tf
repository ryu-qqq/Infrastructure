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
  default     = "fbtkdals2@naver.com"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "infrastructure"
}

variable "team" {
  description = "Team responsible for the resource"
  type        = string
  default     = "platform-team"
}

variable "project" {
  description = "Project name this resource belongs to"
  type        = string
  default     = "infrastructure"
}

variable "data_class" {
  description = "Data classification level (confidential, internal, public)"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

variable "resource_lifecycle" {
  description = "Resource lifecycle (temporary, permanent)"
  type        = string
  default     = "permanent"

  validation {
    condition     = contains(["temporary", "permanent"], var.resource_lifecycle)
    error_message = "Lifecycle must be one of: temporary, permanent."
  }
}

# GitHub Actions 허용 프로젝트 목록
variable "allowed_github_repos" {
  description = "List of GitHub repositories allowed to assume the GitHub Actions role"
  type        = list(string)
  default = [
    "Infrastructure",
    "fileflow",
    "CrawlingHub",
    "AuthHub"
  ]
}
