# ElastiCache Module for Staging Environment
# 여러 서버들이 공유하는 단일 Redis 인스턴스

module "elasticache" {
  source = "../../../modules/elasticache"

  # Cluster Configuration
  cluster_id      = var.cluster_id
  engine          = var.engine
  engine_version  = var.engine_version
  node_type       = var.node_type
  num_cache_nodes = var.num_cache_nodes

  # Network Configuration
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.elasticache.id]

  # Parameter Group
  parameter_group_family = var.parameter_group_family
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]

  # Encryption - Zero-Tolerance: KMS 고객 관리형 키 사용
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  kms_key_id                 = aws_kms_key.elasticache.arn

  # Maintenance
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  maintenance_window       = var.maintenance_window

  # Monitoring
  enable_cloudwatch_alarms = var.enable_cloudwatch_alarms

  # Required Tagging Information
  environment  = var.environment
  service_name = var.service_name
  team         = var.team
  owner        = var.owner
  cost_center  = var.cost_center
  project      = var.project
  data_class   = var.data_class

  additional_tags = var.tags
}
