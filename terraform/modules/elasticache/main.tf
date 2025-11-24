# ==============================================================================
# ElastiCache Module - Main Configuration
# Supports both Redis and Memcached with encryption, Multi-AZ, and monitoring
# ==============================================================================

# Common Tags Module
module "tags" {
  source = "../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = var.additional_tags
}

locals {
  # Required tags for governance compliance
  required_tags = module.tags.tags
}

# ==============================================================================
# Subnet Group
# ==============================================================================

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.cluster_id}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    local.required_tags,
    {
      Name = "${var.cluster_id}-subnet-group"
    }
  )
}

# ==============================================================================
# Parameter Group (Optional)
# ==============================================================================

resource "aws_elasticache_parameter_group" "this" {
  count = var.parameter_group_family != null ? 1 : 0

  name   = "${var.cluster_id}-parameter-group"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name = "${var.cluster_id}-parameter-group"
    }
  )
}

# ==============================================================================
# ElastiCache Replication Group (Redis with Replication)
# ==============================================================================

resource "aws_elasticache_replication_group" "redis" {
  count = var.replication_group_id != null && var.engine == "redis" ? 1 : 0

  replication_group_id = var.replication_group_id
  description = coalesce(
    var.replication_group_description,
    "Redis replication group for ${var.cluster_id}"
  )

  # Engine Configuration
  engine               = "redis"
  engine_version       = var.engine_version
  port                 = local.port
  parameter_group_name = var.parameter_group_family != null ? aws_elasticache_parameter_group.this[0].name : null
  node_type            = var.node_type

  # Cluster Configuration
  num_node_groups         = var.num_node_groups
  replicas_per_node_group = var.replicas_per_node_group

  # High Availability
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  # Network Configuration
  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  # Encryption
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token
  kms_key_id                 = var.kms_key_id

  # Maintenance and Backup
  snapshot_retention_limit   = var.snapshot_retention_limit
  snapshot_window            = var.snapshot_window
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  # Logging (Redis only)
  dynamic "log_delivery_configuration" {
    for_each = var.log_delivery_configuration
    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name = var.replication_group_id
    }
  )
}

# ==============================================================================
# ElastiCache Cluster (Memcached or Single-Node Redis)
# ==============================================================================

resource "aws_elasticache_cluster" "memcached-or-single-redis" {
  count = var.replication_group_id == null ? 1 : 0

  cluster_id = var.cluster_id

  # Engine Configuration
  engine               = var.engine
  engine_version       = var.engine_version
  port                 = local.port
  parameter_group_name = var.parameter_group_family != null ? aws_elasticache_parameter_group.this[0].name : null
  node_type            = var.node_type

  # Cluster Configuration
  num_cache_nodes = var.num_cache_nodes
  az_mode         = var.num_cache_nodes > 1 ? var.az_mode : "single-az"

  # Availability Zones (Memcached only)
  preferred_availability_zones = var.engine == "memcached" && length(var.preferred_availability_zones) > 0 ? var.preferred_availability_zones : null

  # Network Configuration
  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = var.security_group_ids

  # Maintenance and Backup
  snapshot_retention_limit   = var.engine == "redis" ? var.snapshot_retention_limit : null
  snapshot_window            = var.engine == "redis" ? var.snapshot_window : null
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  # Logging (Redis only)
  dynamic "log_delivery_configuration" {
    for_each = var.engine == "redis" ? var.log_delivery_configuration : []
    content {
      destination      = log_delivery_configuration.value.destination
      destination_type = log_delivery_configuration.value.destination_type
      log_format       = log_delivery_configuration.value.log_format
      log_type         = log_delivery_configuration.value.log_type
    }
  }

  tags = merge(
    local.required_tags,
    {
      Name = var.cluster_id
    }
  )
}

# ==============================================================================
# CloudWatch Alarms
# ==============================================================================

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_id}-cpu-utilization"
  alarm_description   = "ElastiCache ${var.cluster_id} - CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId     = var.replication_group_id != null ? null : var.cluster_id
    ReplicationGroupId = var.replication_group_id
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    local.required_tags,
    {
      Name = "${var.cluster_id}-cpu-alarm"
    }
  )
}

# Memory Utilization Alarm (Redis: DatabaseMemoryUsagePercentage, Memcached: SwapUsage)
resource "aws_cloudwatch_metric_alarm" "memory" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_id}-memory-utilization"
  alarm_description   = "ElastiCache ${var.cluster_id} - Memory utilization is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = var.engine == "redis" ? "DatabaseMemoryUsagePercentage" : "SwapUsage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = var.engine == "redis" ? "Average" : "Maximum"
  threshold           = var.engine == "redis" ? var.alarm_memory_threshold : var.alarm_swap_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId     = var.replication_group_id != null ? null : var.cluster_id
    ReplicationGroupId = var.replication_group_id
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    local.required_tags,
    {
      Name = "${var.cluster_id}-memory-alarm"
    }
  )
}

# Connection Count Alarm
resource "aws_cloudwatch_metric_alarm" "connections" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.cluster_id}-connection-count"
  alarm_description   = "ElastiCache ${var.cluster_id} - Connection count is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = var.engine == "redis" ? "CurrConnections" : "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_connection_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    CacheClusterId     = var.replication_group_id != null ? null : var.cluster_id
    ReplicationGroupId = var.replication_group_id
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    local.required_tags,
    {
      Name = "${var.cluster_id}-connections-alarm"
    }
  )
}
