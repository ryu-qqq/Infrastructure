# ============================================================================
# ElastiCache Outputs
# ============================================================================

output "cluster_id" {
  description = "The ElastiCache cluster identifier"
  value       = module.elasticache.cluster_id
}

output "cluster_arn" {
  description = "The ARN of the ElastiCache cluster"
  value       = module.elasticache.cluster_arn
}

output "endpoint_address" {
  description = "The cache endpoint address"
  value       = module.elasticache.endpoint_address
}

output "port" {
  description = "The port number on which the cache accepts connections"
  value       = module.elasticache.port
}

output "engine" {
  description = "The cache engine"
  value       = module.elasticache.engine
}

output "engine_version" {
  description = "The running version of the cache engine"
  value       = module.elasticache.engine_version
}

output "node_type" {
  description = "The cache node type"
  value       = module.elasticache.node_type
}

# ============================================================================
# Security Outputs
# ============================================================================

output "security_group_id" {
  description = "The ID of the ElastiCache security group"
  value       = aws_security_group.elasticache.id
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption"
  value       = aws_kms_key.elasticache.key_id
}

output "kms_key_arn" {
  description = "The KMS key ARN used for encryption"
  value       = aws_kms_key.elasticache.arn
}

# ============================================================================
# Connection String (for application configuration)
# ============================================================================

output "connection_string" {
  description = "Redis connection string for applications"
  value       = "${module.elasticache.endpoint_address}:${module.elasticache.port}"
}
