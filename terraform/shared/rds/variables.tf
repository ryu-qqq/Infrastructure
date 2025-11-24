# ============================================================================
# Project Configuration
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_identifier" {
  description = "Database instance identifier"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = null
}

variable "engine" {
  description = "Database engine (mysql, postgres)"
  type        = string
  default     = "mysql"

  validation {
    condition     = contains(["mysql", "postgres"], var.engine)
    error_message = "Engine must be mysql or postgres."
  }
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0.42"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 300
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 400
}

variable "storage_type" {
  description = "Storage type (gp3, gp2, io1)"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "gp2", "io1"], var.storage_type)
    error_message = "Storage type must be gp3, gp2, or io1."
  }
}

variable "iops" {
  description = "IOPS for storage (required for io1, optional for gp3)"
  type        = number
  default     = 3000
}

variable "storage_throughput" {
  description = "Storage throughput in MB/s (gp3 only)"
  type        = number
  default     = 125
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (optional, uses default if not specified)"
  type        = string
  default     = null
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "vpc_id" {
  description = "VPC ID (can use data source or SSM parameter)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for DB subnet group (private subnets recommended)"
  type        = list(string)
}

variable "publicly_accessible" {
  description = "Make database publicly accessible"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the database"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to access the database"
  type        = list(string)
  default     = []
}

# ============================================================================
# High Availability and Backup
# ============================================================================

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Backup retention period in days (0-35)"
  type        = number
  default     = 14

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

# ============================================================================
# Monitoring
# ============================================================================

variable "enabled_cloudwatch_logs_exports" {
  description = "CloudWatch log types to export"
  type        = list(string)
  default     = ["error", "general", "slowquery"]
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days (7, 731)"
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 731], var.performance_insights_retention_period)
    error_message = "Performance Insights retention must be 7 or 731 days."
  }
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60."
  }
}

# ============================================================================
# Database Parameters
# ============================================================================

variable "parameter_group_family" {
  description = "Database parameter group family"
  type        = string
  default     = "mysql8.0"
}

variable "parameters" {
  description = "Database parameters"
  type = list(object({
    name         = string
    value        = string
    apply_method = string
  }))
  default = []
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
  description = "Cost center for billing"
  type        = string
}

variable "data_class" {
  description = "Data classification (public, internal, confidential, sensitive)"
  type        = string

  validation {
    condition     = contains(["public", "internal", "confidential", "sensitive"], var.data_class)
    error_message = "Data class must be public, internal, confidential, or sensitive."
  }
}

variable "resource_lifecycle" {
  description = "Resource lifecycle stage"
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.resource_lifecycle)
    error_message = "Resource lifecycle must be development, staging, or production."
  }
}
