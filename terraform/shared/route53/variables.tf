# ============================================================================
# Input Variables
# ============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
}

variable "comment" {
  description = "Comment for the hosted zone"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Whether to destroy all records in the zone when deleting"
  type        = bool
  default     = false
}

# Governance Tags
variable "owner" {
  description = "Owner email"
  type        = string
}

variable "cost_center" {
  description = "Cost center"
  type        = string
}

variable "data_class" {
  description = "Data classification"
  type        = string
  default     = "public"
}

variable "resource_lifecycle" {
  description = "Resource lifecycle"
  type        = string
  default     = "production"
}
