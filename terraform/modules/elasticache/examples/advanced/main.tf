# ==============================================================================
# Advanced ElastiCache Redis Example
# Multi-AZ Redis Replication Group with automatic failover and encryption
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==============================================================================
# Common Tags Module
# ==============================================================================

module "common_tags" {
  source = "../../../common-tags"

  environment = var.environment
  service     = "cache-service"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  managed_by  = "terraform"
  project     = "elasticache-advanced-example"
}

# ==============================================================================
# VPC Data Source (Assuming VPC already exists)
# ==============================================================================

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "private"
  }
}

# ==============================================================================
# Security Group for ElastiCache
# ==============================================================================

resource "aws_security_group" "redis" {
  name        = "${var.cluster_name}-redis-sg"
  description = "Security group for ElastiCache Redis replication group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis port from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.cluster_name}-redis-sg"
    }
  )
}

# ==============================================================================
# KMS Key for ElastiCache Encryption
# ==============================================================================

resource "aws_kms_key" "redis" {
  description             = "KMS key for ElastiCache Redis replication group encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.cluster_name}-redis-kms"
    }
  )
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${var.cluster_name}-redis"
  target_key_id = aws_kms_key.redis.key_id
}

# ==============================================================================
# SNS Topic for CloudWatch Alarms
# ==============================================================================

resource "aws_sns_topic" "redis_alarms" {
  name = "${var.cluster_name}-redis-alarms"

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.cluster_name}-redis-alarms"
    }
  )
}

# ==============================================================================
# ElastiCache Redis Replication Group
# ==============================================================================

module "redis" {
  source = "../../"

  # Required Configuration
  common_tags        = module.common_tags.tags
  cluster_id         = var.cluster_name
  engine             = "redis"
  node_type          = var.node_type
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.redis.id]

  # Engine Version
  engine_version = var.engine_version

  # Replication Group Configuration
  replication_group_id          = "${var.cluster_name}-rg"
  replication_group_description = "Production Redis replication group with Multi-AZ"
  num_node_groups               = var.num_node_groups
  replicas_per_node_group       = var.replicas_per_node_group

  # High Availability
  automatic_failover_enabled = true
  multi_az_enabled           = true

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn
  auth_token                 = var.auth_token

  # Parameter Group
  parameter_group_family = var.parameter_group_family
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    },
    {
      name  = "timeout"
      value = "300"
    },
    {
      name  = "tcp-keepalive"
      value = "300"
    }
  ]

  # Maintenance and Backup
  snapshot_retention_limit = 14
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade = true

  # CloudWatch Alarms
  enable_cloudwatch_alarms = true
  alarm_cpu_threshold      = 80
  alarm_memory_threshold   = 85
  alarm_connection_threshold = 5000
  alarm_actions            = [aws_sns_topic.redis_alarms.arn]

  # Logging
  log_delivery_configuration = [
    {
      destination      = "${var.cluster_name}-slowlog"
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = "slow-log"
    },
    {
      destination      = "${var.cluster_name}-enginelog"
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = "engine-log"
    }
  ]
}

# ==============================================================================
# CloudWatch Log Groups for Redis Logs
# ==============================================================================

resource "aws_cloudwatch_log_group" "slowlog" {
  name              = "${var.cluster_name}-slowlog"
  retention_in_days = 7

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.cluster_name}-slowlog"
    }
  )
}

resource "aws_cloudwatch_log_group" "enginelog" {
  name              = "${var.cluster_name}-enginelog"
  retention_in_days = 7

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.cluster_name}-enginelog"
    }
  )
}

# ==============================================================================
# Outputs
# ==============================================================================

output "cluster_id" {
  description = "The Redis replication group ID"
  value       = module.redis.cluster_id
}

output "primary_endpoint_address" {
  description = "The primary endpoint address"
  value       = module.redis.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "The reader endpoint address"
  value       = module.redis.reader_endpoint_address
}

output "port" {
  description = "The port number on which Redis accepts connections"
  value       = module.redis.port
}

output "engine_version" {
  description = "The running version of Redis"
  value       = module.redis.engine_version
}

output "num_node_groups" {
  description = "The number of node groups (shards)"
  value       = module.redis.num_node_groups
}

output "replicas_per_node_group" {
  description = "The number of replica nodes in each node group"
  value       = module.redis.replicas_per_node_group
}
