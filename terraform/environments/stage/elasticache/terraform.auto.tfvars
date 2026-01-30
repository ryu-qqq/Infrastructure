# ============================================================================
# Staging ElastiCache Configuration
# ============================================================================

# General
aws_region  = "ap-northeast-2"
environment = "staging"

# Tagging
service_name = "shared-cache"
team         = "platform-team"
owner        = "fbtkdals2@naver.com"
cost_center  = "engineering"
project      = "shared-infrastructure"
data_class   = "internal"

# Network - prod-server-vpc 사용 (stage RDS와 동일)
vpc_id = "vpc-0f162b9e588276e09" # prod-server-vpc
private_subnet_ids = [
  "subnet-09692620519f86cf0", # prod-private-subnet-1 (ap-northeast-2a)
  "subnet-0d99080cbe134b6e9"  # prod-private-subnet-2 (ap-northeast-2b)
]

# Security - 접근을 허용할 보안 그룹 ID들 (ECS 태스크 등)
allowed_security_group_ids = []
allowed_cidr_blocks        = ["10.0.0.0/16"] # VPC CIDR

# ElastiCache Configuration
cluster_id             = "stage-shared-redis"
engine                 = "redis"
engine_version         = "7.0"
node_type              = "cache.t3.micro"
num_cache_nodes        = 1
parameter_group_family = "redis7"
port                   = 6379

# Encryption
at_rest_encryption_enabled = true
transit_encryption_enabled = false # Stage 환경에서는 성능 우선

# Maintenance
snapshot_retention_limit = 1
snapshot_window          = "03:00-04:00"
maintenance_window       = "sun:04:00-sun:05:00"

# Monitoring
enable_cloudwatch_alarms = false

# Additional Tags
tags = {
  Purpose = "shared-cache-for-stage-services"
}
