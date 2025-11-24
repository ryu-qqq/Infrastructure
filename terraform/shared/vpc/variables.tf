# ============================================================================
# AWS Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region for VPC resources"
  type        = string
  default     = "ap-northeast-2"
}

# ============================================================================
# VPC Configuration
# ============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block (recommended: /16 for large projects, /20 for small)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability zones for subnets (minimum 2 for high availability)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets required for high availability."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.128.0/19", "10.0.160.0/19"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets required for high availability."
  }
}

# ============================================================================
# Governance Tags (Required)
# ============================================================================

variable "owner" {
  description = "Email address of the infrastructure owner"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner))
    error_message = "Owner must be a valid email address."
  }
}

variable "cost_center" {
  description = "Cost center for billing and cost allocation"
  type        = string
  default     = "engineering"
}

variable "data_class" {
  description = "Data classification (public, internal, confidential, restricted)"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_class)
    error_message = "Data class must be public, internal, confidential, or restricted."
  }
}

variable "resource_lifecycle" {
  description = "Resource lifecycle stage (temporary, development, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["temporary", "development", "production"], var.resource_lifecycle)
    error_message = "Lifecycle must be temporary, development, or production."
  }
}

# ============================================================================
# Optional Features
# ============================================================================

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all AZs (cost optimization, not HA)"
  type        = bool
  default     = false
}
