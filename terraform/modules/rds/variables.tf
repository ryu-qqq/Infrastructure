# --- Required Variables ---

# --- Required Variables (Tagging) ---

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "service_name" {
  description = "Service name (kebab-case, e.g., api-server, web-app)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "team" {
  description = "Team responsible for the resource (kebab-case, e.g., platform-team)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

variable "owner" {
  description = "Email or identifier of the resource owner"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner)) || can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.owner))
    error_message = "Owner must be a valid email address or kebab-case identifier."
  }
}

variable "cost_center" {
  description = "Cost center for billing and financial tracking (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case (lowercase letters, numbers, hyphens only)."
  }
}

# --- Optional Variables (Tagging) ---

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

variable "additional_tags" {
  description = "Additional tags to merge with common tags"
  type        = map(string)
  default     = {}
}

# --- Required Variables (RDS Configuration) ---

variable "db_name" {
  description = "The name of the database to create when the DB instance is created. If this parameter is not specified, no database is created. Must begin with a letter and contain only alphanumeric characters"
  type        = string
  default     = null

  validation {
    condition     = var.db_name == null || can(regex("^[a-zA-Z][a-zA-Z0-9]*$", var.db_name))
    error_message = "Database name must begin with a letter and contain only alphanumeric characters"
  }
}

variable "engine" {
  description = "The database engine to use (e.g., mysql, postgres, mariadb, oracle-se2, sqlserver-ex)"
  type        = string

  validation {
    condition     = contains(["mysql", "postgres", "mariadb", "oracle-se2", "oracle-se", "oracle-ee", "sqlserver-ex", "sqlserver-web", "sqlserver-se", "sqlserver-ee"], var.engine)
    error_message = "Engine must be one of: mysql, postgres, mariadb, oracle-se2, oracle-se, oracle-ee, sqlserver-ex, sqlserver-web, sqlserver-se, sqlserver-ee"
  }
}

variable "engine_version" {
  description = "The engine version to use (e.g., '8.0.35' for MySQL, '15.4' for PostgreSQL)"
  type        = string
}

variable "identifier" {
  description = "The name of the RDS instance (must be unique, contain only lowercase letters, numbers, and hyphens)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.identifier))
    error_message = "Identifier must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "instance_class" {
  description = "The instance type of the RDS instance (e.g., db.t3.micro, db.t3.small, db.r5.large)"
  type        = string

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.instance_class))
    error_message = "Instance class must be a valid RDS instance type (e.g., db.t3.micro, db.r5.large)"
  }
}

variable "master_username" {
  description = "Username for the master DB user. Cannot be 'admin' for MySQL, 'postgres' for PostgreSQL"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.master_username))
    error_message = "Master username must begin with a letter and contain only alphanumeric characters and underscores"
  }

  validation {
    condition     = !contains(["admin", "postgres", "root", "rdsadmin"], var.master_username)
    error_message = "Master username cannot be 'admin', 'postgres', 'root', or 'rdsadmin'"
  }
}

variable "master_password" {
  description = "Password for the master DB user. Must be at least 8 characters"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.master_password) >= 8
    error_message = "Master password must be at least 8 characters long"
  }
}

variable "security_group_ids" {
  description = "List of VPC security group IDs to associate with the DB instance"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group (must be in at least two different availability zones)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs are required for high availability"
  }
}

# Optional Variables - Storage Configuration

variable "allocated_storage" {
  description = "The allocated storage in gibibytes (GiB). Must be between 20 and 65536 for most engines"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GiB"
  }
}

variable "max_allocated_storage" {
  description = "The upper limit for storage autoscaling in GiB. Set to 0 to disable storage autoscaling"
  type        = number
  default     = 100

  validation {
    condition     = var.max_allocated_storage == 0 || (var.max_allocated_storage > 0 && var.max_allocated_storage <= 65536)
    error_message = "Max allocated storage must be 0 (disabled) or between 1 and 65536 GiB"
  }
}

variable "storage_type" {
  description = "The storage type: gp2 (General Purpose SSD), gp3 (General Purpose SSD), io1 (Provisioned IOPS SSD), or standard (Magnetic)"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "standard"], var.storage_type)
    error_message = "Storage type must be one of: gp2, gp3, io1, io2, standard"
  }
}

variable "iops" {
  description = "The amount of provisioned IOPS. Required if storage_type is io1 or io2"
  type        = number
  default     = null
}

variable "storage_throughput" {
  description = "The storage throughput value for gp3 storage type (125-1000 MiB/s)"
  type        = number
  default     = null

  validation {
    condition     = var.storage_throughput == null ? true : (var.storage_throughput >= 125 && var.storage_throughput <= 1000)
    error_message = "Storage throughput must be between 125 and 1000 MiB/s for gp3 storage"
  }
}

# Optional Variables - Backup Configuration

variable "backup_retention_period" {
  description = "The days to retain backups. Must be between 0 and 35. 0 means disable automated backups"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days"
  }
}

variable "backup_window" {
  description = "The daily time range during which automated backups are created (UTC, format: HH:MM-HH:MM, e.g., '03:00-04:00')"
  type        = string
  default     = "03:00-04:00"

  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]-([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.backup_window))
    error_message = "Backup window must be in format HH:MM-HH:MM (e.g., 03:00-04:00)"
  }
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted. If true, no snapshot is created"
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "The name of the final DB snapshot when this DB instance is deleted. Required if skip_final_snapshot is false"
  type        = string
  default     = null
}

variable "copy_tags_to_snapshot" {
  description = "Copy all instance tags to snapshots"
  type        = bool
  default     = true
}

# Optional Variables - Encryption Configuration

variable "storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key. If not specified, the default KMS key for RDS is used"
  type        = string
  default     = null
}

# Optional Variables - Maintenance and Updates

variable "auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically during the maintenance window"
  type        = bool
  default     = true
}

variable "maintenance_window" {
  description = "The window to perform maintenance (UTC, format: ddd:HH:MM-ddd:HH:MM, e.g., 'sun:04:00-sun:05:00')"
  type        = string
  default     = "sun:04:00-sun:05:00"

  validation {
    condition     = can(regex("^(mon|tue|wed|thu|fri|sat|sun):([0-1][0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window))
    error_message = "Maintenance window must be in format ddd:HH:MM-ddd:HH:MM (e.g., sun:04:00-sun:05:00)"
  }
}

# Optional Variables - High Availability

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ for high availability"
  type        = bool
  default     = false
}

# Optional Variables - Performance and Monitoring

variable "performance_insights_enabled" {
  description = "Enable Performance Insights for the DB instance"
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "The number of days to retain Performance Insights data (7, 731)"
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 731], var.performance_insights_retention_period)
    error_message = "Performance Insights retention period must be 7 or 731 days"
  }
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to enable for exporting to CloudWatch logs (e.g., ['error', 'general', 'slowquery'] for MySQL)"
  type        = list(string)
  default     = []
}

variable "monitoring_interval" {
  description = "The interval, in seconds, between points when Enhanced Monitoring metrics are collected (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be one of: 0, 1, 5, 10, 15, 30, 60"
  }
}

variable "monitoring_role_arn" {
  description = "The ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs. Required if monitoring_interval > 0"
  type        = string
  default     = null
}

# Optional Variables - Parameter Group

variable "parameter_group_family" {
  description = "The family of the DB parameter group (e.g., 'mysql8.0', 'postgres15'). If not specified, a parameter group will not be created"
  type        = string
  default     = null
}

variable "parameters" {
  description = "A list of DB parameters to apply. Only used if parameter_group_family is specified"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Optional Variables - Network Configuration

variable "publicly_accessible" {
  description = "Bool to control if instance is publicly accessible"
  type        = bool
  default     = false
}

variable "port" {
  description = "The port on which the DB accepts connections. If not specified, uses the default port for the engine"
  type        = number
  default     = null

  validation {
    condition     = var.port == null || (var.port > 0 && var.port < 65536)
    error_message = "Port must be between 1 and 65535"
  }
}

# Optional Variables - Deletion Protection

variable "deletion_protection" {
  description = "If true, the database cannot be deleted"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Specifies whether any database modifications are applied immediately, or during the next maintenance window"
  type        = bool
  default     = false
}
