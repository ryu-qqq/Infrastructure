# ==============================================================================
# Primary Identifiers
# ==============================================================================

output "cluster_id" {
  description = "The cluster identifier"
  value       = var.replication_group_id != null ? aws_elasticache_replication_group.redis[0].id : (var.engine == "redis" ? aws_elasticache_cluster.memcached-or-single-redis[0].cluster_id : aws_elasticache_cluster.memcached-or-single-redis[0].cluster_id)
}

output "cluster_arn" {
  description = "The ARN of the ElastiCache cluster or replication group"
  value       = var.replication_group_id != null ? aws_elasticache_replication_group.redis[0].arn : aws_elasticache_cluster.memcached-or-single-redis[0].arn
}

# ==============================================================================
# Endpoint Configuration
# ==============================================================================

output "configuration_endpoint" {
  description = "The configuration endpoint (for Memcached clusters or Redis cluster mode enabled)"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached-or-single-redis[0].configuration_endpoint : null
}

output "primary_endpoint_address" {
  description = "The primary endpoint address (for Redis replication groups)"
  value       = var.replication_group_id != null ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : null
}

output "reader_endpoint_address" {
  description = "The reader endpoint address (for Redis replication groups with Multi-AZ)"
  value       = var.replication_group_id != null && var.multi_az_enabled ? aws_elasticache_replication_group.redis[0].reader_endpoint_address : null
}

output "cache_nodes" {
  description = "List of cache nodes (for standalone clusters)"
  value       = var.replication_group_id == null ? aws_elasticache_cluster.memcached-or-single-redis[0].cache_nodes : []
}

output "endpoint_address" {
  description = "The cache endpoint address (works for both standalone and replication group)"
  value = coalesce(
    # 1. Replication Group primary endpoint
    var.replication_group_id != null ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : null,
    # 2. Standalone Redis/Memcached first node address
    length(aws_elasticache_cluster.memcached-or-single-redis) > 0 && length(aws_elasticache_cluster.memcached-or-single-redis[0].cache_nodes) > 0
    ? aws_elasticache_cluster.memcached-or-single-redis[0].cache_nodes[0].address
    : null
  )
}

# ==============================================================================
# Engine Configuration
# ==============================================================================

output "engine" {
  description = "The cache engine"
  value       = var.engine
}

output "engine_version" {
  description = "The running version of the cache engine"
  value       = var.replication_group_id != null ? aws_elasticache_replication_group.redis[0].engine_version_actual : aws_elasticache_cluster.memcached-or-single-redis[0].engine_version_actual
}

output "port" {
  description = "The port number on which the cache accepts connections"
  value       = local.port
}

# ==============================================================================
# Cluster Configuration
# ==============================================================================

output "node_type" {
  description = "The cache node type"
  value       = var.node_type
}

output "num_cache_nodes" {
  description = "The number of cache nodes"
  value       = var.replication_group_id != null ? null : var.num_cache_nodes
}

output "num_node_groups" {
  description = "The number of node groups (shards) for Redis replication group"
  value       = var.replication_group_id != null ? var.num_node_groups : null
}

output "replicas_per_node_group" {
  description = "The number of replica nodes in each node group"
  value       = var.replication_group_id != null ? var.replicas_per_node_group : null
}

# ==============================================================================
# Network Configuration
# ==============================================================================

output "subnet_group_id" {
  description = "The cache subnet group name"
  value       = aws_elasticache_subnet_group.this.id
}

output "availability_zone" {
  description = "The availability zone of the cluster (for single-node clusters)"
  value       = var.replication_group_id == null && var.num_cache_nodes == 1 ? aws_elasticache_cluster.memcached-or-single-redis[0].availability_zone : null
}

# ==============================================================================
# Parameter Group
# ==============================================================================

output "parameter_group_id" {
  description = "The cache parameter group name (if created)"
  value       = var.parameter_group_family != null ? aws_elasticache_parameter_group.this[0].id : null
}

output "parameter_group_arn" {
  description = "The ARN of the cache parameter group (if created)"
  value       = var.parameter_group_family != null ? aws_elasticache_parameter_group.this[0].arn : null
}

# ==============================================================================
# Security Configuration
# ==============================================================================

output "at_rest_encryption_enabled" {
  description = "Whether at-rest encryption is enabled"
  value       = var.at_rest_encryption_enabled
}

output "transit_encryption_enabled" {
  description = "Whether in-transit encryption is enabled"
  value       = var.transit_encryption_enabled
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption"
  value       = var.kms_key_id
}

# ==============================================================================
# High Availability Configuration
# ==============================================================================

output "automatic_failover_enabled" {
  description = "Whether automatic failover is enabled (Redis replication groups)"
  value       = var.replication_group_id != null ? var.automatic_failover_enabled : null
}

output "multi_az_enabled" {
  description = "Whether Multi-AZ is enabled (Redis replication groups)"
  value       = var.replication_group_id != null ? var.multi_az_enabled : null
}

# ==============================================================================
# Maintenance and Backup
# ==============================================================================

output "snapshot_retention_limit" {
  description = "The number of days to retain automatic snapshots"
  value       = var.snapshot_retention_limit
}

output "snapshot_window" {
  description = "The daily time range for snapshots"
  value       = var.snapshot_window
}

output "maintenance_window" {
  description = "The maintenance window"
  value       = var.maintenance_window
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

output "alarm_cpu_id" {
  description = "The ID of the CPU utilization alarm (if enabled)"
  value       = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.cpu[0].id : null
}

output "alarm_memory_id" {
  description = "The ID of the memory utilization alarm (if enabled)"
  value       = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.memory[0].id : null
}

output "alarm_connections_id" {
  description = "The ID of the connections alarm (if enabled)"
  value       = var.enable_cloudwatch_alarms ? aws_cloudwatch_metric_alarm.connections[0].id : null
}
