# 2️⃣ 아키텍처 설계

**하이브리드 Terraform 인프라 구조 가이드 - Part 2**

**작성일**: 2025-10-22
**버전**: 2.0
**대상 독자**: 아키텍처 설계자, 플랫폼 팀, DevOps 엔지니어

---

## 📋 이 가이드에서 다루는 내용

1. [Infrastructure 프로젝트 역할](#infrastructure-프로젝트-역할-중앙-관리)
2. [Application 프로젝트 역할](#application-프로젝트-역할-분산-관리)
3. [Producer-Consumer 패턴](#producer-consumer-패턴)
4. [데이터 흐름 다이어그램](#데이터-흐름-다이어그램)
5. [SSM Parameter 아키텍처](#ssm-parameter-아키텍처)

---

## Infrastructure 프로젝트 역할 (중앙 관리)

**위치**: `/Users/sangwon-ryu/infrastructure/terraform/`

**핵심 원칙**: 공유 가능한 리소스는 중앙에서 관리하고, SSM Parameter Store를 통해 Export합니다.

### 관리 대상 리소스

#### 1. Network (네트워크)

**VPC 및 Subnets 구성**:
- **VPC CIDR**: `10.0.0.0/16` (65,536 IP 주소)
- **Public Subnets**: Multi-AZ, `/20` (4,096 IP 주소 각)
  - Internet-facing 리소스 (ALB, NAT Gateway)
- **Private Subnets**: Multi-AZ, `/19` (8,192 IP 주소 각)
  - Application 리소스 (ECS Tasks, Lambda)
- **Data Subnets**: Multi-AZ, `/20` (4,096 IP 주소 각)
  - Database 및 Cache (RDS, ElastiCache)

**네트워크 컴포넌트**:
- Internet Gateway (IGW): Public Subnet 아웃바운드
- NAT Gateway: Private Subnet 아웃바운드
- Route Tables: Public, Private, Data 각각 별도
- VPC Endpoints (Gateway & Interface):
  - S3, DynamoDB (Gateway): 무료
  - ECR, Secrets Manager (Interface): 비용 발생

#### 2. KMS (암호화 키)

**데이터 분류별 KMS 키 분리**:

| KMS 키 | 용도 | Export Parameter |
|--------|------|------------------|
| CloudWatch Logs | 로그 암호화 | `/shared/kms/cloudwatch-logs-key-arn` |
| Secrets Manager | 시크릿 암호화 | `/shared/kms/secrets-manager-key-arn` |
| RDS | 데이터베이스 암호화 | `/shared/kms/rds-key-arn` |
| S3 | 스토리지 암호화 | `/shared/kms/s3-key-arn` |
| SQS | 큐 메시지 암호화 | `/shared/kms/sqs-key-arn` |
| SSM | Parameter Store 암호화 | `/shared/kms/ssm-key-arn` |
| ElastiCache | 캐시 암호화 | `/shared/kms/elasticache-key-arn` |

**주요 특징**:
- Customer Managed Keys (CMK) 사용
- Automatic Key Rotation 활성화
- Multi-Region Key 지원 (DR 시나리오)

#### 3. Shared RDS (공유 데이터베이스)

**구성**:
- **Engine**: MySQL 8.0
- **Instance Class**: db.r6g.xlarge (프로덕션)
- **Multi-AZ**: 고가용성 지원
- **Storage**: gp3 (프로비저닝된 IOPS)
- **Backup**: 7일 자동 백업
- **Performance Insights**: 활성화

**내부 Database 구조**:
```
prod-shared-mysql
├── Database: fileflow
│   └── User: fileflow_user (CRUD, DDL 권한)
├── Database: authhub
│   └── User: authhub_user (CRUD, DDL 권한)
└── Database: crawler
    └── User: crawler_user (CRUD, DDL 권한)
```

**보안**:
- Master Credentials: Secrets Manager에 저장
- VPC 내부 Private Subnet에 배치
- Security Group: 서비스별 ECS Tasks만 접근 가능
- Encryption at Rest: RDS KMS 키 사용
- Encryption in Transit: SSL/TLS 강제

#### 4. ECR (컨테이너 레지스트리)

**서비스별 ECR 레포지토리**:
- `fileflow-repository`
- `authhub-repository`
- `crawler-repository`

**Lifecycle Policy**:
```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "최근 10개 이미지만 유지",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

**Image Scanning**: 푸시 시 자동 취약점 스캔

#### 5. SSM Parameters (공유 정보 Export)

모든 공유 리소스는 SSM Parameter Store를 통해 Export됩니다:

**Network Parameters**:
```
/shared/network/vpc-id
/shared/network/public-subnet-ids
/shared/network/private-subnet-ids
/shared/network/data-subnet-ids
```

**KMS Parameters**:
```
/shared/kms/cloudwatch-logs-key-arn
/shared/kms/secrets-manager-key-arn
/shared/kms/rds-key-arn
/shared/kms/s3-key-arn
/shared/kms/sqs-key-arn
/shared/kms/ssm-key-arn
/shared/kms/elasticache-key-arn
```

**Service-specific Parameters**:
```
/shared/ecr/{service-name}-repository-url
/shared/rds/{env}/endpoint
/shared/rds/{env}/port
```

---

## Application 프로젝트 역할 (분산 관리)

**위치**: `/Users/sangwon-ryu/{service-name}/infrastructure/terraform/`

**핵심 원칙**: 서비스 특화 리소스는 서비스 레포지토리에서 관리하고, 공유 리소스는 SSM Parameter Store를 통해 참조합니다.

### 관리 대상 리소스

#### 1. ECS (컨테이너 오케스트레이션)

**ECS Cluster**:
- 클러스터 이름: `{service}-{env}-cluster`
- Container Insights 활성화

**ECS Service**:
- Launch Type: Fargate
- Network Mode: awsvpc
- Service Discovery: AWS Cloud Map (옵션)
- Auto Scaling: Target Tracking (CPU/Memory)

**Task Definition**:
- CPU: 256-4096 (Fargate 제한)
- Memory: 512-30720 (Fargate 제한)
- Ephemeral Storage: 20-200 GB
- Container Logging: CloudWatch Logs

**Security Groups**:
- ECS Tasks: ALB, RDS, Redis, SQS 접근
- Egress: HTTPS (443), MySQL (3306), Redis (6379)

#### 2. Shared RDS 연결

**Database 및 User 생성**:
- Application별 Database 생성 (예: `fileflow`)
- Application별 User 생성 (예: `fileflow_user`)
- 최소 권한 부여: SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER

**Credentials 관리**:
- Secrets Manager에 저장
- Secret 이름: `{service}-{env}-db-credentials`
- KMS: Secrets Manager KMS 키로 암호화

**Security Group Rule**:
```hcl
resource "aws_security_group_rule" "shared_rds_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = local.shared_rds_sg_id
  description              = "Allow MySQL from {service} ECS tasks"
}
```

#### 3. ElastiCache Redis

**Replication Group**:
- Engine: Redis 7.0
- Node Type: cache.r6g.large (프로덕션)
- Number of Nodes: 2 (Primary + Replica)
- Multi-AZ: 활성화
- Automatic Failover: 활성화

**Parameter Group**:
- `maxmemory-policy`: allkeys-lru
- `timeout`: 300

#### 4. S3 Buckets

**Storage Bucket**:
- 버킷 이름: `{service}-{env}-storage`
- Versioning: 활성화
- Lifecycle: 90일 후 Intelligent-Tiering

**Logs Bucket**:
- 버킷 이름: `{service}-{env}-logs`
- Lifecycle: 7일 후 Glacier, 90일 후 삭제

**Encryption**:
- SSE-KMS: S3 KMS 키 사용

#### 5. SQS Queues

**Standard Queue**:
- 큐 이름: `{service}-{env}-queue`
- Message Retention: 4일
- Visibility Timeout: 30초

**Dead Letter Queue**:
- 큐 이름: `{service}-{env}-dlq`
- Max Receive Count: 3

**Encryption**:
- SSE-KMS: SQS KMS 키 사용

#### 6. Application Load Balancer

**ALB Configuration**:
- Scheme: internet-facing
- Subnets: Public Subnets (Multi-AZ)
- Security Group: 80, 443 허용

**Target Group**:
- Target Type: ip
- Health Check: `/actuator/health` 또는 `/health`
- Deregistration Delay: 30초

**Listener Rules**:
- 80 → 443 리다이렉트
- 443 → Target Group (TLS 종료)

#### 7. IAM Roles and Policies

**ECS Task Execution Role**:
```hcl
{
  "Effect": "Allow",
  "Action": [
    "ecr:GetAuthorizationToken",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:BatchGetImage",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

**ECS Task Role**:
```hcl
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "sqs:SendMessage",
    "sqs:ReceiveMessage",
    "sqs:DeleteMessage",
    "secretsmanager:GetSecretValue",
    "ssm:GetParameter"
  ]
}
```

---

## Producer-Consumer 패턴

하이브리드 인프라의 핵심은 **Producer-Consumer 패턴**을 통한 느슨한 결합입니다.

### Producer: Infrastructure 프로젝트

**역할**: 공유 리소스를 생성하고 SSM Parameter Store에 Export

```hcl
# Infrastructure Repository - network/main.tf
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  # ...
}

# SSM Parameter로 Export
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/shared/network/vpc-id"
  type  = "String"
  value = aws_vpc.main.id
}
```

### Consumer: Application 프로젝트

**역할**: SSM Parameter Store에서 공유 리소스 정보를 Import

```hcl
# Application Repository - data.tf
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

# locals.tf
locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
}

# ecs.tf
resource "aws_ecs_cluster" "main" {
  name = "${var.service}-${var.env}-cluster"
  # VPC ID를 로컬 변수로 참조 (직접 의존성 없음)
  vpc_id = local.vpc_id
}
```

### 느슨한 결합의 장점

1. **독립적 배포**: Infrastructure와 Application 프로젝트는 독립적으로 배포 가능
2. **버전 관리**: Application 프로젝트는 Infrastructure 변경에 영향받지 않음
3. **확장성**: 새로운 서비스 추가 시 Infrastructure 수정 불필요
4. **유지보수**: SSM Parameter만 변경하면 모든 Application에 자동 반영

---

## 데이터 흐름 다이어그램

### 전체 아키텍처 흐름

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
```

### Shared RDS 내부 구조

```
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

### 네트워크 트래픽 흐름

```
Internet
   │
   │ HTTPS (443)
   ▼
┌──────────────┐
│ ALB          │ (Public Subnets)
│ (Multi-AZ)   │
└──────┬───────┘
       │
       │ HTTP (8080)
       ▼
┌──────────────┐
│ ECS Tasks    │ (Private Subnets)
│ (Fargate)    │
└──┬────┬───┬──┘
   │    │   │
   │    │   └──────────────┐
   │    │                  │
   │    │ MySQL (3306)     │ Redis (6379)
   │    ▼                  ▼
   │  ┌──────────┐    ┌───────────┐
   │  │ Shared   │    │ ElastiCache│
   │  │ RDS      │    │ Redis      │
   │  └──────────┘    └───────────┘
   │  (Data Subnets)  (Data Subnets)
   │
   │ S3 API (443)
   └──────────────────────┐
                          │
                          ▼
                    ┌──────────┐
                    │ S3       │
                    │ (VPC     │
                    │ Endpoint)│
                    └──────────┘
```

---

## SSM Parameter 아키텍처

### 계층 구조 (Hierarchical)

```
/shared/
├── network/
│   ├── vpc-id
│   ├── public-subnet-ids
│   ├── private-subnet-ids
│   └── data-subnet-ids
├── kms/
│   ├── cloudwatch-logs-key-arn
│   ├── secrets-manager-key-arn
│   ├── rds-key-arn
│   ├── s3-key-arn
│   ├── sqs-key-arn
│   ├── ssm-key-arn
│   └── elasticache-key-arn
├── ecr/
│   ├── fileflow-repository-url
│   ├── authhub-repository-url
│   └── crawler-repository-url
└── rds/
    ├── prod/
    │   ├── endpoint
    │   ├── port
    │   └── database-name
    └── dev/
        ├── endpoint
        ├── port
        └── database-name
```

### 읽기 권한 설정

**Application 프로젝트의 Terraform Execution Role**:

```json
{
  "Effect": "Allow",
  "Action": [
    "ssm:GetParameter",
    "ssm:GetParameters",
    "ssm:GetParametersByPath"
  ],
  "Resource": "arn:aws:ssm:ap-northeast-2:*:parameter/shared/*"
}
```

### Parameter 타입 선택

| 타입 | 용도 | 암호화 | 비용 |
|------|------|--------|------|
| **String** | 일반 값 (VPC ID, Subnet IDs, ARNs) | 불필요 | 무료 |
| **SecureString** | 민감 정보 (DB passwords, API keys) | KMS 암호화 | KMS 비용 |
| **StringList** | 배열 값 (Subnet IDs) | 불필요 | 무료 |

**권장 사항**:
- Network, KMS ARNs: **String** 타입 사용 (암호화 불필요, 무료)
- Database credentials: **Secrets Manager** 사용 (Rotation 지원)
- 환경별 설정: **StringList** 타입으로 여러 값 저장

---

## 다음 단계

이제 아키텍처 설계를 완료했습니다. 다음 단계로 넘어가세요:

- **[3️⃣ Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)**: Network, KMS, RDS, ECR 모듈 배포 및 SSM Parameters 생성
- **[4️⃣ Application 프로젝트 설정](hybrid-04-application-setup.md)**: data.tf, locals.tf 작성 및 Application 리소스 배포
- **[5️⃣ 배포 가이드](hybrid-05-deployment-guide.md)**: Terraform 검증, 배포, CI/CD 통합

---

**Last Updated**: 2025-10-22
