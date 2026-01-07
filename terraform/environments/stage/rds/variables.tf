# ============================================================================
# General Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "staging"
}

# ============================================================================
# Tagging Configuration (Required for modules)
# ============================================================================

variable "service_name" {
  description = "Service name (kebab-case, e.g., shared-database)"
  type        = string
  default     = "shared-database"

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
  default     = "engineering"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "project" {
  description = "Project name this resource belongs to"
  type        = string
  default     = "shared-infrastructure"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project))
    error_message = "Project must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "data_class" {
  description = "Data classification level (confidential, internal, public)"
  type        = string
  default     = "internal" # Stage uses internal, not confidential

  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS subnet group (minimum 2 for Multi-AZ)"
  type        = list(string)
}

# ============================================================================
# Security Configuration
# ============================================================================

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to access RDS (e.g., ECS task security groups)"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access RDS"
  type        = list(string)
  default     = []
}

# ============================================================================
# RDS Configuration
# ============================================================================

variable "identifier" {
  description = "RDS instance identifier"
  type        = string
  default     = "shared-mysql"
}

variable "mysql_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0.35"
}

variable "instance_class" {
  description = "RDS instance class (e.g., db.t4g.micro, db.t4g.small)"
  type        = string
  default     = "db.t4g.micro" # Smaller instance for staging
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20 # Smaller storage for staging
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 100 # Smaller max for staging
}

variable "storage_type" {
  description = "Storage type (gp3, gp2, io1)"
  type        = string
  default     = "gp3"
}

variable "iops" {
  description = "IOPS for io1 storage type"
  type        = number
  default     = null
}

# ============================================================================
# Snapshot Restore Configuration (for Monthly Refresh)
# ============================================================================

variable "snapshot_identifier" {
  description = "Snapshot identifier to restore from. Set to null for fresh DB or specify prod snapshot ARN/ID for restore."
  type        = string
  default     = null
}

variable "restore_from_snapshot" {
  description = "Whether to restore from a snapshot. When true, snapshot_identifier must be provided."
  type        = bool
  default     = false
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "database_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "shared_db"
}

variable "master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "admin"
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 3306
}

# ============================================================================
# High Availability Configuration
# ============================================================================

variable "enable_multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false # Disabled for staging to reduce cost
}

# ============================================================================
# Backup Configuration
# ============================================================================

variable "backup_retention_period" {
  description = "Number of days to retain backups (0-35)"
  type        = number
  default     = 7 # Shorter retention for staging
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

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying RDS instance"
  type        = bool
  default     = true # Allow easy teardown for staging
}

variable "final_snapshot_identifier" {
  description = "Name of final snapshot (if skip_final_snapshot is false)"
  type        = string
  default     = null
}

variable "copy_tags_to_snapshot" {
  description = "Copy tags to snapshots"
  type        = bool
  default     = true
}

# ============================================================================
# Monitoring Configuration
# ============================================================================

variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true # Keep for debugging in staging
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days (7, 731)"
  type        = number
  default     = 7
}

variable "enable_enhanced_monitoring" {
  description = "Enable Enhanced Monitoring"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch (error, general, slowquery)"
  type        = list(string)
  default     = ["error", "slowquery"] # Reduced logs for staging
}

# ============================================================================
# Security Configuration
# ============================================================================

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false # Disabled for staging - allows easy refresh
}

variable "publicly_accessible" {
  description = "Make RDS instance publicly accessible"
  type        = bool
  default     = false
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM Database authentication"
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

# ============================================================================
# Parameter Group Configuration
# ============================================================================

variable "parameter_group_family" {
  description = "RDS parameter group family"
  type        = string
  default     = "mysql8.0"
}

variable "parameters" {
  description = "List of DB parameters to apply"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "collation_server"
      value = "utf8mb4_unicode_ci"
    },
    {
      name  = "max_connections"
      value = "100" # Reduced for staging
    },
    {
      name  = "innodb_buffer_pool_size"
      value = "{DBInstanceClassMemory*3/4}"
    },
    {
      name  = "slow_query_log"
      value = "1"
    },
    {
      name  = "long_query_time"
      value = "2"
    },
    {
      name  = "log_queries_not_using_indexes"
      value = "1"
    }
  ]
}

# ============================================================================
# Alarm Configuration
# ============================================================================

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for RDS"
  type        = bool
  default     = false # Disabled for staging by default
}

variable "cpu_utilization_threshold" {
  description = "CPU utilization threshold for alarm (%)"
  type        = number
  default     = 80
}

variable "free_storage_threshold" {
  description = "Free storage space threshold for alarm (bytes)"
  type        = number
  default     = 5368709120 # 5GB in bytes
}

variable "freeable_memory_threshold" {
  description = "Freeable memory threshold for alarm (bytes)"
  type        = number
  default     = 268435456 # 256MB in bytes
}

variable "database_connections_threshold" {
  description = "Database connections threshold for alarm"
  type        = number
  default     = 90 # 90% of max_connections (100)
}

# ============================================================================
# Secrets Rotation Configuration
# ============================================================================

variable "enable_secrets_rotation" {
  description = "Enable automatic rotation for RDS master password"
  type        = bool
  default     = false # Disabled for staging
}

variable "rotation_days" {
  description = "Number of days between automatic password rotations"
  type        = number
  default     = 30
  validation {
    condition     = var.rotation_days >= 1 && var.rotation_days <= 365
    error_message = "Rotation days must be between 1 and 365."
  }
}

# ============================================================================
# Tags
# ============================================================================

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# RDS Proxy Configuration
# ============================================================================

variable "enable_rds_proxy" {
  description = "Enable RDS Proxy for connection pooling"
  type        = bool
  default     = false # Disabled for staging
}
