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
  description = "Service name (kebab-case, e.g., shared-cache)"
  type        = string
  default     = "shared-cache"

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
  default     = "internal"

  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "vpc_id" {
  description = "VPC ID where ElastiCache will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ElastiCache subnet group"
  type        = list(string)
}

# ============================================================================
# Security Configuration
# ============================================================================

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to access ElastiCache (e.g., ECS task security groups)"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access ElastiCache"
  type        = list(string)
  default     = []
}

# ============================================================================
# ElastiCache Configuration
# ============================================================================

variable "cluster_id" {
  description = "ElastiCache cluster identifier"
  type        = string
  default     = "stage-shared-redis"
}

variable "engine" {
  description = "Cache engine (redis or memcached)"
  type        = string
  default     = "redis"

  validation {
    condition     = contains(["redis", "memcached"], var.engine)
    error_message = "Engine must be either 'redis' or 'memcached'."
  }
}

variable "engine_version" {
  description = "Redis/Memcached engine version"
  type        = string
  default     = "7.0"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes (for standalone cluster)"
  type        = number
  default     = 1
}

variable "parameter_group_family" {
  description = "ElastiCache parameter group family"
  type        = string
  default     = "redis7"
}

variable "port" {
  description = "Port number for cache connections"
  type        = number
  default     = 6379
}

# ============================================================================
# Encryption Configuration
# ============================================================================

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit"
  type        = bool
  default     = false # Stage 환경에서는 성능을 위해 비활성화
}

# ============================================================================
# Maintenance Configuration
# ============================================================================

variable "snapshot_retention_limit" {
  description = "Number of days to retain snapshots (Redis only)"
  type        = number
  default     = 1 # Stage 환경에서는 최소 보관
}

variable "snapshot_window" {
  description = "Daily snapshot window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

# ============================================================================
# Monitoring Configuration
# ============================================================================

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = false # Stage 환경에서는 비활성화
}

# ============================================================================
# Tags
# ============================================================================

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
