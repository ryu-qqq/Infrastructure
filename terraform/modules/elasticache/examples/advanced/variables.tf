variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where ElastiCache will be deployed"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ElastiCache replication group"
  type        = string
  default     = "redis-advanced-example"
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "parameter_group_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "num_node_groups" {
  description = "Number of node groups (shards)"
  type        = number
  default     = 2
}

variable "replicas_per_node_group" {
  description = "Number of replica nodes in each node group"
  type        = number
  default     = 2
}

variable "auth_token" {
  description = "Auth token for Redis (min 16 characters)"
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.auth_token == null || length(var.auth_token) >= 16
    error_message = "Auth token must be at least 16 characters"
  }
}
