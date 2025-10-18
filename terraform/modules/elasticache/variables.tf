# Required Variables

variable "common_tags" {
  description = "Common tags from common-tags module"
  type        = map(string)
}

variable "cluster_id" {
  description = "The cluster identifier (must be unique, lowercase letters, numbers, and hyphens only)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_id))
    error_message = "Cluster ID must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "engine" {
  description = "The name of the cache engine to be used (redis or memcached)"
  type        = string

  validation {
    condition     = contains(["redis", "memcached"], var.engine)
    error_message = "Engine must be either 'redis' or 'memcached'"
  }
}

variable "node_type" {
  description = "The instance class to use (e.g., cache.t3.micro, cache.r6g.large)"
  type        = string

  validation {
    condition     = can(regex("^cache\\.[a-z0-9]+\\.[a-z0-9]+$", var.node_type))
    error_message = "Node type must be a valid ElastiCache instance type (e.g., cache.t3.micro)"
  }
}

variable "subnet_ids" {
  description = "List of VPC subnet IDs for the cache subnet group"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "At least 1 subnet ID is required"
  }
}

variable "security_group_ids" {
  description = "List of security group IDs to allow access to the cluster"
  type        = list(string)
}

# Optional Variables - Engine Configuration

variable "engine_version" {
  description = "Version number of the cache engine (e.g., '7.0' for Redis, '1.6.6' for Memcached)"
  type        = string
  default     = null
}

variable "port" {
  description = "The port number on which the cache accepts connections (default: 6379 for Redis, 11211 for Memcached)"
  type        = number
  default     = null

  validation {
    condition     = var.port == null || (var.port > 0 && var.port < 65536)
    error_message = "Port must be between 1 and 65535"
  }
}

# Optional Variables - Cluster Configuration

variable "num_cache_nodes" {
  description = "The number of cache nodes (for Memcached clusters only, 1-40)"
  type        = number
  default     = 1

  validation {
    condition     = var.num_cache_nodes >= 1 && var.num_cache_nodes <= 40
    error_message = "Number of cache nodes must be between 1 and 40"
  }
}

variable "az_mode" {
  description = "Whether to enable Multi-AZ Support (cross-az or single-az). For Redis replication groups, use automatic_failover_enabled instead"
  type        = string
  default     = "single-az"

  validation {
    condition     = contains(["single-az", "cross-az"], var.az_mode)
    error_message = "AZ mode must be either 'single-az' or 'cross-az'"
  }
}

variable "preferred_availability_zones" {
  description = "List of EC2 availability zones for the cache cluster nodes (for Memcached only)"
  type        = list(string)
  default     = []
}

# Optional Variables - Redis Replication Group

variable "replication_group_id" {
  description = "The replication group identifier (for Redis clusters with replication). Must be different from cluster_id"
  type        = string
  default     = null

  validation {
    condition     = var.replication_group_id == null || can(regex("^[a-z0-9-]+$", var.replication_group_id))
    error_message = "Replication group ID must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "replication_group_description" {
  description = "User-created description for the replication group"
  type        = string
  default     = null
}

variable "num_node_groups" {
  description = "Number of node groups (shards) for this Redis replication group (1-500)"
  type        = number
  default     = 1

  validation {
    condition     = var.num_node_groups >= 1 && var.num_node_groups <= 500
    error_message = "Number of node groups must be between 1 and 500"
  }
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes in each node group (0-5)"
  type        = number
  default     = 1

  validation {
    condition     = var.replicas_per_node_group >= 0 && var.replicas_per_node_group <= 5
    error_message = "Replicas per node group must be between 0 and 5"
  }
}

variable "automatic_failover_enabled" {
  description = "Enable automatic failover for Redis replication groups (requires at least 2 nodes)"
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Enable Multi-AZ for Redis replication groups (requires automatic_failover_enabled)"
  type        = bool
  default     = false
}

# Optional Variables - Parameter Group

variable "parameter_group_family" {
  description = "The family of the ElastiCache parameter group (e.g., 'redis7', 'memcached1.6')"
  type        = string
  default     = null
}

variable "parameters" {
  description = "List of ElastiCache parameters to apply"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Optional Variables - Encryption and Security

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest (Redis only, requires Redis 3.2.6+ or 4.0.10+)"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit (Redis only)"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "Password used to access a password protected server (Redis only, requires transit_encryption_enabled)"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.auth_token == null || (length(var.auth_token) >= 16 && length(var.auth_token) <= 128)
    error_message = "Auth token must be between 16 and 128 characters"
  }
}

variable "kms_key_id" {
  description = "ARN of the KMS key to use for at-rest encryption (if not specified, uses AWS managed key)"
  type        = string
  default     = null
}

# Optional Variables - Maintenance and Backup

variable "snapshot_retention_limit" {
  description = "Number of days to retain automatic cache cluster snapshots (Redis only, 0-35)"
  type        = number
  default     = 7

  validation {
    condition     = var.snapshot_retention_limit >= 0 && var.snapshot_retention_limit <= 35
    error_message = "Snapshot retention limit must be between 0 and 35 days"
  }
}

variable "snapshot_window" {
  description = "Daily time range for snapshots (UTC, format: HH:MM-HH:MM, e.g., '03:00-04:00')"
  type        = string
  default     = "03:00-04:00"

  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]-([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.snapshot_window))
    error_message = "Snapshot window must be in format HH:MM-HH:MM (e.g., 03:00-04:00)"
  }
}

variable "maintenance_window" {
  description = "Weekly time range for maintenance (UTC, format: ddd:HH:MM-ddd:HH:MM, e.g., 'sun:04:00-sun:05:00')"
  type        = string
  default     = "sun:04:00-sun:05:00"

  validation {
    condition     = can(regex("^(mon|tue|wed|thu|fri|sat|sun):([0-1][0-9]|2[0-3]):[0-5][0-9]-(mon|tue|wed|thu|fri|sat|sun):([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window))
    error_message = "Maintenance window must be in format ddd:HH:MM-ddd:HH:MM (e.g., sun:04:00-sun:05:00)"
  }
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades during the maintenance window"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately instead of during the maintenance window"
  type        = bool
  default     = false
}

# Optional Variables - Notifications

variable "notification_topic_arn" {
  description = "ARN of an SNS topic to send ElastiCache notifications to"
  type        = string
  default     = null
}

# Optional Variables - Logging (Redis only)

variable "log_delivery_configuration" {
  description = "Log delivery configuration for Redis slow-log and engine-log"
  type = list(object({
    destination      = string
    destination_type = string
    log_format       = string
    log_type         = string
  }))
  default = []
}

# Optional Variables - CloudWatch Alarms

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for CPU, memory, and connections"
  type        = bool
  default     = true
}

variable "alarm_cpu_threshold" {
  description = "CPU utilization threshold for CloudWatch alarm (%)"
  type        = number
  default     = 75

  validation {
    condition     = var.alarm_cpu_threshold > 0 && var.alarm_cpu_threshold <= 100
    error_message = "CPU threshold must be between 1 and 100"
  }
}

variable "alarm_memory_threshold" {
  description = "Memory utilization threshold for CloudWatch alarm (%)"
  type        = number
  default     = 75

  validation {
    condition     = var.alarm_memory_threshold > 0 && var.alarm_memory_threshold <= 100
    error_message = "Memory threshold must be between 1 and 100"
  }
}

variable "alarm_connection_threshold" {
  description = "Connection count threshold for CloudWatch alarm"
  type        = number
  default     = 1000

  validation {
    condition     = var.alarm_connection_threshold > 0
    error_message = "Connection threshold must be greater than 0"
  }
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}
