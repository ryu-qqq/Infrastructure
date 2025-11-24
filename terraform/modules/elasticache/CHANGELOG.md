# Changelog

All notable changes to the ElastiCache Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-18

### Added

#### Core Features
- Initial release of ElastiCache Terraform module
- Support for Redis and Memcached engines
- Redis Replication Group support with cluster mode
- Single-node and multi-node cluster configurations
- Multi-AZ deployment with automatic failover for Redis

#### Security
- KMS customer-managed key encryption for at-rest data
- TLS encryption for data in-transit (Redis only)
- Redis AUTH token support for authentication
- Security group integration for network access control

#### High Availability
- Redis Replication Groups with configurable shards (num_node_groups)
- Configurable replicas per shard (replicas_per_node_group)
- Automatic failover configuration (automatic_failover_enabled)
- Multi-AZ support for read replicas (multi_az_enabled)
- Memcached cross-AZ distribution

#### Configuration Management
- ElastiCache Parameter Group support with custom parameters
- Redis and Memcached parameter family options
- Subnet group configuration with multi-AZ support
- Flexible port configuration (default 6379 for Redis, 11211 for Memcached)

#### Backup and Maintenance
- Automated backup configuration for Redis (snapshot_retention_limit)
- Configurable snapshot window (snapshot_window)
- Configurable maintenance window (maintenance_window)
- Automatic minor version upgrades (auto_minor_version_upgrade)
- Apply immediately option (apply_immediately)

#### Monitoring and Logging
- CloudWatch Alarms for CPU utilization
- CloudWatch Alarms for memory utilization
- CloudWatch Alarms for connection count
- Configurable alarm thresholds
- SNS topic integration for alarm notifications
- Redis slow-log and engine-log delivery to CloudWatch Logs

#### Governance and Compliance
- Common-tags module integration (var.common_tags)
- merge(var.common_tags, {...}) pattern for all resources
- Kebab-case naming for resources
- Snake_case naming for variables
- Comprehensive input validation
- tfsec and checkov security compliance

#### Examples
- Basic example: Single-node Redis cluster with encryption
- Advanced example: Multi-AZ Redis replication group with automatic failover
- Memcached example in documentation

#### Documentation
- Comprehensive README.md with usage examples
- Architecture diagrams for standalone and replication group
- Input variables documentation with types and defaults
- Output values documentation
- Best practices and troubleshooting guide
- Governance and security standards

### Technical Details

#### Resource Types
- `aws_elasticache_subnet_group`: Subnet group for ElastiCache
- `aws_elasticache_parameter_group`: Custom parameter groups (optional)
- `aws_elasticache_replication_group`: Redis replication groups (conditional)
- `aws_elasticache_cluster`: Standalone clusters (Memcached or single-node Redis)
- `aws_cloudwatch_metric_alarm`: CPU, memory, and connection alarms (optional)

#### Supported Configurations
- **Redis Standalone**: Single-node cluster with encryption and backups
- **Redis Replication Group**: Multi-node, multi-shard with automatic failover
- **Memcached Standalone**: Single-node cluster
- **Memcached Distributed**: Multi-node cluster across AZs

#### Version Compatibility
- Terraform >= 1.5.0
- AWS Provider >= 5.0
- Redis Engine: 3.2.6+ (for encryption support)
- Memcached Engine: 1.4.5+

### Dependencies
- **Required**: common-tags module for standardized tagging
- **Optional**: Security group module (example uses inline security groups)
- **Optional**: KMS module (example creates keys inline)
- **Optional**: SNS module (example creates topics inline)

### Validation
- ✅ Cluster ID: Lowercase letters, numbers, hyphens only
- ✅ Engine: Must be "redis" or "memcached"
- ✅ Node Type: Valid ElastiCache instance type format (cache.*.*)
- ✅ Subnet IDs: At least 1 subnet required
- ✅ Port: Between 1 and 65535
- ✅ Snapshot Retention: Between 0 and 35 days
- ✅ Auth Token: Between 16 and 128 characters (if provided)
- ✅ CPU Threshold: Between 1 and 100 percent
- ✅ Memory Threshold: Between 1 and 100 percent
- ✅ Connection Threshold: Greater than 0

### Known Limitations
- Memcached does not support encryption
- Memcached does not support backup/snapshot features
- Redis AUTH requires transit encryption to be enabled
- Cluster mode enabled requires Redis 3.2.4+
- Auth token cannot be updated without recreation

### Future Enhancements
- [ ] Cluster mode enabled support for Redis
- [ ] Global Datastore support for cross-region replication
- [ ] Data tiering support (Redis 6.2+)
- [ ] User and user group management (RBAC)
- [ ] Auto scaling for Redis clusters
- [ ] Enhanced metrics and custom dashboards

## [Unreleased]

### Changed
- **BREAKING**: Replaced `common_tags` variable with individual tagging variables
- Module now integrates common-tags module internally for standardized tagging
- Required tagging variables: `environment`, `service_name`, `team`, `owner`, `cost_center`
- Optional tagging variables: `project`, `data_class`, `additional_tags`
- All resources now automatically receive standardized tags from common-tags module

### Migration Guide
Replace:
```hcl
module "elasticache" {
  common_tags = module.common_tags.tags
}
```

With:
```hcl
module "elasticache" {
  environment  = "prod"
  service_name = "cache-service"
  team         = "platform-team"
  owner        = "owner@example.com"
  cost_center  = "engineering"
}
```

---

## Release Notes

### v1.0.0 Release Summary

This is the initial stable release of the ElastiCache Terraform module. It provides comprehensive support for deploying and managing ElastiCache clusters for both Redis and Memcached engines.

**Key Features:**
- Production-ready Redis replication groups with Multi-AZ and automatic failover
- Complete encryption support (at-rest with KMS, in-transit with TLS)
- Integrated monitoring with CloudWatch alarms
- Automated backups for Redis
- Governance-compliant with required tags and security standards

**Use Cases:**
- Session management and caching
- Real-time analytics and leaderboards
- Pub/Sub messaging (Redis)
- Distributed caching (Memcached)
- Database query result caching

**Migration Path:**
For existing ElastiCache resources, import using:
```bash
# For standalone cluster
terraform import module.elasticache.aws_elasticache_cluster.memcached_or_single_redis[0] <cluster_id>

# For replication group
terraform import module.elasticache.aws_elasticache_replication_group.redis[0] <replication_group_id>
```

**Breaking Changes:**
- None (initial release)

**Security Notes:**
- All examples demonstrate encryption at rest and in transit
- Customer-managed KMS keys recommended for production
- Security groups should follow principle of least privilege
- AUTH tokens strongly recommended for Redis production deployments

---

[1.0.0]: https://github.com/your-org/infrastructure/releases/tag/elasticache-v1.0.0
