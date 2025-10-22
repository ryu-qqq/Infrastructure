# Variables for Atlantis Basic Example

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "atlantis_version" {
  description = "Atlantis version to deploy"
  type        = string
  default     = "v0.30.0"
}

variable "github_repo_allowlist" {
  description = "GitHub repository allowlist for Atlantis (e.g., github.com/yourorg/*)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

# Required Tags (Governance Standard)
variable "owner" {
  description = "Team or individual responsible for the resource"
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

variable "resource_lifecycle" {
  description = "Resource lifecycle (permanent, temporary, ephemeral)"
  type        = string
  default     = "temporary"
}

variable "data_class" {
  description = "Data classification (public, internal, confidential, restricted)"
  type        = string
  default     = "confidential"
}

variable "service" {
  description = "Service name this resource belongs to"
  type        = string
  default     = "atlantis"
}
