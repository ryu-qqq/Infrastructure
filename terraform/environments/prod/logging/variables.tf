# Central Logging System Variables

# ============================================================================
# General Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region for CloudWatch Logs"
  type        = string
  default     = "ap-northeast-2"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
  default     = "prod-connectly"
}

# ============================================================================
# Required Tag Variables (following modules v1.0.0 pattern)
# ============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "service_name" {
  description = "Service name (kebab-case, e.g., logging, monitoring)"
  type        = string
  default     = "logging"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "team" {
  description = "Team responsible for the resource (kebab-case)"
  type        = string
  default     = "platform-team"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "owner" {
  description = "Email or identifier of the resource owner"
  type        = string
  default     = "fbtkdals2@naver.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner)) || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.owner))
    error_message = "Owner must be a valid email address or kebab-case identifier."
  }
}

variable "cost_center" {
  description = "Cost center for billing and financial tracking (kebab-case)"
  type        = string
  default     = "infrastructure"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

# ============================================================================
# Optional Tag Variables
# ============================================================================

variable "project" {
  description = "Project name this resource belongs to"
  type        = string
  default     = "infrastructure"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project))
    error_message = "Project must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "data_class" {
  description = "Data classification level (confidential, internal, public)"
  type        = string
  default     = "confidential"

  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

# ============================================================================
# Log Streaming Variables
# ============================================================================

variable "enable_log_streaming" {
  description = "Enable log streaming to OpenSearch"
  type        = bool
  default     = true
}

variable "opensearch_domain_name" {
  description = "Name of the existing OpenSearch domain"
  type        = string
  default     = "prod-obs-opensearch"
}

variable "opensearch_index_name" {
  description = "Index name prefix for logs in OpenSearch"
  type        = string
  default     = "logs"
}

variable "log_filter_pattern" {
  description = "CloudWatch Logs filter pattern (empty string = all logs)"
  type        = string
  default     = ""
}

variable "opensearch_index_prefix" {
  description = "Index name prefix for logs in OpenSearch (service name appended automatically)"
  type        = string
  default     = "logs"
}

# ============================================================================
# OpenSearch Domain Configuration
# ============================================================================

variable "opensearch_engine_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "OpenSearch_2.11"
}

variable "opensearch_kms_key_id" {
  description = "Existing KMS key ID for OpenSearch encryption (required, no default for security)"
  type        = string
  # No default - must be provided via tfvars or CLI
}

variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.medium.search" # Upgraded from t3.small.search (4GB RAM, JVM 2GB)
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
}

variable "opensearch_dedicated_master_enabled" {
  description = "Enable dedicated master nodes"
  type        = bool
  default     = false
}

variable "opensearch_zone_awareness_enabled" {
  description = "Enable zone awareness for high availability"
  type        = bool
  default     = false
}

variable "opensearch_availability_zone_count" {
  description = "Number of availability zones (requires zone_awareness_enabled)"
  type        = number
  default     = 2
}

variable "opensearch_volume_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp3"
}

variable "opensearch_volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 50 # Upgraded from 20GB
}

variable "opensearch_iops" {
  description = "IOPS for gp3 volumes"
  type        = number
  default     = 3000
}

variable "opensearch_throughput" {
  description = "Throughput in MiB/s for gp3 volumes"
  type        = number
  default     = 250
}

variable "opensearch_allowed_ips" {
  description = "List of IP addresses allowed to access OpenSearch (required, no default for security)"
  type        = list(string)
  # No default - must be provided via tfvars or CLI
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block for OpenSearch access"
  type        = string
  default     = "10.0.0.0/16"
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs for CloudWatch alarms"
  type        = list(string)
  default     = []
}
