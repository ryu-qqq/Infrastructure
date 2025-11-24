# ElastiCache Terraform Module

AWS ElastiCache 클러스터를 배포하고 관리하기 위한 재사용 가능한 Terraform 모듈입니다. Redis와 Memcached 엔진을 지원하며, 암호화, Multi-AZ, 자동 백업, CloudWatch 모니터링 등을 포함합니다.

## Features

- ✅ Redis 및 Memcached 엔진 지원
- ✅ Redis Replication Group (클러스터 모드 및 복제 지원)
- ✅ Multi-AZ 자동 장애 조치 (Automatic Failover)
- ✅ KMS 고객 관리형 키를 이용한 at-rest 및 in-transit 암호화
- ✅ ElastiCache Parameter Group 커스터마이징
- ✅ 자동 백업 및 스냅샷 관리 (Redis only)
- ✅ CloudWatch Logs 통합 (slow-log, engine-log)
- ✅ CloudWatch 알람 자동 생성 (CPU, 메모리, 연결 수)
- ✅ 표준화된 태그 자동 적용 (common-tags 모듈 통합)
- ✅ 포괄적인 변수 검증 및 거버넌스 준수

## Architecture

### Standalone Cluster (Single-node or Memcached)
```
┌─────────────────────────────────────┐
│   ElastiCache Cluster               │
│  ┌─────────────────────────────┐   │
│  │  Cache Node(s)              │   │
│  │  - Single Redis node        │   │
│  │  - Multiple Memcached nodes │   │
│  └─────────────────────────────┘   │
│                                     │
│  Subnet Group (Multi-AZ)            │
│  Parameter Group                    │
│  Security Groups                    │
└─────────────────────────────────────┘
```

### Redis Replication Group (Multi-AZ with Replicas)
```
┌─────────────────────────────────────────────────────────┐
│   ElastiCache Replication Group                         │
│                                                           │
│  ┌──────────────┐      ┌──────────────┐                 │
│  │  Node Group 1│      │  Node Group 2│  (Shards)       │
│  │ ┌──────────┐ │      │ ┌──────────┐ │                 │
│  │ │ Primary  │ │      │ │ Primary  │ │                 │
│  │ └──────────┘ │      │ └──────────┘ │                 │
│  │ ┌──────────┐ │      │ ┌──────────┐ │                 │
│  │ │ Replica  │ │      │ │ Replica  │ │                 │
│  │ └──────────┘ │      │ └──────────┘ │                 │
│  └──────────────┘      └──────────────┘                 │
│                                                           │
│  Primary Endpoint → Write Operations                     │
│  Reader Endpoint → Read Operations (Multi-AZ)            │
│  Automatic Failover Enabled                              │
└─────────────────────────────────────────────────────────┘
```

## Usage

### Basic Example (Single-node Redis)

```hcl

# Security Group for ElastiCache
resource "aws_security_group" "redis" {
  name        = "redis-dev-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from application layer"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  tags = module.common_tags.tags
}

# KMS Key for Encryption
resource "aws_kms_key" "redis" {
  description             = "KMS key for ElastiCache Redis encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = module.common_tags.tags
}

# ElastiCache Module - Basic Redis
module "redis" {
  source = "../../modules/elasticache"

  # Required Configuration
  environment  = "dev"
  service_name = "cache-service"
  team         = "platform-team"
  owner        = "fbtkdals2@naver.com"
  cost_center  = "engineering"
  cluster_id         = "redis-dev"
  engine             = "redis"
  engine_version     = "7.0"
  node_type          = "cache.t3.micro"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.redis.id]

  # Single-node configuration
  num_cache_nodes = 1

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn

  # Parameter Group
  parameter_group_family = "redis7"
  parameters = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]

  # Backup
  snapshot_retention_limit = 7

  # CloudWatch Alarms
  enable_cloudwatch_alarms = true
}
```

### Advanced Example (Redis Replication Group with Multi-AZ)

```hcl
# Security Group
resource "aws_security_group" "redis" {
  name        = "redis-prod-sg"
  description = "Security group for ElastiCache Redis Replication Group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = module.common_tags.tags
}

# KMS Key for Encryption
resource "aws_kms_key" "redis" {
  description             = "KMS key for ElastiCache Redis encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = module.common_tags.tags
}

# SNS Topic for Alarms
resource "aws_sns_topic" "redis_alarms" {
  name = "redis-prod-alarms"
  tags = module.common_tags.tags
}

# ElastiCache Module - Redis Replication Group
module "redis_cluster" {
  source = "../../modules/elasticache"

  # Required Configuration
  environment  = "dev"
  service_name = "cache-service"
  team         = "platform-team"
  owner        = "fbtkdals2@naver.com"
  cost_center  = "engineering"
  cluster_id         = "redis-prod"
  engine             = "redis"
  engine_version     = "7.0"
  node_type          = "cache.r6g.large"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.redis.id]

  # Replication Group Configuration
  replication_group_id          = "redis-prod-rg"
  replication_group_description = "Production Redis replication group"
  num_node_groups               = 2  # 2 shards
  replicas_per_node_group       = 2  # 2 replicas per shard

  # High Availability
  automatic_failover_enabled = true
  multi_az_enabled           = true

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn
  auth_token                 = var.redis_auth_token  # Min 16 characters

  # Parameter Group
  parameter_group_family = "redis7"
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

  # Backup
  snapshot_retention_limit = 14
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"

  # CloudWatch Alarms
  enable_cloudwatch_alarms = true
  alarm_cpu_threshold      = 80
  alarm_memory_threshold   = 85
  alarm_connection_threshold = 5000
  alarm_actions            = [aws_sns_topic.redis_alarms.arn]

  # Logging
  log_delivery_configuration = [
    {
      destination      = "redis-prod-slowlog"
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = "slow-log"
    },
    {
      destination      = "redis-prod-enginelog"
      destination_type = "cloudwatch-logs"
      log_format       = "json"
      log_type         = "engine-log"
    }
  ]
}

# CloudWatch Log Groups for Redis Logs
resource "aws_cloudwatch_log_group" "slowlog" {
  name              = "redis-prod-slowlog"
  retention_in_days = 7
  tags              = module.common_tags.tags
}

resource "aws_cloudwatch_log_group" "enginelog" {
  name              = "redis-prod-enginelog"
  retention_in_days = 7
  tags              = module.common_tags.tags
}
```

### Memcached Example

```hcl
module "memcached" {
  source = "../../modules/elasticache"

  # Required Configuration
  environment  = "dev"
  service_name = "cache-service"
  team         = "platform-team"
  owner        = "fbtkdals2@naver.com"
  cost_center  = "engineering"
  cluster_id         = "memcached-dev"
  engine             = "memcached"
  engine_version     = "1.6.6"
  node_type          = "cache.t3.micro"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.memcached.id]

  # Memcached Configuration
  num_cache_nodes = 3  # Distributed across AZs
  az_mode         = "cross-az"
  preferred_availability_zones = [
    "ap-northeast-2a",
    "ap-northeast-2b",
    "ap-northeast-2c"
  ]

  # Parameter Group
  parameter_group_family = "memcached1.6"

  # CloudWatch Alarms
  enable_cloudwatch_alarms = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

### Required Variables

| Name | Description | Type | Example |
|------|-------------|------|---------|
| `cluster_id` | Cluster identifier (lowercase, letters, numbers, hyphens) | `string` | `"redis-prod"` |
| `engine` | Cache engine (redis or memcached) | `string` | `"redis"` |
| `node_type` | Instance class | `string` | `"cache.t3.micro"` |
| `subnet_ids` | List of VPC subnet IDs | `list(string)` | `["subnet-xxx", "subnet-yyy"]` |
| `security_group_ids` | List of security group IDs | `list(string)` | `["sg-xxx"]` |

### Required Variables (Tagging)

| Name | Description | Type | Example |
|------|-------------|------|---------|
| `environment` | Environment name (dev, staging, prod) | `string` | `"prod"` |
| `service_name` | Service name (kebab-case) | `string` | `"cache-service"` |
| `team` | Team name (kebab-case) | `string` | `"platform-team"` |
| `owner` | Owner email or identifier | `string` | `"owner@example.com"` |
| `cost_center` | Cost center (kebab-case) | `string` | `"engineering"` |

### Optional Variables (Tagging)

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `project` | Project name | `string` | `"infrastructure"` |
| `data_class` | Data classification | `string` | `"confidential"` |
| `additional_tags` | Additional tags | `map(string)` | `{}` |

### Optional Variables - Engine Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `engine_version` | Engine version | `string` | `null` (uses latest) |
| `port` | Port number | `number` | `6379` (Redis), `11211` (Memcached) |

### Optional Variables - Redis Replication Group

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `replication_group_id` | Replication group identifier | `string` | `null` |
| `replication_group_description` | Description for replication group | `string` | `null` |
| `num_node_groups` | Number of shards | `number` | `1` |
| `replicas_per_node_group` | Replicas per shard | `number` | `1` |
| `automatic_failover_enabled` | Enable automatic failover | `bool` | `false` |
| `multi_az_enabled` | Enable Multi-AZ | `bool` | `false` |

### Optional Variables - Memcached Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `num_cache_nodes` | Number of cache nodes | `number` | `1` |
| `az_mode` | Availability zone mode (single-az or cross-az) | `string` | `"single-az"` |
| `preferred_availability_zones` | List of AZs for Memcached nodes | `list(string)` | `[]` |

### Optional Variables - Encryption

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `at_rest_encryption_enabled` | Enable at-rest encryption | `bool` | `true` |
| `transit_encryption_enabled` | Enable in-transit encryption | `bool` | `true` |
| `kms_key_id` | KMS key ARN | `string` | `null` (uses AWS managed key) |
| `auth_token` | Redis password (16-128 chars) | `string` | `null` |

### Optional Variables - Parameter Group

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `parameter_group_family` | Parameter group family | `string` | `null` |
| `parameters` | List of parameters | `list(object)` | `[]` |

### Optional Variables - Backup and Maintenance

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `snapshot_retention_limit` | Snapshot retention days (0-35) | `number` | `7` |
| `snapshot_window` | Daily snapshot window (UTC) | `string` | `"03:00-04:00"` |
| `maintenance_window` | Weekly maintenance window (UTC) | `string` | `"sun:04:00-sun:05:00"` |
| `auto_minor_version_upgrade` | Auto upgrade minor versions | `bool` | `true` |
| `apply_immediately` | Apply changes immediately | `bool` | `false` |

### Optional Variables - CloudWatch Alarms

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_cloudwatch_alarms` | Enable CloudWatch alarms | `bool` | `true` |
| `alarm_cpu_threshold` | CPU utilization threshold (%) | `number` | `75` |
| `alarm_memory_threshold` | Memory utilization threshold (%) | `number` | `75` |
| `alarm_connection_threshold` | Connection count threshold | `number` | `1000` |
| `alarm_actions` | List of SNS topic ARNs for alarms | `list(string)` | `[]` |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | Cluster or replication group ID |
| `cluster_arn` | ARN of the cluster or replication group |
| `primary_endpoint_address` | Primary endpoint (Redis replication group only) |
| `reader_endpoint_address` | Reader endpoint (Multi-AZ Redis only) |
| `configuration_endpoint` | Configuration endpoint (Memcached or cluster mode enabled) |
| `cache_nodes` | List of cache nodes (standalone clusters only) |
| `port` | Port number |
| `engine` | Cache engine |
| `engine_version` | Running engine version |
| `subnet_group_id` | Subnet group name |
| `parameter_group_id` | Parameter group name (if created) |

## Examples

See the [examples](./examples/) directory for complete working examples:

- **[basic](./examples/basic/)**: Single-node Redis cluster with encryption
- **[advanced](./examples/advanced/)**: Multi-AZ Redis replication group with automatic failover

## Governance and Security

This module follows infrastructure governance standards:

- ✅ **Required Tags**: All resources use `merge(var.common_tags, {...})` pattern
- ✅ **KMS Encryption**: Customer-managed KMS keys for at-rest and in-transit encryption
- ✅ **Naming Convention**: kebab-case for resource names, snake_case for variables
- ✅ **Security Scanning**: Passes tfsec and checkov validations
- ✅ **Network Security**: Deploys in private subnets with security group controls

## Best Practices

### Production Recommendations

1. **High Availability**
   - Use Redis replication groups with `automatic_failover_enabled = true`
   - Enable `multi_az_enabled = true` for production workloads
   - Deploy with at least 2 replicas per node group

2. **Security**
   - Always enable `at_rest_encryption_enabled = true`
   - Always enable `transit_encryption_enabled = true`
   - Use customer-managed KMS keys (not AWS managed)
   - Set `auth_token` for Redis (min 16 characters)
   - Deploy in private subnets only

3. **Backup and Recovery**
   - Set `snapshot_retention_limit` to at least 7 days for production
   - Use automated backups with appropriate `snapshot_window`
   - Test restore procedures regularly

4. **Monitoring**
   - Enable CloudWatch alarms for CPU, memory, and connections
   - Configure SNS topics for alarm notifications
   - Use CloudWatch Logs for slow-log and engine-log analysis
   - Monitor eviction rates and cache hit ratios

5. **Performance**
   - Choose appropriate node types based on workload
   - Use Parameter Groups to optimize cache behavior
   - Consider cluster mode for large datasets (Redis sharding)
   - Monitor connection counts and adjust application connection pooling

## Troubleshooting

### Common Issues

**Issue**: Cannot connect to Redis cluster
- Verify security group allows traffic from application security group
- Check if cluster is in the same VPC as the application
- Ensure subnet group contains subnets in the same VPC

**Issue**: Authentication failures with Redis
- Verify `transit_encryption_enabled = true` when using `auth_token`
- Ensure auth token is between 16-128 characters
- Check that application is using TLS connection with auth token

**Issue**: High memory utilization
- Review `maxmemory-policy` parameter (e.g., `allkeys-lru`)
- Consider scaling up to a larger node type
- Analyze data access patterns and TTL settings

## References

- [AWS ElastiCache Documentation](https://docs.aws.amazon.com/elasticache/)
- [Redis Best Practices](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/BestPractices.html)
- [Memcached Best Practices](https://docs.aws.amazon.com/AmazonElastiCache/latest/mem-ug/BestPractices.html)
- [ElastiCache Parameter Groups](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/ParameterGroups.html)

## License

This module is maintained as part of the infrastructure repository.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for version history and changes.
