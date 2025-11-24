# Production Environment - Infrastructure as Code

**환경**: Production (prod)
**리전**: ap-northeast-2 (Seoul)
**Terraform 버전**: >= 1.5.0
**마지막 업데이트**: 2025-11-24

---

## 📋 목차

- [개요](#개요)
- [전체 아키텍처](#전체-아키텍처)
- [스택 목록](#스택-목록)
- [배포 순서](#배포-순서)
- [Modules v1.0.0 패턴](#modules-v100-패턴)
- [거버넌스 준수](#거버넌스-준수)
- [운영 가이드](#운영-가이드)
- [문제 해결](#문제-해결)

---

## 개요

Production 환경의 전체 인프라를 관리하는 Terraform 스택 모음입니다. 11개의 독립적인 스택으로 구성되어 있으며, 각 스택은 특정 도메인의 리소스를 관리합니다.

### 주요 특징

- ✅ **Modules v1.0.0 패턴**: 재사용 가능한 모듈 활용
- ✅ **거버넌스 준수**: 8개 필수 태그, KMS 암호화, 네이밍 규칙
- ✅ **상태 격리**: 스택별 독립적인 Terraform state 관리
- ✅ **Cross-Stack 참조**: SSM Parameter Store를 통한 안전한 참조
- ✅ **보안 우선**: KMS 암호화, IAM 최소 권한, VPC 격리
- ✅ **고가용성**: Multi-AZ 배포, 자동 백업, 모니터링
- ✅ **자동화**: Atlantis를 통한 PR 기반 배포

---

## 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    Production Environment                    │
│                      (ap-northeast-2)                        │
└─────────────────────────────────────────────────────────────┘

┌──────────────┐
│  Foundation  │  Bootstrap, KMS, Network, ACM, Route53
└──────────────┘
       │
       ▼
┌──────────────┐
│   Security   │  Secrets Manager, IAM Roles
└──────────────┘
       │
       ▼
┌──────────────┐
│  Application │  Atlantis (ECS), RDS Database
└──────────────┘
       │
       ▼
┌──────────────┐
│ Observability│  Logging, Monitoring (AMP/AMG), CloudTrail
└──────────────┘
```

### 네트워크 토폴로지

```
VPC (10.0.0.0/16)
├── Public Subnets (2 AZs)
│   ├── 10.0.0.0/20  (ap-northeast-2a)
│   └── 10.0.16.0/20 (ap-northeast-2c)
│
├── Private Subnets (2 AZs)
│   ├── 10.0.32.0/19 (ap-northeast-2a)
│   └── 10.0.64.0/19 (ap-northeast-2c)
│
├── Internet Gateway
├── NAT Gateway (ap-northeast-2a)
└── Transit Gateway (Optional)
```

---

## 스택 목록

### 🏗️ Foundation (기반 인프라)

| 스택 | 설명 | 사용 모듈 | 주요 리소스 |
|------|------|-----------|-------------|
| **[bootstrap](./bootstrap/)** | Terraform state 관리 | s3-bucket, iam-role-policy | S3, DynamoDB, KMS, GitHub Actions Role |
| **[kms](./kms/)** | 암호화 키 중앙 관리 | - | 9개 KMS Keys, SSM Parameters |
| **[network](./network/)** | VPC 및 네트워크 | - | VPC, Subnets, NAT Gateway, Transit Gateway |
| **[acm](./acm/)** | SSL/TLS 인증서 | - | Wildcard Certificate (*.set-of.com) |
| **[route53](./route53/)** | DNS 관리 | - | Hosted Zone, Query Logging, Health Checks |

### 🔐 Security (보안)

| 스택 | 설명 | 사용 모듈 | 주요 리소스 |
|------|------|-----------|-------------|
| **[secrets](./secrets/)** | 비밀 정보 관리 | lambda, iam-role-policy | Secrets Manager, Lambda Rotation |

### 🚀 Application (애플리케이션)

| 스택 | 설명 | 사용 모듈 | 주요 리소스 |
|------|------|-----------|-------------|
| **[atlantis](./atlantis/)** | Terraform 자동화 서버 | ecr, alb, security-group, iam-role-policy, cloudwatch-log-group | ECS Fargate, ECR, ALB, EFS |
| **[rds](./rds/)** | MySQL 데이터베이스 | rds, security-group, iam-role-policy | RDS MySQL, CloudWatch Alarms |

### 📊 Observability (관찰성)

| 스택 | 설명 | 사용 모듈 | 주요 리소스 |
|------|------|-----------|-------------|
| **[logging](./logging/)** | 중앙 로깅 시스템 | cloudwatch-log-group | CloudWatch Log Groups (3개) |
| **[monitoring](./monitoring/)** | 메트릭 및 알림 | sns, iam-role-policy | AMP, AMG, SNS Topics, CloudWatch Alarms |
| **[cloudtrail](./cloudtrail/)** | 감사 로그 | s3-bucket | CloudTrail, Athena, EventBridge |

---

## 배포 순서

스택 간 의존성을 고려한 배포 순서입니다:

### 1단계: Foundation (순서 중요)

```bash
cd bootstrap
terraform init && terraform apply  # 로컬 state → S3 backend 마이그레이션

cd ../kms
terraform init && terraform apply

cd ../network
terraform init && terraform apply

cd ../route53
terraform init && terraform apply

cd ../acm
terraform init && terraform apply
```

### 2단계: Security

```bash
cd secrets
terraform init && terraform apply
```

### 3단계: Application

```bash
cd atlantis
terraform init && terraform apply

cd ../rds
terraform init && terraform apply
```

### 4단계: Observability (병렬 가능)

```bash
# 병렬 실행 가능
cd logging && terraform init && terraform apply &
cd monitoring && terraform init && terraform apply &
cd cloudtrail && terraform init && terraform apply &
wait
```

---

## Modules v1.0.0 패턴

모든 스택은 `../../modules/` 디렉터리의 재사용 가능한 모듈을 활용합니다.

### 사용된 모듈 (활용도 순)

1. **security-group** (6회) - Atlantis, RDS, Secrets, Network
2. **iam-role-policy** (8회) - Atlantis, RDS, Secrets, Monitoring, Bootstrap
3. **cloudwatch-log-group** (4회) - Atlantis, Logging
4. **s3-bucket** (3회) - Bootstrap, CloudTrail
5. **sns** (3회) - Monitoring
6. **rds** (1회) - RDS
7. **ecr** (1회) - Atlantis
8. **alb** (1회) - Atlantis
9. **lambda** (1회) - Secrets

### 모듈 사용 예시

```hcl
module "example_security_group" {
  source = "../../modules/security-group"

  name        = "my-service"
  description = "Security group for my service"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "HTTPS from VPC"
    }
  ]

  # Required: 필수 태그 변수
  environment  = "prod"
  service_name = "my-service"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

---

## 거버넌스 준수

모든 스택은 다음 거버넌스 표준을 준수합니다:

### ✅ 필수 태그 (8개)

모든 리소스는 다음 태그를 포함해야 합니다:

| 태그 | 설명 | 예시 |
|------|------|------|
| Environment | 환경 | prod |
| Service | 서비스 이름 | atlantis |
| Team | 담당 팀 | platform-team |
| Owner | 소유자 이메일 | platform@example.com |
| CostCenter | 비용 센터 | engineering |
| Project | 프로젝트 | infrastructure |
| DataClass | 데이터 분류 | confidential |
| ManagedBy | 관리 도구 | terraform |

### ✅ KMS 암호화

모든 암호화는 customer-managed KMS keys를 사용합니다:

- ❌ AES256 (AWS 관리형) 사용 금지
- ✅ Customer-managed KMS keys 필수
- ✅ 자동 키 로테이션 활성화
- ✅ 30일 삭제 대기 기간

### ✅ 네이밍 규칙

- **리소스**: kebab-case (예: `prod-atlantis-ecs`)
- **변수/출력**: snake_case (예: `vpc_id`, `subnet_ids`)
- **태그 값**: kebab-case (예: `platform-team`)

### ✅ 보안 스캔

배포 전 자동 검증:

```bash
# 필수 태그 검증
./scripts/validators/check-tags.sh

# KMS 암호화 검증
./scripts/validators/check-encryption.sh

# 네이밍 규칙 검증
./scripts/validators/check-naming.sh

# tfsec 보안 스캔
./scripts/validators/check-tfsec.sh

# Checkov 규정 준수
./scripts/validators/check-checkov.sh
```

---

## 운영 가이드

### 일반적인 작업 흐름

#### 1. 변경 사항 배포 (Atlantis 사용)

```bash
# 1. Feature 브랜치 생성
git checkout -b feature/add-rds-read-replica

# 2. Terraform 코드 변경
cd terraform/environments/prod/rds
# ... 파일 수정 ...

# 3. PR 생성
git add .
git commit -m "feat: Add RDS read replica for performance"
git push origin feature/add-rds-read-replica

# 4. GitHub에서 PR 생성
# → Atlantis가 자동으로 terraform plan 실행
# → PR 코멘트에 plan 결과 표시

# 5. PR 승인 후 Atlantis 명령어
# PR 코멘트에 입력:
atlantis apply

# 6. PR 병합
```

#### 2. 수동 배포 (긴급 상황)

```bash
cd terraform/environments/prod/{stack-name}

# Plan 실행
terraform plan -out=tfplan

# 검토 후 Apply
terraform apply tfplan
```

#### 3. State 조회

```bash
# 현재 리소스 목록
terraform state list

# 특정 리소스 상세 정보
terraform state show module.rds.aws_db_instance.main

# 출력 값 조회
terraform output
```

#### 4. Cross-Stack 참조

다른 스택의 출력 값을 참조할 때:

```hcl
# Option 1: Remote State (추천하지 않음)
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "prod-connectly-tfstate"
    key    = "network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Option 2: SSM Parameter (권장)
data "aws_ssm_parameter" "vpc_id" {
  name = "/prod/network/vpc-id"
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
}
```

### 비용 모니터링

**월간 예상 비용** (2025년 기준):

| 스택 | 주요 비용 | 월 예상 |
|------|----------|---------|
| network | NAT Gateway, Transit Gateway | $45-60 |
| atlantis | ECS Fargate, ALB, EFS | $80-100 |
| rds | RDS MySQL db.t3.medium | $120-150 |
| monitoring | AMP, AMG | $40-60 |
| kms | 9 Keys | $9-12 |
| cloudtrail | S3, Athena | $5-10 |
| 기타 | Secrets, Logs, Route53 | $20-30 |
| **합계** | | **$319-422/월** |

**비용 최적화 팁**:

1. **NAT Gateway**: Single vs Multi-AZ 트레이드오프
2. **RDS**: Reserved Instances 고려 (1년 약정 시 40% 절감)
3. **Log Retention**: 불필요한 로그 보존 기간 단축
4. **VPC Endpoints**: S3, ECR 등 Gateway/Interface 엔드포인트 활용
5. **Spot Instances**: 비프로덕션 워크로드는 Spot 사용

---

## 문제 해결

### 일반적인 문제

#### 1. State Lock 획득 실패

```bash
Error: Error acquiring the state lock

# 원인: 다른 프로세스가 이미 lock 보유
# 해결:
terraform force-unlock <LOCK_ID>
```

#### 2. Remote State 참조 실패

```bash
Error: error reading S3 Bucket object

# 원인: 참조하는 스택이 아직 배포되지 않음
# 해결:
cd terraform/environments/prod/{dependency-stack}
terraform init && terraform apply
```

#### 3. KMS 권한 에러

```bash
Error: AccessDeniedException: User is not authorized to perform: kms:Decrypt

# 원인: IAM role에 KMS 키 권한 없음
# 해결: kms 스택의 키 정책 업데이트 필요
```

#### 4. VPC 리소스 삭제 실패

```bash
Error: error deleting VPC: DependencyViolation

# 원인: VPC에 연결된 리소스 존재 (ENI, Security Group 등)
# 해결:
# 1. 모든 애플리케이션 스택 먼저 삭제
# 2. VPC 엔드포인트, NAT Gateway 삭제
# 3. 마지막으로 VPC 삭제
```

#### 5. Atlantis Plan 실패

```bash
# PR 코멘트에 에러 표시됨

# 디버깅:
# 1. Atlantis ECS 로그 확인
aws logs tail /aws/ecs/atlantis/application --follow

# 2. ECS 태스크 상태 확인
aws ecs describe-tasks --cluster atlantis-prod --tasks <task-id>

# 3. GitHub Webhook 이벤트 확인
# GitHub Repository → Settings → Webhooks → Recent Deliveries
```

### 긴급 연락처

- **인프라 담당**: Platform Team (platform@example.com)
- **Slack 채널**: #infrastructure-alerts
- **On-Call**: PagerDuty 에스컬레이션 정책 참조

---

## 관련 문서

### 내부 문서

- [Terraform Modules Catalog](../../modules/README.md)
- [Governance Standards](../../../docs/governance/GOVERNANCE_STANDARDS.md)
- [Tagging Standards](../../../docs/TAGGING_STANDARDS.md)
- [Network Architecture](../../../docs/architecture/NETWORK_ARCHITECTURE.md)

### 외부 참고

- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Atlantis Documentation](https://www.runatlantis.io/)

---

**Version**: v1.0.0
**Last Updated**: 2025-11-24
**Maintained By**: Platform Team
