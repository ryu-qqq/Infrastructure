# 하이브리드 Terraform 인프라: Application 프로젝트 설정

**작성일**: 2025-10-22
**버전**: 1.0
**대상 독자**: 서비스 개발팀, 새로운 서비스 론칭팀
**소요 시간**: 45분
**선행 문서**: [Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)

---

## 📋 목차

1. [개요](#개요)
2. [Step 1: 프로젝트 구조 생성](#step-1-프로젝트-구조-생성)
3. [Step 2: data.tf 작성](#step-2-datatf-작성-ssm-parameter-데이터-소스)
4. [Step 3: locals.tf 작성](#step-3-localstf-작성-ssm-parameter-값-참조)
5. [Step 4: variables.tf 작성](#step-4-variablestf-작성)
6. [Step 5: database.tf 작성](#step-5-databasetf-작성-shared-rds-연결)
7. [Step 6: 리소스별 KMS Key 매핑](#step-6-리소스별-kms-key-매핑)
8. [Step 7: iam.tf 작성](#step-7-iamtf-작성-로컬-변수-참조)
9. [Step 8: 환경별 terraform.tfvars 작성](#step-8-환경별-terraformtfvars-작성)
10. [검증](#검증)
11. [다음 단계](#다음-단계)

---

## 개요

이 가이드는 **Application 프로젝트 설정**을 다룹니다. Application 프로젝트는 서비스별 인프라를 관리하며, Infrastructure 프로젝트에서 생성된 공유 리소스를 **SSM Parameter Store를 통해 참조**합니다.

### 목표

- Application 프로젝트 디렉토리 구조 생성
- SSM Parameter Store를 통한 공유 리소스 참조
- 서비스별 리소스 정의 (ECS, Redis, S3, SQS, ALB)
- Shared RDS 연결 설정
- IAM 역할 및 정책 작성
- 환경별 구성 파일 작성

### 사전 요구사항

✅ **Infrastructure 프로젝트 배포 완료**
- Network 모듈 배포 완료 (VPC, Subnets)
- KMS 모듈 배포 완료 (7개 KMS 키)
- Shared RDS 배포 완료 (사용 시)
- ECR Repository 배포 완료

✅ **SSM Parameters 확인**
```bash
# 모든 SSM Parameters 확인
aws ssm get-parameters-by-path \
  --path /shared \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name]' \
  --output table
```

**기대 결과**: 최소 13개 이상의 SSM Parameters (Network 4개 + KMS 7개 + ECR 1개 + RDS 3개 옵션)

---

## Step 1: 프로젝트 구조 생성

### 디렉토리 생성

```bash
cd /Users/sangwon-ryu/{service-name}

# 디렉토리 생성
mkdir -p infrastructure/terraform/{environments/{dev,staging,prod},modules}
mkdir -p infrastructure/scripts
mkdir -p .github/workflows
```

### 결과 구조

```
{service-name}/
├── infrastructure/
│   ├── terraform/
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   │   └── terraform.tfvars
│   │   │   ├── staging/
│   │   │   │   └── terraform.tfvars
│   │   │   └── prod/
│   │   │       └── terraform.tfvars
│   │   ├── modules/          # (Infrastructure repo에서 복사)
│   │   ├── data.tf           # SSM Parameter 데이터 소스
│   │   ├── locals.tf         # SSM Parameter 값 참조
│   │   ├── variables.tf      # 서비스별 변수
│   │   ├── provider.tf       # Terraform 및 AWS Provider
│   │   ├── database.tf       # Shared RDS 연결
│   │   ├── ecs.tf            # ECS 클러스터 및 서비스
│   │   ├── redis.tf          # ElastiCache Redis
│   │   ├── s3.tf             # S3 버킷
│   │   ├── sqs.tf            # SQS 큐
│   │   ├── alb.tf            # Application Load Balancer
│   │   ├── iam.tf            # IAM 역할 및 정책
│   │   └── outputs.tf        # 출력 값
│   └── scripts/
│       └── deploy.sh
├── .github/
│   └── workflows/
│       ├── build-and-push.yml
│       └── deploy.yml
└── db/
    └── migration/
        ├── V001__initial_schema.sql
        └── ...
```

---

## Step 2: data.tf 작성 (SSM Parameter 데이터 소스)

**파일**: `infrastructure/terraform/data.tf`

이 파일은 Infrastructure 프로젝트에서 생성한 **SSM Parameters를 데이터 소스로 참조**합니다.

### 전체 코드

```hcl
# ============================================================================
# Data Sources for Shared Infrastructure
# ============================================================================

# Account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# Network Information (from SSM Parameters)
# ============================================================================

data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/shared/network/private-subnet-ids"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name = "/shared/network/public-subnet-ids"
}

data "aws_ssm_parameter" "data_subnet_ids" {
  name = "/shared/network/data-subnet-ids"
}

# VPC 정보 직접 조회 (fallback)
data "aws_vpc" "main" {
  id = local.vpc_id
}

# Subnets 직접 조회 (fallback)
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  tags = {
    Tier = "Private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  tags = {
    Tier = "Public"
  }
}

# ============================================================================
# KMS Keys (from SSM Parameters)
# ============================================================================

data "aws_ssm_parameter" "cloudwatch_logs_key_arn" {
  name = "/shared/kms/cloudwatch-logs-key-arn"
}

data "aws_ssm_parameter" "secrets_manager_key_arn" {
  name = "/shared/kms/secrets-manager-key-arn"
}

data "aws_ssm_parameter" "rds_key_arn" {
  name = "/shared/kms/rds-key-arn"
}

data "aws_ssm_parameter" "s3_key_arn" {
  name = "/shared/kms/s3-key-arn"
}

data "aws_ssm_parameter" "sqs_key_arn" {
  name = "/shared/kms/sqs-key-arn"
}

data "aws_ssm_parameter" "ssm_key_arn" {
  name = "/shared/kms/ssm-key-arn"
}

data "aws_ssm_parameter" "elasticache_key_arn" {
  name = "/shared/kms/elasticache-key-arn"
}

# ============================================================================
# ECR Repository (from SSM Parameters)
# ============================================================================

data "aws_ssm_parameter" "ecr_repository_url" {
  name = "/shared/ecr/${var.service_name}-repository-url"
}

# ============================================================================
# Shared RDS Information (from SSM Parameters - Optional)
# ============================================================================

# Shared RDS를 사용하는 경우 추가
data "aws_ssm_parameter" "shared_rds_identifier" {
  count = var.shared_rds_identifier != "" ? 1 : 0
  name  = "/shared/rds/${var.environment}/identifier"
}

data "aws_ssm_parameter" "shared_rds_security_group_id" {
  count = var.shared_rds_identifier != "" ? 1 : 0
  name  = "/shared/rds/${var.environment}/security-group-id"
}

data "aws_ssm_parameter" "shared_rds_master_secret_arn" {
  count = var.shared_rds_identifier != "" ? 1 : 0
  name  = "/shared/rds/${var.environment}/master-secret-arn"
}
```

### 핵심 포인트

1. **SSM Parameter 참조**: `/shared/` 경로의 모든 공유 리소스를 참조
2. **조건부 데이터 소스**: Shared RDS를 사용하지 않는 경우 `count = 0`으로 비활성화
3. **Fallback 데이터 소스**: VPC와 Subnets은 직접 조회도 가능 (이중화)

---

## Step 3: locals.tf 작성 (SSM Parameter 값 참조)

**파일**: `infrastructure/terraform/locals.tf`

이 파일은 **SSM Parameter 데이터 소스의 값을 로컬 변수로 매핑**합니다.

### 전체 코드

```hcl
# ============================================================================
# Local Variables
# ============================================================================

locals {
  # Account and Region
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Naming
  name_prefix  = "${var.service_name}-${var.environment}"
  service_name = var.service_name

  # Network (from SSM Parameters)
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  public_subnet_ids  = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
  data_subnet_ids    = split(",", data.aws_ssm_parameter.data_subnet_ids.value)

  # KMS Keys (from SSM Parameters)
  cloudwatch_key_arn  = data.aws_ssm_parameter.cloudwatch_logs_key_arn.value
  secrets_key_arn     = data.aws_ssm_parameter.secrets_manager_key_arn.value
  rds_key_arn         = data.aws_ssm_parameter.rds_key_arn.value
  s3_key_arn          = data.aws_ssm_parameter.s3_key_arn.value
  sqs_key_arn         = data.aws_ssm_parameter.sqs_key_arn.value
  ssm_key_arn         = data.aws_ssm_parameter.ssm_key_arn.value
  elasticache_key_arn = data.aws_ssm_parameter.elasticache_key_arn.value

  # ECR (from SSM Parameters)
  ecr_repository_url = data.aws_ssm_parameter.ecr_repository_url.value

  # Shared RDS (from SSM Parameters - Optional)
  shared_rds_identifier        = var.shared_rds_identifier != "" ? data.aws_ssm_parameter.shared_rds_identifier[0].value : ""
  shared_rds_security_group_id = var.shared_rds_identifier != "" ? data.aws_ssm_parameter.shared_rds_security_group_id[0].value : ""
  shared_rds_master_secret_arn = var.shared_rds_identifier != "" ? data.aws_ssm_parameter.shared_rds_master_secret_arn[0].value : ""

  # Required Tags
  required_tags = {
    Environment = var.environment
    Service     = var.service_name
    Owner       = var.tags_owner
    CostCenter  = var.tags_cost_center
    Team        = var.tags_team
    Lifecycle   = var.environment == "prod" ? "critical" : "non-critical"
    DataClass   = "sensitive"
    ManagedBy   = "Terraform"
    Repository  = var.service_name
  }
}
```

### 핵심 포인트

1. **StringList 파싱**: Subnet IDs는 쉼표로 구분된 문자열이므로 `split()` 함수 사용
2. **조건부 로컬 변수**: Shared RDS를 사용하지 않는 경우 빈 문자열 반환
3. **Required Tags**: 모든 리소스에 적용할 공통 태그 정의

---

## Step 4: variables.tf 작성

**파일**: `infrastructure/terraform/variables.tf`

### 전체 코드

```hcl
# ============================================================================
# Core Variables
# ============================================================================

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "service_name" {
  description = "Service name"
  type        = string
  default     = "fileflow"
}

# ============================================================================
# Shared RDS Configuration (Shared RDS 사용 시)
# ============================================================================

variable "shared_rds_identifier" {
  description = "Identifier of the shared RDS instance"
  type        = string
  default     = ""
}

variable "shared_rds_master_secret_arn" {
  description = "ARN of Secrets Manager secret for shared RDS master credentials"
  type        = string
  default     = ""
}

variable "shared_rds_security_group_id" {
  description = "Security group ID of shared RDS"
  type        = string
  default     = ""
}

# ============================================================================
# Database Configuration
# ============================================================================

variable "db_name" {
  description = "Database name for this service"
  type        = string
  default     = "fileflow"
}

variable "db_username" {
  description = "Database username for this service"
  type        = string
  default     = "fileflow_user"
}

# ============================================================================
# ECS Configuration
# ============================================================================

variable "ecs_task_cpu" {
  description = "ECS task CPU units"
  type        = string
  default     = "512"
}

variable "ecs_task_memory" {
  description = "ECS task memory (MB)"
  type        = string
  default     = "1024"
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

# ============================================================================
# Redis Configuration
# ============================================================================

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

# ============================================================================
# Tags
# ============================================================================

variable "tags_owner" {
  description = "Owner tag value"
  type        = string
  default     = "platform-team"
}

variable "tags_cost_center" {
  description = "Cost center tag value"
  type        = string
  default     = "engineering"
}

variable "tags_team" {
  description = "Team tag value"
  type        = string
  default     = "platform-team"
}
```

### 핵심 포인트

1. **Validation**: `environment` 변수는 `dev`, `staging`, `prod`만 허용
2. **Default 값**: 개발 환경에 적합한 기본값 제공
3. **서비스별 커스터마이징**: 각 서비스의 `terraform.tfvars`에서 오버라이드

---

## Step 5: database.tf 작성 (Shared RDS 연결)

**파일**: `infrastructure/terraform/database.tf`

이 파일은 **Shared RDS 인스턴스에 서비스별 데이터베이스와 사용자를 생성**합니다.

### 전체 코드

```hcl
# ============================================================================
# Database Configuration (Shared RDS)
# ============================================================================

# Data source to get shared RDS instance
data "aws_db_instance" "shared" {
  count                  = var.shared_rds_identifier != "" ? 1 : 0
  db_instance_identifier = var.shared_rds_identifier
}

# Security group rule to allow ECS tasks to access shared RDS
resource "aws_security_group_rule" "shared_rds_from_ecs" {
  count                    = var.shared_rds_identifier != "" ? 1 : 0
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.shared_rds_security_group_id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow MySQL access from ${var.service_name} ECS tasks"
}

# Random password for service-specific database user
resource "random_password" "db_password" {
  count   = var.shared_rds_identifier != "" ? 1 : 0
  length  = 32
  special = true
}

# Store service-specific database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  count                   = var.shared_rds_identifier != "" ? 1 : 0
  name_prefix             = "${local.name_prefix}-db-credentials-"
  description             = "Database credentials for ${var.service_name} service"
  kms_key_id              = local.secrets_key_arn
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-credentials"
      Component = "database"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  count     = var.shared_rds_identifier != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.db_credentials[0].id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password[0].result
    database = var.db_name
    host     = data.aws_db_instance.shared[0].endpoint
    port     = 3306
  })
}

# MySQL database and user creation using null_resource
resource "null_resource" "create_database_and_user" {
  count = var.shared_rds_identifier != "" ? 1 : 0

  # Trigger on database name or username changes
  triggers = {
    db_name      = var.db_name
    db_username  = var.db_username
    rds_endpoint = data.aws_db_instance.shared[0].endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for RDS to be available
      sleep 30

      # Get master credentials from Secrets Manager
      MASTER_CREDS=$(aws secretsmanager get-secret-value \
        --secret-id ${var.shared_rds_master_secret_arn} \
        --query SecretString \
        --output text \
        --region ${var.aws_region})

      MASTER_USER=$(echo $MASTER_CREDS | jq -r .username)
      MASTER_PASS=$(echo $MASTER_CREDS | jq -r .password)
      RDS_HOST="${data.aws_db_instance.shared[0].endpoint}"

      # Create database and user
      mysql -h "$RDS_HOST" -u "$MASTER_USER" -p"$MASTER_PASS" << 'SQL'
        -- Create database if not exists
        CREATE DATABASE IF NOT EXISTS ${var.db_name}
          CHARACTER SET utf8mb4
          COLLATE utf8mb4_unicode_ci;

        -- Create user if not exists
        CREATE USER IF NOT EXISTS '${var.db_username}'@'%'
          IDENTIFIED BY '${random_password.db_password[0].result}';

        -- Grant minimal required privileges
        GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
          ON ${var.db_name}.* TO '${var.db_username}'@'%';

        -- Flush privileges
        FLUSH PRIVILEGES;
      SQL

      echo "Database ${var.db_name} and user ${var.db_username} created successfully"
    EOT
  }

  depends_on = [
    random_password.db_password,
    aws_secretsmanager_secret_version.db_credentials
  ]
}

# IAM policy for accessing service-specific database credentials
resource "aws_iam_policy" "db_access" {
  count       = var.shared_rds_identifier != "" ? 1 : 0
  name        = "${local.name_prefix}-db-access"
  description = "Policy for ${var.service_name} to access its database credentials"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials[0].arn,
          "${aws_secretsmanager_secret.db_credentials[0].arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = local.secrets_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-access"
      Component = "iam"
    }
  )
}

# Attach database access policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_db" {
  count      = var.shared_rds_identifier != "" ? 1 : 0
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.db_access[0].arn
}

# CloudWatch Log Group for database query logs (optional)
resource "aws_cloudwatch_log_group" "database_queries" {
  count             = var.shared_rds_identifier != "" ? 1 : 0
  name              = "/aws/rds/${local.service_name}/queries"
  retention_in_days = 7
  kms_key_id        = local.cloudwatch_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-queries"
      Component = "logging"
    }
  )
}
```

### 핵심 포인트

1. **조건부 리소스 생성**: `count`를 사용하여 Shared RDS를 사용하지 않는 경우 리소스 생성 안 함
2. **Secrets Manager 암호화**: DB 자격 증명을 Secrets Manager에 저장 (KMS 암호화)
3. **null_resource 프로비저너**: MySQL 명령어로 데이터베이스와 사용자 생성
4. **최소 권한 부여**: 서비스별 사용자에게 필요한 권한만 부여

---

## Step 6: 리소스별 KMS Key 매핑

**중요**: 각 리소스는 **전용 KMS key**를 사용해야 합니다.

### KMS Key 매핑 테이블

| 리소스 타입 | KMS Key 로컬 변수 | 사용 예제 |
|------------|-------------------|----------|
| CloudWatch Logs | `local.cloudwatch_key_arn` | Log Groups |
| Secrets Manager | `local.secrets_key_arn` | DB Credentials, API Keys |
| RDS | `local.rds_key_arn` | RDS Storage Encryption |
| S3 | `local.s3_key_arn` | S3 Bucket Encryption |
| SQS | `local.sqs_key_arn` | SQS Queue Encryption |
| SSM Parameters | `local.ssm_key_arn` | Secure String Parameters |
| ElastiCache | `local.elasticache_key_arn` | Redis at-rest encryption |

### Redis 예제

**파일**: `infrastructure/terraform/redis.tf`

```hcl
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${local.name_prefix}-redis"
  replication_group_description = "Redis cluster for ${var.service_name}"
  engine                     = "redis"
  engine_version             = "7.0"
  node_type                  = var.redis_node_type
  num_cache_clusters         = var.redis_num_cache_nodes
  parameter_group_name       = "default.redis7"
  port                       = 6379

  # Network
  subnet_group_name = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled         = true
  kms_key_id                 = local.elasticache_key_arn  # ✅ ElastiCache 전용 키

  # Maintenance
  automatic_failover_enabled  = var.environment == "prod"
  multi_az_enabled           = var.environment == "prod"
  snapshot_retention_limit   = var.environment == "prod" ? 7 : 1
  snapshot_window            = "03:00-05:00"
  maintenance_window         = "mon:05:00-mon:06:00"

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-redis"
      Component = "cache"
    }
  )
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-subnet-group"
  subnet_ids = local.data_subnet_ids

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-redis-subnet-group"
      Component = "cache"
    }
  )
}
```

### SQS 예제

**파일**: `infrastructure/terraform/sqs.tf`

```hcl
resource "aws_sqs_queue" "file_processing" {
  name                      = "${local.name_prefix}-file-processing"
  message_retention_seconds = 1209600  # 14 days
  visibility_timeout_seconds = 300
  receive_wait_time_seconds = 20       # Long polling

  # Encryption
  kms_master_key_id                 = local.sqs_key_arn  # ✅ SQS 전용 키
  kms_data_key_reuse_period_seconds = 300

  # Dead Letter Queue
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.file_processing_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-file-processing-queue"
      Component = "queue"
    }
  )
}

# Dead Letter Queue
resource "aws_sqs_queue" "file_processing_dlq" {
  name                      = "${local.name_prefix}-file-processing-dlq"
  message_retention_seconds = 1209600  # 14 days

  # Encryption
  kms_master_key_id                 = local.sqs_key_arn  # ✅ SQS 전용 키
  kms_data_key_reuse_period_seconds = 300

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-file-processing-dlq"
      Component = "queue"
    }
  )
}
```

### S3 예제

**파일**: `infrastructure/terraform/s3.tf`

```hcl
resource "aws_s3_bucket" "storage" {
  bucket = "${local.name_prefix}-storage"

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-storage"
      Component = "storage"
    }
  )
}

# Encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.s3_key_arn  # ✅ S3 전용 키
    }
    bucket_key_enabled = true
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "storage" {
  bucket = aws_s3_bucket.storage.id

  versioning_configuration {
    status = var.environment == "prod" ? "Enabled" : "Suspended"
  }
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "archive-old-files"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555  # 7 years
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "storage" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

---

## Step 7: iam.tf 작성 (로컬 변수 참조)

**중요**: Remote state 대신 로컬 변수 사용

**파일**: `infrastructure/terraform/iam.tf`

### ECS Task Execution Role

```hcl
# ============================================================================
# ECS Task Execution Role
# ============================================================================

resource "aws_iam_role" "ecs_execution_role" {
  name_prefix = "${local.name_prefix}-ecs-execution-"
  description = "ECS task execution role for ${var.service_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-execution-role"
      Component = "iam"
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for ECR and Secrets Manager access
resource "aws_iam_policy" "ecs_execution_custom" {
  name_prefix = "${local.name_prefix}-ecs-execution-custom-"
  description = "Custom policy for ECS task execution"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.app.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.shared_rds_identifier != "" ? [
          aws_secretsmanager_secret.db_credentials[0].arn
        ] : []
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        # ✅ 올바른 방법 (로컬 변수 사용)
        Resource = local.secrets_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-execution-custom"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_execution_custom" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_custom.arn
}
```

### ECS Task Role

```hcl
# ============================================================================
# ECS Task Role
# ============================================================================

resource "aws_iam_role" "ecs_task_role" {
  name_prefix = "${local.name_prefix}-ecs-task-"
  description = "ECS task role for ${var.service_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-ecs-task-role"
      Component = "iam"
    }
  )
}

# S3 access policy
resource "aws_iam_policy" "s3_access" {
  name_prefix = "${local.name_prefix}-s3-access-"
  description = "Policy for ${var.service_name} to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        # ✅ 로컬 변수 사용
        Resource = local.s3_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-s3-access"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# SQS access policy
resource "aws_iam_policy" "sqs_access" {
  name_prefix = "${local.name_prefix}-sqs-access-"
  description = "Policy for ${var.service_name} to access SQS queues"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          aws_sqs_queue.file_processing.arn,
          aws_sqs_queue.file_processing_dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        # ✅ 로컬 변수 사용
        Resource = local.sqs_key_arn
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-sqs-access"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_sqs" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.sqs_access.arn
}
```

---

## Step 8: 환경별 terraform.tfvars 작성

### Production 환경

**파일**: `infrastructure/terraform/environments/prod/terraform.tfvars`

```hcl
# Environment
environment = "prod"
aws_region  = "ap-northeast-2"

# Service
service_name = "fileflow"

# Shared RDS Configuration
shared_rds_identifier        = "prod-shared-mysql"
shared_rds_master_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:prod-shared-mysql-master-XXXXX"
shared_rds_security_group_id = "sg-xxxxxxxxxxxxx"

# Database
db_name     = "fileflow"
db_username = "fileflow_user"

# ECS Configuration
ecs_task_cpu       = "2048"
ecs_task_memory    = "4096"
ecs_desired_count  = 3
ecs_container_port = 8080

# Redis Configuration
redis_node_type       = "cache.t3.medium"
redis_num_cache_nodes = 2

# Tags
tags_owner       = "platform-team"
tags_cost_center = "engineering"
tags_team        = "platform-team"
```

### Staging 환경

**파일**: `infrastructure/terraform/environments/staging/terraform.tfvars`

```hcl
# Environment
environment = "staging"
aws_region  = "ap-northeast-2"

# Service
service_name = "fileflow"

# Shared RDS Configuration
shared_rds_identifier        = "staging-shared-mysql"
shared_rds_master_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:staging-shared-mysql-master-XXXXX"
shared_rds_security_group_id = "sg-xxxxxxxxxxxxx"

# Database
db_name     = "fileflow"
db_username = "fileflow_user"

# ECS Configuration
ecs_task_cpu       = "1024"
ecs_task_memory    = "2048"
ecs_desired_count  = 2
ecs_container_port = 8080

# Redis Configuration
redis_node_type       = "cache.t3.small"
redis_num_cache_nodes = 1

# Tags
tags_owner       = "platform-team"
tags_cost_center = "engineering"
tags_team        = "platform-team"
```

### Development 환경

**파일**: `infrastructure/terraform/environments/dev/terraform.tfvars`

```hcl
# Environment
environment = "dev"
aws_region  = "ap-northeast-2"

# Service
service_name = "fileflow"

# Shared RDS Configuration
shared_rds_identifier        = "dev-shared-mysql"
shared_rds_master_secret_arn = "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:dev-shared-mysql-master-XXXXX"
shared_rds_security_group_id = "sg-xxxxxxxxxxxxx"

# Database
db_name     = "fileflow"
db_username = "fileflow_user"

# ECS Configuration
ecs_task_cpu       = "512"
ecs_task_memory    = "1024"
ecs_desired_count  = 1
ecs_container_port = 8080

# Redis Configuration
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 1

# Tags
tags_owner       = "platform-team"
tags_cost_center = "engineering"
tags_team        = "platform-team"
```

---

## 검증

### 1. SSM Parameters 확인

```bash
# 모든 공유 리소스 확인
aws ssm get-parameters-by-path \
  --path /shared \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name,Value]' \
  --output table

# 특정 Parameter 확인
aws ssm get-parameter --name /shared/network/vpc-id --region ap-northeast-2
aws ssm get-parameter --name /shared/kms/s3-key-arn --region ap-northeast-2
```

### 2. Terraform 검증

```bash
cd {service-name}/infrastructure/terraform

# 초기화
terraform init

# 형식 확인
terraform fmt -recursive

# 구문 검증
terraform validate

# Plan 확인 (Dev)
terraform plan -var-file=environments/dev/terraform.tfvars
```

**기대 결과**:
- ✅ 모든 데이터 소스 정상 조회
- ✅ 모든 로컬 변수 정상 참조
- ✅ 예상 리소스 생성 개수 확인

### 3. data.tf 동작 확인

```bash
# Terraform console에서 테스트
terraform console -var-file=environments/dev/terraform.tfvars

# VPC ID 확인
> data.aws_ssm_parameter.vpc_id.value

# KMS Key ARN 확인
> data.aws_ssm_parameter.s3_key_arn.value

# Subnet IDs 확인
> split(",", data.aws_ssm_parameter.private_subnet_ids.value)
```

### 4. 보안 검증

```bash
# tfsec 스캔
tfsec .

# checkov 스캔
checkov -d .

# KMS 암호화 확인
grep -r "kms_key" *.tf
```

**기대 결과**:
- ✅ 모든 리소스가 적절한 KMS key 사용
- ✅ Secrets Manager로 민감 정보 저장
- ✅ Security Group 최소 권한

---

## 다음 단계

✅ **Application 프로젝트 설정 완료**

**다음 가이드**: [배포 가이드 (hybrid-05-deployment-guide.md)](hybrid-05-deployment-guide.md)

**다음 단계 내용**:
1. Terraform 검증 및 배포 실행
2. 배포 전 체크리스트
3. 배포 후 검증
4. CI/CD 통합 (GitHub Actions)
5. Atlantis 통합 (옵션)
6. PR 자동화 전략

---

## 트러블슈팅

### 문제 1: SSM Parameter를 찾을 수 없음

**증상**:
```
Error: reading SSM Parameter (/shared/network/vpc-id): ParameterNotFound
```

**원인**: Infrastructure 프로젝트에서 SSM Parameters가 생성되지 않음

**해결**:
```bash
# Infrastructure 프로젝트에서 SSM Parameters 확인
cd /Users/sangwon-ryu/infrastructure/terraform/network
terraform output

# SSM Parameter가 없는 경우 생성
terraform apply
```

### 문제 2: Shared RDS 접근 권한 없음

**증상**:
```
Error: security group rule already exists
```

**원인**: ECS Security Group이 이미 RDS Security Group에 추가됨

**해결**:
1. 기존 Security Group Rule 확인
2. 중복 생성 방지를 위해 `count` 조건 확인

### 문제 3: 환경별 tfvars 값 누락

**증상**:
```
Error: No value for required variable
```

**원인**: `terraform.tfvars`에 필수 변수 누락

**해결**:
1. `variables.tf`에서 필수 변수 확인
2. 각 환경의 `terraform.tfvars`에 값 추가

---

## 참고 자료

### 관련 문서
- [개요 및 시작하기](hybrid-01-overview.md)
- [아키텍처 설계](hybrid-02-architecture-design.md)
- [Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)
- [배포 가이드](hybrid-05-deployment-guide.md)

### Terraform 모듈
- `/terraform/modules/common-tags` - 공통 태그 모듈
- `/terraform/modules/cloudwatch-log-group` - Log Group 모듈
- `/terraform/modules/ecs-service` - ECS 서비스 모듈
- `/terraform/modules/s3-bucket` - S3 버킷 모듈

### AWS 문서
- [SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [KMS Key Management](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)
- [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)

---

**Last Updated**: 2025-10-22
**버전**: 1.0
