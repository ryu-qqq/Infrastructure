# ============================================================================
# General Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "vpc_id" {
  description = "VPC ID where DMS replication instance will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for DMS replication subnet group"
  type        = list(string)
}

# ============================================================================
# Source (Prod) Configuration
# ============================================================================

variable "source_db_host" {
  description = "Source (Prod) RDS endpoint hostname"
  type        = string
}

variable "source_db_port" {
  description = "Source database port"
  type        = number
  default     = 3306
}

variable "source_db_name" {
  description = "Source database name"
  type        = string
  default     = "shared_db"
}

variable "source_secrets_manager_arn" {
  description = "Secrets Manager ARN containing source DB credentials"
  type        = string
}

variable "source_security_group_id" {
  description = "Security group ID of the source RDS instance"
  type        = string
}

# ============================================================================
# Target (Stage) Configuration
# ============================================================================

variable "target_db_host" {
  description = "Target (Stage) RDS Proxy endpoint hostname"
  type        = string
}

variable "target_db_port" {
  description = "Target database port"
  type        = number
  default     = 3306
}

variable "target_db_name" {
  description = "Target database name"
  type        = string
  default     = "shared_db"
}

variable "target_secrets_manager_arn" {
  description = "Secrets Manager ARN containing target DB credentials"
  type        = string
}

variable "target_security_group_id" {
  description = "Security group ID of the target RDS instance"
  type        = string
}

# ============================================================================
# DMS Configuration
# ============================================================================

variable "replication_instance_class" {
  description = "DMS replication instance class"
  type        = string
  default     = "dms.t3.medium"
}

variable "allocated_storage" {
  description = "Storage allocated for the replication instance (GB)"
  type        = number
  default     = 50
}

variable "schema_name" {
  description = "Schema name to replicate (e.g., luxurydb)"
  type        = string
  default     = "luxurydb"
}

variable "migration_type" {
  description = "DMS migration type (full-load, cdc, full-load-and-cdc)"
  type        = string
  default     = "full-load-and-cdc"
}
