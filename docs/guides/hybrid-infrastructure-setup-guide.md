# 하이브리드 Terraform 인프라 구조 설정 가이드

**작성일**: 2025-10-21
**버전**: 1.0
**대상 독자**: DevOps 엔지니어, 플랫폼 팀, 새로운 서비스를 론칭하는 개발팀

---

## 📋 목차

1. [개요](#개요)
2. [아키텍처 설계](#아키텍처-설계)
3. [사전 요구사항](#사전-요구사항)
4. [Infrastructure 프로젝트 설정](#infrastructure-프로젝트-설정)
5. [Application 프로젝트 설정](#application-프로젝트-설정)
6. [검증 및 배포](#검증-및-배포)
7. [트러블슈팅](#트러블슈팅)
8. [모범 사례](#모범-사례)
9. [FAQ](#faq)

---

## 개요

### 하이브리드 인프라 구조란?

하이브리드 인프라 구조는 **중앙 집중식 관리**와 **프로젝트별 분산 관리**를 결합한 인프라 관리 방식입니다.

```
Infrastructure Repository          Application Repository
┌─────────────────────┐           ┌──────────────────────┐
│ 공유 인프라 (중앙)   │           │ 애플리케이션 인프라   │
│ - VPC, Subnets      │───────────│ - ECS, Task Def      │
│ - KMS Keys          │   SSM     │ - S3, SQS, Redis     │
│ - Shared RDS        │  Parameters│ - ALB, Auto Scaling  │
│ - ECR Repository    │           │ - Database Schema    │
└─────────────────────┘           └──────────────────────┘
```

### 왜 이 구조를 사용하는가?

#### 단일 Repository 방식 (Not Recommended)

```
infrastructure/
├── network/
├── kms/
├── service-a/
├── service-b/
└── service-c/
```

**단점**:
- 서비스별 배포 독립성 부족
- 인프라 변경이 모든 서비스에 영향
- 코드 충돌 및 Merge 복잡도 증가
- 애플리케이션 코드와 인프라 분리 불가

#### 멀티 Repository 방식 (Isolated)

```
service-a/infrastructure/  (모든 인프라 포함)
service-b/infrastructure/  (모든 인프라 포함)
service-c/infrastructure/  (모든 인프라 포함)
```

**단점**:
- VPC, KMS 등 공유 리소스 중복 생성
- 일관성 유지 어려움
- 비용 증가 (리소스 중복)
- 네트워크 복잡도 증가 (VPC Peering 필요)

#### 하이브리드 방식 (Recommended) ✅

```
infrastructure/            ← 공유 인프라 중앙 관리
service-a/infrastructure/  ← 서비스별 인프라
service-b/infrastructure/  ← 서비스별 인프라
service-c/infrastructure/  ← 서비스별 인프라
```

**장점**:
- ✅ 공유 리소스 중앙 관리 (VPC, KMS, 네트워크)
- ✅ 서비스별 독립적 배포 가능
- ✅ 애플리케이션 코드와 인프라 동기화
- ✅ 비용 절감 (공유 리소스 활용)
- ✅ 일관성 유지 (중앙 거버넌스)

### 적용 대상 프로젝트

#### 이 방식을 사용해야 하는 경우

- ✅ 마이크로서비스 아키텍처
- ✅ 여러 서비스가 동일한 네트워크 공유
- ✅ 서비스별 독립적 배포 필요
- ✅ 애플리케이션 코드와 인프라 동기화 필요
- ✅ Shared RDS 사용 (멀티 테넌트 데이터베이스)

#### 전용 인프라를 사용해야 하는 경우

- ❌ 단일 모놀리식 애플리케이션
- ❌ 완전히 격리된 환경 필요 (보안/규정 준수)
- ❌ 트래픽이 매우 높아 전용 RDS 필요
- ❌ 특수한 네트워크 구성 필요

---

## 아키텍처 설계

### Infrastructure 프로젝트 역할 (중앙 관리)

**위치**: `/Users/sangwon-ryu/infrastructure/terraform/`

#### 관리 대상 리소스

**1. Network (네트워크)**
- VPC 및 CIDR 블록 (`10.0.0.0/16`)
- Public Subnets (Multi-AZ, `/20`)
- Private Subnets (Multi-AZ, `/19`)
- Data Subnets (Multi-AZ, `/20`)
- Internet Gateway
- NAT Gateway
- Route Tables
- VPC Endpoints (S3, DynamoDB, ECR, Secrets Manager)

**2. KMS (암호화 키)**
- CloudWatch Logs 전용 KMS 키
- Secrets Manager 전용 KMS 키
- RDS 전용 KMS 키
- S3 전용 KMS 키
- SQS 전용 KMS 키
- SSM Parameter Store 전용 KMS 키
- ElastiCache 전용 KMS 키

**3. Shared RDS (공유 데이터베이스)**
- Multi-AZ MySQL 인스턴스
- Master credentials (Secrets Manager)
- DB Subnet Group
- Security Group
- Parameter Group
- Automated Backups
- Performance Insights

**4. ECR (컨테이너 레지스트리)**
- 서비스별 ECR 레포지토리
- Lifecycle 정책
- Image 스캔 설정

**5. SSM Parameters (공유 정보 Export)**

모든 공유 리소스는 SSM Parameter Store를 통해 Export됩니다:

```
/shared/network/vpc-id
/shared/network/public-subnet-ids
/shared/network/private-subnet-ids
/shared/network/data-subnet-ids
/shared/kms/cloudwatch-logs-key-arn
/shared/kms/secrets-manager-key-arn
/shared/kms/rds-key-arn
/shared/kms/s3-key-arn
/shared/kms/sqs-key-arn
/shared/kms/ssm-key-arn
/shared/kms/elasticache-key-arn
/shared/ecr/{service-name}-repository-url
```

### Application 프로젝트 역할 (분산 관리)

**위치**: `/Users/sangwon-ryu/{service-name}/infrastructure/terraform/`

#### 관리 대상 리소스

**1. ECS (컨테이너 오케스트레이션)**
- ECS Cluster
- ECS Service
- Task Definition
- Container Definition
- Auto Scaling Policy
- Security Groups

**2. Shared RDS 연결**
- Security Group Rule (ECS → RDS)
- Service-specific Database 생성
- Service-specific User 생성
- Database Credentials (Secrets Manager)

**3. ElastiCache Redis**
- Redis Replication Group
- Subnet Group
- Parameter Group
- Security Group

**4. S3 Buckets**
- Storage Bucket
- Logs Bucket
- Bucket Policies
- Lifecycle Rules

**5. SQS Queues**
- Standard/FIFO Queues
- Dead Letter Queues
- Queue Policies

**6. Application Load Balancer**
- ALB
- Target Groups
- Listener Rules
- Security Groups

**7. IAM Roles and Policies**
- ECS Task Execution Role
- ECS Task Role
- Service-specific Policies

### 데이터 흐름 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│ Infrastructure Repository (중앙 관리)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────┐   ┌────────────┐   ┌─────────────┐        │
│  │ VPC        │   │ KMS Keys   │   │ Shared RDS  │        │
│  │ 10.0.0.0/16│   │ 7 keys     │   │ prod-shared │        │
│  └─────┬──────┘   └─────┬──────┘   └──────┬──────┘        │
│        │                │                  │                │
│        └────────────────┴──────────────────┘                │
│                         │                                   │
│                   SSM Parameters                            │
│         /shared/network/*, /shared/kms/*                    │
│                         │                                   │
└─────────────────────────┼───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Application Repository (FileFlow)                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────┐                  │
│  │ data.tf (SSM Parameter 데이터 소스)   │                  │
│  ├──────────────────────────────────────┤                  │
│  │ data "aws_ssm_parameter" "vpc_id"    │                  │
│  │ data "aws_ssm_parameter" "kms_arns"  │                  │
│  └────────────┬─────────────────────────┘                  │
│               │                                             │
│               ▼                                             │
│  ┌──────────────────────────────────────┐                  │
│  │ locals.tf (값 참조)                   │                  │
│  ├──────────────────────────────────────┤                  │
│  │ vpc_id = data.aws_ssm_parameter...   │                  │
│  │ cloudwatch_key_arn = data.aws...    │                  │
│  └────────────┬─────────────────────────┘                  │
│               │                                             │
│               ▼                                             │
│  ┌────────────────────────────────────────────────┐        │
│  │ Application Resources                          │        │
│  ├────────────────────────────────────────────────┤        │
│  │ • ECS (local.vpc_id, local.private_subnet_ids)│        │
│  │ • Redis (local.elasticache_key_arn)           │        │
│  │ • S3 (local.s3_key_arn)                       │        │
│  │ • SQS (local.sqs_key_arn)                     │        │
│  │ • Database (Shared RDS connection)            │        │
│  └────────────────────────────────────────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Shared RDS 내부 구조:
┌─────────────────────────────────────┐
│ prod-shared-mysql                   │
├─────────────────────────────────────┤
│ Database: fileflow                  │
│ User: fileflow_user                 │
│ Privileges: CRUD, DDL               │
├─────────────────────────────────────┤
│ Database: authhub                   │
│ User: authhub_user                  │
│ Privileges: CRUD, DDL               │
├─────────────────────────────────────┤
│ Database: crawler                   │
│ User: crawler_user                  │
│ Privileges: CRUD, DDL               │
└─────────────────────────────────────┘
```

---

## 사전 요구사항

### 필수 소프트웨어

- **Terraform**: >= 1.5.0
- **AWS CLI**: >= 2.0
- **jq**: JSON 처리 (database 생성 스크립트 용)
- **mysql-client**: Shared RDS database 생성 용
- **Git**: 버전 관리

### AWS 권한

Infrastructure 프로젝트 배포에 필요한 권한:
- VPC, Subnet 생성/관리
- KMS 키 생성/관리
- RDS 인스턴스 생성/관리
- ECR 레포지토리 생성/관리
- SSM Parameter 생성/관리

Application 프로젝트 배포에 필요한 권한:
- ECS Cluster, Service, Task 생성/관리
- ElastiCache 생성/관리
- S3 Bucket 생성/관리
- SQS Queue 생성/관리
- ALB 생성/관리
- IAM Role, Policy 생성/관리
- Security Group 생성/관리
- Secrets Manager Secret 생성/관리
- SSM Parameter 읽기 (SSM Parameters에 접근)

### Infrastructure 프로젝트 사전 배포

**중요**: Application 프로젝트를 배포하기 전에 Infrastructure 프로젝트의 다음 모듈이 **반드시** 배포되어 있어야 합니다:

```bash
# 1. Network 모듈 배포
cd /Users/sangwon-ryu/infrastructure/terraform/network
terraform init
terraform apply

# 2. KMS 모듈 배포
cd /Users/sangwon-ryu/infrastructure/terraform/kms
terraform init
terraform apply

# 3. ECR 모듈 배포 (서비스별)
cd /Users/sangwon-ryu/infrastructure/terraform/ecr
# ECR 레포지토리 생성 (예: fileflow)
terraform init
terraform apply

# 4. Shared RDS 배포 (옵션)
cd /Users/sangwon-ryu/infrastructure/terraform/rds
terraform init
terraform apply
```

### 배포 확인

SSM Parameters가 생성되었는지 확인:

```bash
# 모든 공유 파라미터 조회
aws ssm get-parameters-by-path \
  --path /shared \
  --recursive \
  --region ap-northeast-2

# 특정 파라미터 확인
aws ssm get-parameter \
  --name /shared/network/vpc-id \
  --region ap-northeast-2
```

---

## Infrastructure 프로젝트 설정

### 디렉토리 구조

```
infrastructure/terraform/
├── network/              # VPC, Subnets, Route Tables
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf       # SSM Parameter exports
│   └── locals.tf
├── kms/                  # KMS Keys (7개)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf       # SSM Parameter exports
│   └── locals.tf
├── rds/                  # Shared RDS Instance
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── locals.tf
└── ecr/                  # ECR Repositories
    ├── fileflow/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf   # SSM Parameter exports
    ├── authhub/
    └── crawler/
```

### SSM Parameters 생성 방법

#### Network SSM Parameters

**파일**: `infrastructure/terraform/network/outputs.tf`

```hcl
# VPC ID
resource "aws_ssm_parameter" "vpc_id" {
  name        = "/shared/network/vpc-id"
  description = "VPC ID for cross-stack references"
  type        = "String"
  value       = aws_vpc.main.id

  tags = merge(
    local.required_tags,
    {
      Name      = "vpc-id-export"
      Component = "network"
    }
  )
}

# Public Subnet IDs
resource "aws_ssm_parameter" "public_subnet_ids" {
  name        = "/shared/network/public-subnet-ids"
  description = "Public subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.public[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "public-subnet-ids-export"
      Component = "network"
    }
  )
}

# Private Subnet IDs
resource "aws_ssm_parameter" "private_subnet_ids" {
  name        = "/shared/network/private-subnet-ids"
  description = "Private subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.private[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "private-subnet-ids-export"
      Component = "network"
    }
  )
}

# Data Subnet IDs (RDS, ElastiCache 용)
resource "aws_ssm_parameter" "data_subnet_ids" {
  name        = "/shared/network/data-subnet-ids"
  description = "Data subnet IDs for cross-stack references"
  type        = "StringList"
  value       = join(",", aws_subnet.data[*].id)

  tags = merge(
    local.required_tags,
    {
      Name      = "data-subnet-ids-export"
      Component = "network"
    }
  )
}
```

#### KMS SSM Parameters

**파일**: `infrastructure/terraform/kms/outputs.tf`

```hcl
# CloudWatch Logs KMS Key
resource "aws_ssm_parameter" "cloudwatch_logs_key_arn" {
  name        = "/shared/kms/cloudwatch-logs-key-arn"
  description = "CloudWatch Logs KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.cloudwatch-logs.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "cloudwatch-logs-key-arn-export"
      Component = "kms"
    }
  )
}

# Secrets Manager KMS Key
resource "aws_ssm_parameter" "secrets_manager_key_arn" {
  name        = "/shared/kms/secrets-manager-key-arn"
  description = "Secrets Manager KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.secrets-manager.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "secrets-manager-key-arn-export"
      Component = "kms"
    }
  )
}

# RDS KMS Key
resource "aws_ssm_parameter" "rds_key_arn" {
  name        = "/shared/kms/rds-key-arn"
  description = "RDS KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.rds.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-key-arn-export"
      Component = "kms"
    }
  )
}

# S3 KMS Key
resource "aws_ssm_parameter" "s3_key_arn" {
  name        = "/shared/kms/s3-key-arn"
  description = "S3 KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.s3.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "s3-key-arn-export"
      Component = "kms"
    }
  )
}

# SQS KMS Key
resource "aws_ssm_parameter" "sqs_key_arn" {
  name        = "/shared/kms/sqs-key-arn"
  description = "SQS KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.sqs.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "sqs-key-arn-export"
      Component = "kms"
    }
  )
}

# SSM Parameter Store KMS Key
resource "aws_ssm_parameter" "ssm_key_arn" {
  name        = "/shared/kms/ssm-key-arn"
  description = "SSM Parameter Store KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.ssm.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "ssm-key-arn-export"
      Component = "kms"
    }
  )
}

# ElastiCache KMS Key
resource "aws_ssm_parameter" "elasticache_key_arn" {
  name        = "/shared/kms/elasticache-key-arn"
  description = "ElastiCache KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.elasticache.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "elasticache-key-arn-export"
      Component = "kms"
    }
  )
}
```

#### ECR SSM Parameters

**파일**: `infrastructure/terraform/ecr/fileflow/outputs.tf`

```hcl
# ECR Repository URL
resource "aws_ssm_parameter" "ecr_repository_url" {
  name        = "/shared/ecr/fileflow-repository-url"
  description = "FileFlow ECR repository URL for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.repository_url

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-ecr-url-export"
      Component = "ecr"
    }
  )
}

# ECR Repository ARN
resource "aws_ssm_parameter" "ecr_repository_arn" {
  name        = "/shared/ecr/fileflow-repository-arn"
  description = "FileFlow ECR repository ARN for cross-stack references"
  type        = "String"
  value       = aws_ecr_repository.fileflow.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "fileflow-ecr-arn-export"
      Component = "ecr"
    }
  )
}
```

### Shared RDS 설정

#### Shared RDS 인스턴스 생성

**파일**: `infrastructure/terraform/rds/main.tf`

```hcl
# Random password for RDS master user
resource "random_password" "master" {
  length  = 32
  special = true
}

# Store master credentials in Secrets Manager
resource "aws_secretsmanager_secret" "rds_master" {
  name_prefix             = "${var.environment}-shared-mysql-master-"
  description             = "Master credentials for shared MySQL RDS instance"
  kms_key_id              = data.aws_ssm_parameter.secrets_manager_key_arn.value
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-master"
      Component = "rds"
    }
  )
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.master.result
    engine   = "mysql"
    host     = aws_db_instance.shared.endpoint
    port     = 3306
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "shared" {
  name       = "${var.environment}-shared-mysql-subnet-group"
  subnet_ids = split(",", data.aws_ssm_parameter.data_subnet_ids.value)

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-subnet-group"
      Component = "rds"
    }
  )
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.environment}-shared-mysql-"
  description = "Security group for shared MySQL RDS instance"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  # Allow MySQL from private subnets
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "Allow MySQL from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-sg"
      Component = "rds"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Instance
resource "aws_db_instance" "shared" {
  identifier = "${var.environment}-shared-mysql"

  # Engine
  engine               = "mysql"
  engine_version       = "8.0.42"
  instance_class       = var.environment == "prod" ? "db.t3.medium" : "db.t3.small"
  allocated_storage    = var.environment == "prod" ? 100 : 20
  max_allocated_storage = var.environment == "prod" ? 500 : 100
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id          = data.aws_ssm_parameter.rds_key_arn.value

  # Credentials
  username = "admin"
  password = random_password.master.result

  # Network
  db_subnet_group_name   = aws_db_subnet_group.shared.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability
  multi_az = var.environment == "prod"

  # Backup
  backup_retention_period = var.environment == "prod" ? 7 : 3
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  skip_final_snapshot    = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.environment}-shared-mysql-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Performance Insights
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  performance_insights_enabled    = true
  performance_insights_kms_key_id = data.aws_ssm_parameter.cloudwatch_logs_key_arn.value

  # Parameter Group
  parameter_group_name = aws_db_parameter_group.shared.name

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql"
      Component = "rds"
    }
  )
}

# DB Parameter Group
resource "aws_db_parameter_group" "shared" {
  name_prefix = "${var.environment}-shared-mysql-"
  family      = "mysql8.0"
  description = "Parameter group for shared MySQL RDS instance"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = var.environment == "prod" ? "200" : "100"
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${var.environment}-shared-mysql-params"
      Component = "rds"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
```

#### Shared RDS Outputs

**파일**: `infrastructure/terraform/rds/outputs.tf`

```hcl
output "db_instance_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.shared.identifier
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.shared.endpoint
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.shared.arn
}

output "db_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "master_secret_arn" {
  description = "ARN of master credentials secret"
  value       = aws_secretsmanager_secret.rds_master.arn
}

# SSM Parameter Export for Application projects
resource "aws_ssm_parameter" "shared_rds_identifier" {
  name        = "/shared/rds/${var.environment}/identifier"
  description = "Shared RDS instance identifier"
  type        = "String"
  value       = aws_db_instance.shared.identifier

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-identifier-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_endpoint" {
  name        = "/shared/rds/${var.environment}/endpoint"
  description = "Shared RDS instance endpoint"
  type        = "String"
  value       = aws_db_instance.shared.endpoint

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-endpoint-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_security_group_id" {
  name        = "/shared/rds/${var.environment}/security-group-id"
  description = "Shared RDS security group ID"
  type        = "String"
  value       = aws_security_group.rds.id

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-sg-export"
      Component = "rds"
    }
  )
}

resource "aws_ssm_parameter" "shared_rds_master_secret_arn" {
  name        = "/shared/rds/${var.environment}/master-secret-arn"
  description = "Shared RDS master credentials secret ARN"
  type        = "String"
  value       = aws_secretsmanager_secret.rds_master.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "shared-rds-master-secret-export"
      Component = "rds"
    }
  )
}
```

---

## Application 프로젝트 설정

### Step 1: 프로젝트 구조 생성

```bash
cd /Users/sangwon-ryu/{service-name}

# 디렉토리 생성
mkdir -p infrastructure/terraform/{environments/{dev,staging,prod},modules}
mkdir -p infrastructure/scripts
mkdir -p .github/workflows
```

**결과 구조**:

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

### Step 2: data.tf 작성 (SSM Parameter 데이터 소스)

**파일**: `infrastructure/terraform/data.tf`

FileFlow 프로젝트의 실제 예제:

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
    Tier = "private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  tags = {
    Tier = "public"
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
  name = "/shared/ecr/fileflow-repository-url"
}

# ============================================================================
# Shared RDS Information (from SSM Parameters - Optional)
# ============================================================================

# Shared RDS를 사용하는 경우 추가
data "aws_ssm_parameter" "shared_rds_identifier" {
  name = "/shared/rds/${var.environment}/identifier"
}

data "aws_ssm_parameter" "shared_rds_security_group_id" {
  name = "/shared/rds/${var.environment}/security-group-id"
}

data "aws_ssm_parameter" "shared_rds_master_secret_arn" {
  name = "/shared/rds/${var.environment}/master-secret-arn"
}
```

### Step 3: locals.tf 작성 (SSM Parameter 값 참조)

**파일**: `infrastructure/terraform/locals.tf`

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
  shared_rds_identifier        = try(data.aws_ssm_parameter.shared_rds_identifier.value, "")
  shared_rds_security_group_id = try(data.aws_ssm_parameter.shared_rds_security_group_id.value, "")
  shared_rds_master_secret_arn = try(data.aws_ssm_parameter.shared_rds_master_secret_arn.value, "")

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

### Step 4: variables.tf 작성

**파일**: `infrastructure/terraform/variables.tf`

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

### Step 5: database.tf 작성 (Shared RDS 연결)

**파일**: `infrastructure/terraform/database.tf`

FileFlow 프로젝트의 실제 예제 (완전한 코드):

```hcl
# ============================================================================
# Database Configuration (Shared RDS)
# ============================================================================

# Data source to get shared RDS instance
data "aws_db_instance" "shared" {
  db_instance_identifier = var.shared_rds_identifier
}

# Security group rule to allow ECS tasks to access shared RDS
resource "aws_security_group_rule" "shared_rds_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.shared_rds_security_group_id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow MySQL access from FileFlow ECS tasks"
}

# Random password for service-specific database user
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Store service-specific database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
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
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    database = var.db_name
    host     = data.aws_db_instance.shared.endpoint
    port     = 3306
  })
}

# MySQL database and user creation using null_resource
resource "null_resource" "create_database_and_user" {
  # Trigger on database name or username changes
  triggers = {
    db_name      = var.db_name
    db_username  = var.db_username
    rds_endpoint = data.aws_db_instance.shared.endpoint
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
      RDS_HOST="${data.aws_db_instance.shared.endpoint}"

      # Create database and user
      mysql -h "$RDS_HOST" -u "$MASTER_USER" -p"$MASTER_PASS" << 'SQL'
        -- Create database if not exists
        CREATE DATABASE IF NOT EXISTS ${var.db_name}
          CHARACTER SET utf8mb4
          COLLATE utf8mb4_unicode_ci;

        -- Create user if not exists
        CREATE USER IF NOT EXISTS '${var.db_username}'@'%'
          IDENTIFIED BY '${random_password.db_password.result}';

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
          aws_secretsmanager_secret.db_credentials.arn,
          "${aws_secretsmanager_secret.db_credentials.arn}:*"
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
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.db_access.arn
}

# CloudWatch Log Group for database query logs (optional)
resource "aws_cloudwatch_log_group" "database_queries" {
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

### Step 6: 리소스별 KMS Key 매핑

**중요**: 각 리소스는 **전용 KMS key**를 사용해야 합니다.

| 리소스 타입 | KMS Key 로컬 변수 | 사용 예제 |
|------------|-------------------|----------|
| CloudWatch Logs | `local.cloudwatch_key_arn` | Log Groups |
| Secrets Manager | `local.secrets_key_arn` | DB Credentials, API Keys |
| RDS | `local.rds_key_arn` | RDS Storage Encryption |
| S3 | `local.s3_key_arn` | S3 Bucket Encryption |
| SQS | `local.sqs_key_arn` | SQS Queue Encryption |
| SSM Parameters | `local.ssm_key_arn` | Secure String Parameters |
| ElastiCache | `local.elasticache_key_arn` | Redis at-rest encryption |

#### Redis 예제

**파일**: `infrastructure/terraform/redis.tf`

```hcl
module "redis" {
  source = "../modules/elasticache"

  name               = "${local.name_prefix}-redis"
  engine_version     = "7.0"
  node_type          = var.redis_node_type
  num_cache_nodes    = var.redis_num_cache_nodes
  parameter_group_family = "redis7"

  # Network
  subnet_ids         = local.data_subnet_ids
  security_group_ids = [aws_security_group.redis.id]

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled         = true
  kms_key_id                 = local.elasticache_key_arn  # ✅ ElastiCache 전용 키

  # Tags
  common_tags = local.required_tags
}
```

#### SQS 예제

**파일**: `infrastructure/terraform/sqs.tf`

```hcl
module "file_processing_queue" {
  source = "../modules/sqs"

  name                      = "${local.name_prefix}-file-processing"
  message_retention_seconds = 1209600  # 14 days
  visibility_timeout_seconds = 300

  # Encryption
  kms_master_key_id = local.sqs_key_arn  # ✅ SQS 전용 키

  # Dead Letter Queue
  enable_dlq               = true
  max_receive_count        = 3
  dlq_message_retention_seconds = 1209600

  # Tags
  common_tags = local.required_tags
}
```

#### S3 예제

**파일**: `infrastructure/terraform/s3.tf`

```hcl
module "storage_bucket" {
  source = "../modules/s3-bucket"

  bucket_name = "${local.name_prefix}-storage"

  # Encryption
  enable_encryption     = true
  kms_master_key_id    = local.s3_key_arn  # ✅ S3 전용 키

  # Versioning
  enable_versioning = var.environment == "prod"

  # Lifecycle
  lifecycle_rules = [
    {
      id      = "archive-old-files"
      enabled = true

      transition = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
        },
        {
          days          = 365
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = 2555  # 7 years
      }
    }
  ]

  # Tags
  common_tags = local.required_tags
}
```

### Step 7: iam.tf 작성 (로컬 변수 참조)

**중요**: Remote state 대신 로컬 변수 사용

**파일**: `infrastructure/terraform/iam.tf`

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
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        # ❌ 잘못된 방법 (remote state 사용)
        # Resource = data.terraform_remote_state.kms.outputs.secrets_manager_key_arn

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
          module.storage_bucket.bucket_arn,
          "${module.storage_bucket.bucket_arn}/*"
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
          module.file_processing_queue.queue_arn,
          module.file_upload_queue.queue_arn,
          module.file_completion_queue.queue_arn
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

### Step 8: 환경별 terraform.tfvars 작성

#### Production 환경

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

#### Staging 환경

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

#### Development 환경

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

## 검증 및 배포

### Terraform 검증

```bash
cd {service-name}/infrastructure/terraform

# 1. 초기화
terraform init

# 2. 형식 확인
terraform fmt -recursive

# 3. 구문 검증
terraform validate

# 4. Plan 확인 (Dev 환경)
terraform plan -var-file=environments/dev/terraform.tfvars

# 5. Plan 확인 (Staging 환경)
terraform plan -var-file=environments/staging/terraform.tfvars

# 6. Plan 확인 (Prod 환경)
terraform plan -var-file=environments/prod/terraform.tfvars
```

### 배포 전 체크리스트

- [ ] **Infrastructure 프로젝트 배포 완료**
  - [ ] Network 모듈 배포 완료
  - [ ] KMS 모듈 배포 완료
  - [ ] Shared RDS 배포 완료 (사용 시)
  - [ ] ECR Repository 배포 완료

- [ ] **SSM Parameters 확인**
  ```bash
  # 모든 SSM Parameters 확인
  aws ssm get-parameters-by-path --path /shared --recursive

  # 특정 Parameter 확인
  aws ssm get-parameter --name /shared/network/vpc-id
  aws ssm get-parameter --name /shared/kms/s3-key-arn
  ```

- [ ] **Application Terraform 파일 준비**
  - [ ] `data.tf`: 모든 필요한 SSM Parameter 데이터 소스 추가
  - [ ] `locals.tf`: 모든 SSM Parameter 값 참조
  - [ ] `database.tf`: Shared RDS 연결 (사용 시)
  - [ ] 모든 리소스: 올바른 KMS key 사용
  - [ ] `iam.tf`: Remote state 제거, 로컬 변수 사용
  - [ ] 환경별 `terraform.tfvars` 작성 완료

- [ ] **Terraform 검증**
  - [ ] `terraform init` 성공
  - [ ] `terraform validate` 통과
  - [ ] `terraform plan` 검토 완료 (예상 리소스 생성 확인)

- [ ] **보안 검증**
  - [ ] 모든 KMS 암호화 활성화
  - [ ] Secrets Manager 사용 (하드코딩 없음)
  - [ ] Security Group 최소 권한
  - [ ] IAM 역할 최소 권한

### 배포 실행

```bash
# Dev 환경 배포
terraform apply -var-file=environments/dev/terraform.tfvars

# Staging 환경 배포
terraform apply -var-file=environments/staging/terraform.tfvars

# Prod 환경 배포 (수동 확인 필요)
terraform apply -var-file=environments/prod/terraform.tfvars
```

### 배포 후 검증

```bash
# 1. ECS 서비스 상태 확인
aws ecs describe-services \
  --cluster fileflow-dev-cluster \
  --services fileflow-dev-service \
  --region ap-northeast-2

# 2. Task 상태 확인
aws ecs list-tasks \
  --cluster fileflow-dev-cluster \
  --service-name fileflow-dev-service \
  --region ap-northeast-2

# 3. RDS 연결 확인 (ECS Exec)
aws ecs execute-command \
  --cluster fileflow-dev-cluster \
  --task <task-id> \
  --container fileflow \
  --command "/bin/sh" \
  --interactive

# Container 내부에서
mysql -h <rds-endpoint> -u fileflow_user -p

# 4. Redis 연결 확인
redis-cli -h <redis-endpoint> ping

# 5. ALB Health Check 확인
curl http://<alb-dns-name>/actuator/health
```

---

## 트러블슈팅

### SSM Parameter를 찾을 수 없음

**증상**:
```
Error: error reading SSM Parameter (/shared/network/vpc-id): ParameterNotFound
```

**원인**: Infrastructure 프로젝트의 SSM Parameter가 생성되지 않음

**해결**:

```bash
# 1. Infrastructure 프로젝트로 이동
cd /Users/sangwon-ryu/infrastructure/terraform/network

# 2. Outputs에 SSM Parameter export가 있는지 확인
cat outputs.tf | grep aws_ssm_parameter

# 3. SSM Parameter가 없다면 추가 (이 가이드의 예제 참고)
# outputs.tf에 SSM Parameter 리소스 추가

# 4. Terraform 적용
terraform init
terraform apply

# 5. SSM Parameter 생성 확인
aws ssm get-parameter --name /shared/network/vpc-id
```

### Shared RDS 접근 권한 없음

**증상**: ECS task에서 RDS 연결 실패

**원인**:
1. Security Group 규칙 누락
2. IAM 정책에 Secrets Manager 접근 권한 없음
3. KMS key 정책 문제

**해결**:

```bash
# 1. Security Group 규칙 확인
aws ec2 describe-security-group-rules \
  --filter "Name=group-id,Values=<rds-sg-id>"

# 2. ECS Task Security Group에서 RDS로 3306 포트 열기
# database.tf의 aws_security_group_rule 확인

# 3. IAM 정책 확인
aws iam get-role-policy \
  --role-name fileflow-dev-ecs-task-role \
  --policy-name fileflow-dev-db-access

# 4. Secrets Manager 접근 테스트 (ECS Exec)
aws secretsmanager get-secret-value \
  --secret-id <secret-arn> \
  --region ap-northeast-2
```

### KMS Key 권한 오류

**증상**:
```
Error: KMS.NotFoundException
Error: AccessDeniedException
```

**원인**: KMS key 정책에 서비스 principal 없음

**해결**:

```bash
# 1. KMS key ARN 확인
aws ssm get-parameter --name /shared/kms/s3-key-arn

# 2. KMS key 정책 확인
aws kms get-key-policy \
  --key-id <key-id> \
  --policy-name default

# 3. KMS key 정책에 서비스 principal 추가 (Infrastructure 프로젝트)
cd /Users/sangwon-ryu/infrastructure/terraform/kms

# main.tf의 KMS key 정책에 추가:
# - S3 key: s3.amazonaws.com
# - SQS key: sqs.amazonaws.com
# - ElastiCache key: elasticache.amazonaws.com

terraform apply
```

### Terraform State 잠금 오류

**증상**:
```
Error: Error acquiring the state lock
```

**원인**: 다른 Terraform 프로세스가 실행 중이거나 비정상 종료

**해결**:

```bash
# 1. DynamoDB Lock 테이블 확인
aws dynamodb scan \
  --table-name terraform-lock \
  --region ap-northeast-2

# 2. Lock 강제 해제 (주의: 다른 프로세스 없는지 확인)
terraform force-unlock <lock-id>

# 3. Lock이 계속 발생하면 DynamoDB 테이블에서 직접 삭제
aws dynamodb delete-item \
  --table-name terraform-lock \
  --key '{"LockID": {"S": "<lock-id>"}}'
```

### 모듈을 찾을 수 없음

**증상**:
```
Error: Module not installed
```

**원인**: Infrastructure 프로젝트의 모듈이 복사되지 않음

**해결**:

```bash
# 1. Infrastructure 프로젝트에서 모듈 복사
cp -r /Users/sangwon-ryu/infrastructure/terraform/modules/{alb,ecs-service,elasticache,s3-bucket,sqs} \
      /Users/sangwon-ryu/{service-name}/infrastructure/terraform/modules/

# 2. Terraform 재초기화
cd /Users/sangwon-ryu/{service-name}/infrastructure/terraform
terraform init
```

### Database 생성 스크립트 실패

**증상**:
```
Error: local-exec provisioner error
mysql: command not found
```

**원인**: mysql-client가 설치되지 않음

**해결**:

```bash
# macOS
brew install mysql-client

# Ubuntu/Debian
sudo apt-get install mysql-client

# Amazon Linux
sudo yum install mysql

# 환경 변수 추가 (macOS)
echo 'export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## 모범 사례

### 명명 규칙

#### SSM Parameter 경로
```
/shared/{category}/{resource-name}

예제:
/shared/network/vpc-id
/shared/kms/s3-key-arn
/shared/ecr/fileflow-repository-url
/shared/rds/prod/identifier
```

#### Shared RDS 인스턴스
```
{environment}-shared-mysql

예제:
dev-shared-mysql
staging-shared-mysql
prod-shared-mysql
```

#### Database 이름
```
{service-name}

예제:
fileflow
authhub
crawler

# 짧고 명확하게 (특수문자 없이)
```

#### Database 사용자
```
{service-name}_user

예제:
fileflow_user
authhub_user
crawler_user
```

#### 리소스 네이밍
```
{service-name}-{environment}-{resource-type}

예제:
fileflow-prod-cluster
fileflow-prod-ecs-tasks-sg
fileflow-prod-storage-bucket
```

### 보안

#### Secrets 관리
- ✅ **Secrets Manager 사용**: 모든 민감 정보 (DB 패스워드, API 키)
- ✅ **KMS 암호화**: Secrets Manager에 KMS key 지정
- ❌ **하드코딩 금지**: Terraform 코드나 환경 변수에 패스워드 하드코딩 금지
- ✅ **최소 권한**: IAM 정책은 필요한 권한만 부여
- ✅ **Rotation**: Secrets Manager automatic rotation 활성화 (가능 시)

#### KMS Key 정책
- ✅ **리소스별 분리**: CloudWatch, S3, SQS, RDS 등 전용 키 사용
- ✅ **Key Rotation**: `enable_key_rotation = true`
- ✅ **Deletion Protection**: `deletion_window_in_days = 30` (prod)
- ✅ **Principal 명시**: 서비스별 principal 명확히 지정

#### Security Group
- ✅ **최소 권한**: 필요한 포트만 개방
- ✅ **소스 제한**: CIDR 대신 Security Group ID 참조
- ✅ **설명 추가**: 각 규칙에 `description` 추가
- ❌ **0.0.0.0/0 지양**: 불필요한 전역 개방 금지

#### IAM 역할
- ✅ **최소 권한 원칙**: 필요한 권한만 부여
- ✅ **리소스 ARN 명시**: `"Resource": "*"` 지양
- ✅ **조건 추가**: 가능한 경우 `Condition` 블록 사용
- ✅ **역할 분리**: Execution Role과 Task Role 분리

### 비용 최적화

#### Shared RDS 활용
- ✅ **멀티 테넌트**: 여러 서비스가 하나의 RDS 인스턴스 공유
- ✅ **적절한 인스턴스 크기**: 환경별 인스턴스 크기 조정
  - Dev: `db.t3.small`
  - Staging: `db.t3.medium`
  - Prod: `db.t3.large` ~ `db.r6g.xlarge`
- ✅ **Storage Auto Scaling**: `max_allocated_storage` 설정
- ❌ **과도한 백업 보관 지양**: 백업 보관 기간 적절히 설정 (7일)

#### ECS Auto Scaling
- ✅ **Target Tracking**: CPU/Memory 기반 Auto Scaling
- ✅ **환경별 범위**: Dev는 1~3, Prod는 2~10
- ✅ **Scale-in 보호**: Prod 환경에서 최소 태스크 수 유지

#### S3 Lifecycle
- ✅ **Lifecycle Rules**: 오래된 파일 자동 아카이빙
  - 90일: Standard → Standard-IA
  - 365일: Standard-IA → Glacier
  - 7년: Glacier → Expiration
- ✅ **Intelligent Tiering**: 액세스 패턴에 따라 자동 이동

#### CloudWatch Logs
- ✅ **보존 기간 설정**: 7~14일 (환경별)
- ✅ **S3 Export**: 장기 보관이 필요한 로그는 S3로 Export
- ❌ **무제한 보관 지양**: 비용 증가 원인

### 유지보수성

#### 일관된 디렉토리 구조
```
{service-name}/infrastructure/terraform/
├── environments/
│   ├── dev/terraform.tfvars
│   ├── staging/terraform.tfvars
│   └── prod/terraform.tfvars
├── modules/
├── data.tf
├── locals.tf
├── variables.tf
├── provider.tf
├── database.tf
├── ecs.tf
├── redis.tf
├── s3.tf
├── sqs.tf
├── alb.tf
├── iam.tf
└── outputs.tf
```

#### 주석 작성
```hcl
# ============================================================================
# Database Configuration (Shared RDS)
# ============================================================================
# This configuration connects to the shared RDS instance and creates
# a service-specific database and user with limited privileges.
#
# Privileges granted:
# - SELECT, INSERT, UPDATE, DELETE (DML)
# - CREATE, DROP, INDEX, ALTER (DDL)
#
# Security:
# - Credentials stored in Secrets Manager
# - KMS encryption enabled
# - Security group restricts access to ECS tasks only
# ============================================================================

resource "aws_security_group_rule" "shared_rds_from_ecs" {
  # ...
}
```

#### 모듈화
- ✅ **재사용 가능한 모듈**: 공통 패턴 모듈화
- ✅ **버전 관리**: 모듈 버전 명시 (`version = "1.0.0"`)
- ✅ **문서화**: 각 모듈에 `README.md` 추가
- ✅ **예제 제공**: `examples/` 디렉토리에 사용 예제

#### 문서화
- ✅ **README.md**: 프로젝트 개요, 배포 방법
- ✅ **CHANGELOG.md**: 버전별 변경 사항
- ✅ **아키텍처 다이어그램**: ASCII art 또는 이미지
- ✅ **트러블슈팅 가이드**: 자주 발생하는 문제 해결 방법

### Git 워크플로

#### 브랜치 전략
```
main (production)
├── develop (staging)
│   ├── feature/KAN-XXX-description
│   └── hotfix/KAN-YYY-description
```

#### 커밋 메시지
```bash
# 형식
feat: Add Shared RDS connection (KAN-153)
fix: Correct KMS key reference in S3 module (KAN-155)
docs: Update hybrid infrastructure guide

# 예제
feat: Add FileFlow database.tf with shared RDS connection
- Security group rule for ECS → RDS
- Database and user creation with null_resource
- IAM policy for database credentials access

fix: Use local.secrets_key_arn instead of remote state in iam.tf
- Removed data.terraform_remote_state.kms
- Updated all KMS key references to use locals

docs: Add troubleshooting section for SSM Parameter errors
- Steps to verify SSM Parameters
- How to recreate missing parameters
```

#### Pull Request 체크리스트
- [ ] `terraform fmt -recursive` 실행
- [ ] `terraform validate` 통과
- [ ] `terraform plan` 검토 완료
- [ ] 보안 스캔 통과 (tfsec, checkov)
- [ ] 주석 및 문서 업데이트
- [ ] 관련 Jira 태스크 링크

---

## FAQ

### Q: 언제 Shared RDS를 사용하고 언제 전용 RDS를 사용해야 하나요?

**A**: 다음 기준으로 판단하세요.

**Shared RDS 사용 (권장)**:
- ✅ 초기 단계 서비스 (MVP)
- ✅ 트래픽이 낮거나 중간 수준
- ✅ 데이터베이스 격리가 필수가 아님
- ✅ 비용 절감이 중요
- ✅ 여러 마이크로서비스 통합 관리

**전용 RDS 사용**:
- ❌ 대규모 트래픽 (>10,000 QPS)
- ❌ 특수한 RDS 설정 필요 (Parameter Group, Engine Version)
- ❌ 완전한 데이터 격리 필요 (보안/규정 준수)
- ❌ 독립적인 확장 필요
- ❌ 다른 서비스와 성능 격리 필요

**마이그레이션 경로**:
초기에는 Shared RDS로 시작 → 트래픽 증가 시 전용 RDS로 마이그레이션

### Q: SSM Parameter vs Terraform Remote State, 어떤 것을 사용해야 하나요?

**A**: 하이브리드 구조에서는 **SSM Parameter 권장**.

| 기준 | SSM Parameter | Terraform Remote State |
|-----|--------------|----------------------|
| **런타임 참조** | ✅ 가능 (애플리케이션에서 직접 조회) | ❌ 불가능 |
| **AWS 서비스 통합** | ✅ 네이티브 통합 | ❌ Terraform에서만 |
| **버전 관리** | ✅ 자동 버전 관리 | ❌ State 파일 의존 |
| **암호화** | ✅ KMS 암호화 지원 | ⚠️ S3 백엔드 암호화만 |
| **Terraform 의존성** | ✅ 의존성 없음 (단방향) | ❌ 양방향 의존성 (복잡도 증가) |
| **변경 전파** | ✅ 즉시 반영 | ❌ State refresh 필요 |

**SSM Parameter 예제**:
```hcl
# Infrastructure 프로젝트 (Export)
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/shared/network/vpc-id"
  value = aws_vpc.main.id
}

# Application 프로젝트 (Import)
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
}
```

**Remote State 예제** (권장하지 않음):
```hcl
# Application 프로젝트
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "tfstate-bucket"
    key    = "network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
}
```

### Q: 여러 환경(dev/staging/prod)을 어떻게 관리하나요?

**A**: 환경별 tfvars 파일 + 환경별 Shared RDS 인스턴스 사용.

**디렉토리 구조**:
```
infrastructure/terraform/
├── environments/
│   ├── dev/terraform.tfvars
│   ├── staging/terraform.tfvars
│   └── prod/terraform.tfvars
└── (공통 .tf 파일)
```

**환경별 Shared RDS 인스턴스**:
```
dev-shared-mysql        ← Dev 환경 서비스들 공유
staging-shared-mysql    ← Staging 환경 서비스들 공유
prod-shared-mysql       ← Prod 환경 서비스들 공유
```

**환경별 배포**:
```bash
# Dev 배포
terraform apply -var-file=environments/dev/terraform.tfvars

# Staging 배포
terraform apply -var-file=environments/staging/terraform.tfvars

# Prod 배포
terraform apply -var-file=environments/prod/terraform.tfvars
```

**환경별 리소스 크기**:

| 리소스 | Dev | Staging | Prod |
|--------|-----|---------|------|
| **ECS Task** | 512 CPU / 1GB RAM | 1024 CPU / 2GB RAM | 2048 CPU / 4GB RAM |
| **RDS** | db.t3.small | db.t3.medium | db.t3.large |
| **Redis** | cache.t3.micro | cache.t3.small | cache.t3.medium |
| **ECS Desired Count** | 1 | 2 | 3 |

### Q: 기존 전용 RDS를 Shared RDS로 마이그레이션하려면?

**A**: 다음 단계를 따르세요.

**1. 데이터 백업**
```bash
# RDS 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier fileflow-prod-db \
  --db-snapshot-identifier fileflow-prod-db-pre-migration-$(date +%Y%m%d)

# 또는 mysqldump
mysqldump -h <old-rds-endpoint> -u admin -p \
  --databases fileflow \
  --single-transaction \
  --routines \
  --triggers \
  > fileflow_backup_$(date +%Y%m%d).sql
```

**2. Shared RDS에 database 및 user 생성**
```sql
-- Shared RDS에 연결
mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com -u admin -p

-- Database 생성
CREATE DATABASE IF NOT EXISTS fileflow
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- User 생성
CREATE USER IF NOT EXISTS 'fileflow_user'@'%'
  IDENTIFIED BY '<password>';

-- 권한 부여
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
  ON fileflow.* TO 'fileflow_user'@'%';

FLUSH PRIVILEGES;
```

**3. 데이터 마이그레이션**
```bash
# mysqldump로 백업한 경우
mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com \
  -u fileflow_user -p fileflow < fileflow_backup_20251021.sql

# 또는 AWS DMS 사용 (대용량 데이터)
# https://aws.amazon.com/dms/
```

**4. 애플리케이션 연결 문자열 업데이트**

Terraform `database.tf` 수정:
```hcl
# 기존 전용 RDS (제거)
# resource "aws_db_instance" "fileflow" { ... }

# Shared RDS 연결 (추가)
data "aws_db_instance" "shared" {
  db_instance_identifier = var.shared_rds_identifier
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = "fileflow_user"
    password = random_password.db_password.result
    database = "fileflow"
    host     = data.aws_db_instance.shared.endpoint  # ← Shared RDS endpoint
    port     = 3306
  })
}
```

**5. 검증**
```bash
# ECS task에서 새 RDS 연결 확인
aws ecs execute-command \
  --cluster fileflow-prod-cluster \
  --task <task-id> \
  --container fileflow \
  --command "/bin/sh" \
  --interactive

# Container 내부에서
mysql -h prod-shared-mysql.xxxxx.ap-northeast-2.rds.amazonaws.com \
  -u fileflow_user -p

# 데이터 확인
USE fileflow;
SHOW TABLES;
SELECT COUNT(*) FROM <table-name>;
```

**6. 전용 RDS 제거**

검증 완료 후:
```bash
# 1. 최종 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier fileflow-prod-db \
  --db-snapshot-identifier fileflow-prod-db-final-$(date +%Y%m%d)

# 2. RDS 인스턴스 삭제
terraform destroy -target=aws_db_instance.fileflow
```

### Q: SSM Parameter가 변경되면 Application Terraform에 어떻게 반영되나요?

**A**: SSM Parameter 변경 시 Application Terraform `plan`에서 자동 감지됩니다.

**시나리오**: VPC ID가 변경된 경우

```bash
# Infrastructure 프로젝트에서 VPC 재생성
cd /Users/sangwon-ryu/infrastructure/terraform/network
terraform apply
# 새로운 VPC ID: vpc-new123
# SSM Parameter /shared/network/vpc-id 자동 업데이트

# Application 프로젝트에서 Plan 실행
cd /Users/sangwon-ryu/fileflow/infrastructure/terraform
terraform plan

# 출력:
# ~ resource "aws_security_group" "ecs_tasks" {
#     ~ vpc_id = "vpc-old456" -> "vpc-new123" (forces replacement)
#   }
```

**중요**: SSM Parameter 변경은 Application 리소스 재생성을 유발할 수 있으므로, 신중하게 계획해야 합니다.

### Q: 하나의 Application 프로젝트에서 여러 서비스를 관리할 수 있나요?

**A**: 가능하지만 권장하지 않습니다.

**권장하지 않는 이유**:
- ❌ 서비스별 독립적 배포 불가
- ❌ Terraform state 복잡도 증가
- ❌ 변경 영향 범위 불명확
- ❌ 팀 간 코드 충돌 가능성

**권장 구조** (서비스별 분리):
```
fileflow/infrastructure/terraform/     ← FileFlow 서비스만
authhub/infrastructure/terraform/      ← AuthHub 서비스만
crawler/infrastructure/terraform/      ← Crawler 서비스만
```

**예외** (모노레포 구조가 필요한 경우):
- Workspace를 사용하여 서비스별 state 분리
- 디렉토리 구조로 서비스 분리

```
infrastructure/
├── services/
│   ├── fileflow/
│   │   ├── main.tf
│   │   └── ...
│   ├── authhub/
│   │   ├── main.tf
│   │   └── ...
│   └── crawler/
│       ├── main.tf
│       └── ...
```

### Q: Terraform Module을 Infrastructure 프로젝트에서 참조하려면?

**A**: 두 가지 방법이 있습니다.

**방법 1: 모듈 복사** (권장)
```bash
# Infrastructure 프로젝트에서 Application 프로젝트로 복사
cp -r /Users/sangwon-ryu/infrastructure/terraform/modules/{alb,ecs-service,elasticache,s3-bucket,sqs} \
      /Users/sangwon-ryu/fileflow/infrastructure/terraform/modules/

# Application Terraform에서 사용
module "storage_bucket" {
  source = "../modules/s3-bucket"
  # ...
}
```

**장점**:
- ✅ 독립적 버전 관리
- ✅ Infrastructure 프로젝트 변경에 영향 없음
- ✅ 배포 속도 빠름

**단점**:
- ❌ 모듈 중복
- ❌ 업데이트 수동 동기화 필요

**방법 2: Git 모듈 참조**
```hcl
module "storage_bucket" {
  source = "git::https://github.com/your-org/infrastructure.git//terraform/modules/s3-bucket?ref=v1.0.0"
  # ...
}
```

**장점**:
- ✅ 모듈 중복 없음
- ✅ 버전 관리 명확

**단점**:
- ❌ 네트워크 의존성
- ❌ 배포 속도 느림
- ❌ Private repository 접근 권한 필요

---

## 참고 자료

### 내부 문서
- **Infrastructure 프로젝트**: `/Users/sangwon-ryu/infrastructure/CLAUDE.md`
- **FileFlow 마이그레이션 계획**: `/Users/sangwon-ryu/infrastructure/FILEFLOW_HYBRID_MIGRATION.md`
- **FileFlow 마이그레이션 체크포인트**: `/Users/sangwon-ryu/infrastructure/FILEFLOW_MIGRATION_CHECKPOINT.md`
- **Governance 가이드**: `/Users/sangwon-ryu/infrastructure/docs/governance/`

### Terraform 모듈
- **공통 모듈**: `/Users/sangwon-ryu/infrastructure/terraform/modules/`
- **모듈 개발 가이드**: `/Users/sangwon-ryu/infrastructure/docs/modules/`

### 실제 구현 예제
- **FileFlow 프로젝트**: `/Users/sangwon-ryu/fileflow/infrastructure/terraform/`
- **Infrastructure 백업**: `/Users/sangwon-ryu/infrastructure/terraform/fileflow.backup-20251021-094557/`

### AWS 공식 문서
- **SSM Parameter Store**: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
- **KMS**: https://docs.aws.amazon.com/kms/latest/developerguide/overview.html
- **RDS**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html
- **ECS**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html

### Terraform 공식 문서
- **AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Data Sources**: https://www.terraform.io/language/data-sources
- **Modules**: https://www.terraform.io/language/modules

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|-----|------|----------|--------|
| 1.0 | 2025-10-21 | 초기 작성 | Platform Team |

---

**문서 피드백**: 이 가이드에 대한 피드백이나 개선 제안은 Jira 또는 Slack #infrastructure 채널로 부탁드립니다.
