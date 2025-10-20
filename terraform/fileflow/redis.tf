# ============================================================================
# Redis (ElastiCache) Configuration
# ============================================================================

module "redis" {
  source = "../modules/elasticache"

  # Cluster identification
  cluster_id  = "${local.name_prefix}-redis"
  description = "Redis cache for fileflow service"

  # Engine configuration
  engine         = "redis"
  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type
  num_cache_nodes = var.redis_num_cache_nodes

  # Network configuration
  vpc_id     = var.vpc_id
  subnet_ids = data.aws_subnets.private.ids

  # Security
  allowed_security_groups = []  # Will be updated after ECS service creation

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled         = true
  kms_key_id                 = data.terraform_remote_state.kms.outputs.elasticache_key_arn

  # Backup and maintenance
  snapshot_retention_limit = 5
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:06:00"

  # Monitoring
  sns_topic_arn = data.terraform_remote_state.monitoring.outputs.alerts_topic_arn

  # Tags
  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-redis"
      Component = "cache"
    }
  )
}

# Security group for Redis access
resource "aws_security_group" "redis_client" {
  name_description = "${local.name_prefix}-redis-client"
  description      = "Security group for services accessing Redis"
  vpc_id           = var.vpc_id

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-redis-client"
      Component = "cache"
    }
  )
}

# Allow ECS tasks to access Redis
resource "aws_security_group_rule" "redis_from_ecs" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = module.redis.security_group_id
  source_security_group_id = aws_security_group.redis_client.id
  description              = "Allow Redis access from ECS tasks"
}
