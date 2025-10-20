# Service Repository Onboarding Guide

## Purpose

This guide helps service teams autonomously build and manage their infrastructure using standardized patterns from the infrastructure repository. It provides clear guidelines on folder structure, naming conventions, and best practices for organizing infrastructure code in service repositories.

## Target Audience

- Service teams setting up new infrastructure
- Developers migrating to Infrastructure as Code (IaC)
- Team members contributing to infrastructure repositories

## Prerequisites

Before you begin, ensure you have:

- Basic understanding of Terraform and AWS
- Access to the infrastructure repository
- Understanding of your service's architecture and requirements
- AWS credentials configured for your target environment

---
# 서비스 리포지토리 온보딩 가이드

## 목적

이 가이드는 서비스 팀이 인프라스트럭처 리포지토리의 표준화된 패턴을 활용하여 자율적으로 인프라를 구축하고 운영할 수 있도록 돕습니다. 서비스 리포지토리에서 인프라 코드를 체계적으로 구성하기 위한 디렉터리 구조, 네이밍 컨벤션, 모범 사례를 명확히 제시합니다.

## 대상 독자

- 신규 인프라를 구축하는 서비스 팀
- IaC(Infrastructure as Code)로 전환 중인 개발자
- 인프라 리포지토리에 기여하는 팀 구성원

## 사전 준비 사항

시작하기 전에 다음을 준비하세요:

- Terraform 및 AWS에 대한 기본 이해

- 중앙 인프라스트럭처 리포지토리에 대한 접근 권한
- 서비스 아키텍처와 요구사항에 대한 이해
- 대상 환경에 맞게 구성된 AWS 자격 증명

---

---

## 문서 분할 안내

## 목차

- [인프라 디렉터리 구조와 가이드라인](./01-structure.md)
- [파일 구성과 상태 관리](./02-files-and-state.md)
- [모듈 사용 가이드](./03-modules-usage.md)
- [버전 관리와 업그레이드](./04-versioning-and-upgrades.md)
- [백엔드 구성 모범사례 및 트러블슈팅](./05-backend-best-practices.md)

---
## 참고

- 본 문서는 `SERVICE_REPO_ONBOARDING.md`의 전체 내용을 한국어로 정리한 후, 섹션별로 분할한 인덱스입니다.
- 각 하위 문서에는 코드 블록과 구체 예시가 포함되어 있으며, 원문 구조와 경로를 유지합니다.
  desired_count       = 3
  cpu                 = 512
  memory              = 1024
  enable_autoscaling  = true
  min_capacity        = 2
  max_capacity        = 10

  common_tags = module.common_tags.tags
}
```

**Backend Configuration Example** (`environments/prod/backend.tf`):
```hcl
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "services/user-api/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    dynamodb_table = "terraform-state-lock"
  }
}
```

#### `infra/terraform/shared/` - 공용 리소스(선택)
- **목적**: 모든 환경에서 공통으로 사용하는 인프라
- **사용 시점**:
  - 모든 환경이 공통으로 사용하는 네트워크(VPC, 서브넷 등)
  - 암호화를 위한 KMS 키
  - IAM 역할 및 정책
  - 환경 간 서비스 디스커버리
- **가이드라인**: 실제로 공용이 필요한 경우에만 생성하고, 대부분은 환경별 구성을 권장

**Shared Resource Example**:
```
shared/
├── network/
│   ├── main.tf        # VPC, subnets, route tables, NAT gateways
│   ├── outputs.tf     # Export VPC ID, subnet IDs for use in environments
│   └── backend.tf     # Separate state for shared network
└── kms/
    ├── main.tf        # KMS keys for different data classifications
    ├── outputs.tf     # Key IDs and ARNs
    └── backend.tf     # Separate state for encryption keys
```

### 파일 네이밍 컨벤션

#### Terraform 파일
- **기본 파일**: 표준 Terraform 파일명을 사용
  - `main.tf` - 핵심 리소스 정의
  - `variables.tf` - 입력 변수 선언
  - `outputs.tf` - 출력 값 정의
  - `versions.tf` - 버전 제약 정의
  - `provider.tf` - 프로바이더 설정
  - `backend.tf` - 백엔드 설정
  - `locals.tf` - 로컬 값(선택, 복잡한 로직이 있을 때 사용)
  - `data.tf` - 데이터 소스 정의(선택, 데이터 소스가 많을 때 분리)

- **리소스별 파일 분리**: 규모가 큰 구성에서는 관련 리소스를 묶어 분리
  - `ecs.tf` - ECS 클러스터, 서비스, 태스크 정의
  - `rds.tf` - 데이터베이스 인스턴스 및 파라미터 그룹
  - `security-groups.tf` - 보안 그룹 정의
  - `iam.tf` - IAM 역할 및 정책
  - `monitoring.tf` - CloudWatch 알람/대시보드

#### 변수 파일
- `terraform.tfvars` - 환경 기본 변수 값
- `prod.tfvars`, `staging.tfvars`, `dev.tfvars` - 환경별 오버라이드(workspace 패턴 사용 시)
- `secrets.auto.tfvars` - 민감한 값(`.gitignore`로 버전 관리 제외)

#### 문서 파일
- `README.md` - 모듈/환경 문서
- `ARCHITECTURE.md` - 아키텍처 결정 사항 및 다이어그램
- `RUNBOOK.md` - 운영 절차

### 파일 구성 모범 사례

#### 소규모 구성(< 10 리소스)
표준 파일을 활용한 간단한 구조 사용:
```
environments/dev/
├── main.tf          # All resource definitions
├── variables.tf     # All variables
├── outputs.tf       # All outputs
├── backend.tf       # State backend
├── provider.tf      # AWS provider
└── terraform.tfvars # Variable values
```

#### 중간 규모 구성(10~50 리소스)
관련 리소스를 논리적으로 파일로 그룹화:
```
environments/prod/
├── main.tf              # Module calls and primary resources
├── ecs.tf               # ECS-related resources
├── rds.tf               # Database resources
├── security-groups.tf   # Network security
├── monitoring.tf        # CloudWatch resources
├── variables.tf         # All variables
├── outputs.tf           # All outputs
├── backend.tf           # State backend
├── provider.tf          # AWS provider
└── terraform.tfvars     # Variable values
```

#### 대규모 구성(> 50 리소스)
여러 모듈로 분할하거나 하위 디렉터리 사용 고려:
```
environments/prod/
├── compute/
│   ├── main.tf       # ECS services
│   └── autoscaling.tf
├── database/
│   ├── main.tf       # RDS instances
│   └── replicas.tf
├── networking/
│   ├── main.tf       # Security groups
│   └── load-balancers.tf
├── variables.tf      # Shared variables
├── outputs.tf        # Shared outputs
├── backend.tf        # State backend
└── provider.tf       # AWS provider
```

### 상태(State) 관리

#### 백엔드 구성
팀 협업을 위해 항상 원격 상태 백엔드(S3 + DynamoDB)를 사용하세요:

```hcl
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "services/{service-name}/{environment}/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:..."
    dynamodb_table = "terraform-state-lock"
  }
}
```

**핵심 가이드라인**:
- **Bucket**: 조직 공용 Terraform 상태 버킷(한 번 생성해 모든 서비스에서 사용)
- **Key 패턴**: 격리를 위해 `services/{service-name}/{environment}/terraform.tfstate`
- **암호화**: 고객 관리형 KMS 키로 항상 암호화 활성화
- **락킹**: 동시 수정 방지를 위해 DynamoDB 테이블 사용
- **버저닝**: 상태 이력을 위해 S3 버킷 버저닝 활성화

#### 상태 파일 구성
- **환경별 1 상태 파일**: dev, staging, prod를 각각 분리
- **공용 상태 분리**: 공용 리소스를 사용한다면 별도 상태 파일 사용
- **모듈 상태 분리**: 각 환경은 모듈을 참조하되 자체 상태를 유지

### 모듈 재사용 전략

#### 중앙 인프라 모듈 사용
인프라 리포지토리의 중앙 모듈을 참조하여 사용하세요:

```hcl
module "common_tags" {
  source = "git::https://github.com/org/infrastructure.git//terraform/modules/common-tags?ref=v1.2.0"

  environment = "prod"
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
}

module "ecs_service" {
  source = "git::https://github.com/org/infrastructure.git//terraform/modules/ecs-service?ref=v2.1.0"

  name              = var.service_name
  cluster_id        = var.cluster_id
  task_definition   = module.task_definition.arn
  desired_count     = var.desired_count

  common_tags = module.common_tags.tags
}
```

**모범 사례**:
- **버전 고정**: 모듈 버전을 고정하기 위해 항상 `?ref=v1.2.0` 형태로 명시
- **시맨틱 버저닝**: 모듈 릴리스에 semver(주.부.패치) 준수
- **테스트**: 프로덕션 적용 전에 개발 환경에서 모듈 업데이트를 테스트
- **문서 확인**: 모듈 README에서 입력/출력 사양 확인

#### 서비스 전용 모듈 생성
중앙 모듈로 요구 사항을 충족할 수 없을 때:

```hcl
# In infra/terraform/modules/custom-cache/
module "redis_cache" {
  source = "./modules/custom-cache"

  name              = "${var.environment}-${var.service}-cache"
  vpc_id            = var.vpc_id
  subnet_ids        = var.private_subnet_ids
  node_type         = "cache.t3.medium"
  num_cache_nodes   = var.environment == "prod" ? 3 : 1

  common_tags = module.common_tags.tags
}
```

**생성 기준**:
- 서비스 특화 인프라 패턴이 필요한 경우
- 커스텀 비즈니스 로직 요구가 있는 경우
- 복잡한 다중 리소스 조합이 필요한 경우
- 중앙 모듈이 지나치게 범용적이라 맞지 않는 경우

### 문서화 요구사항

#### 모듈 README 템플릿
모든 모듈에는 다음 내용을 포함한 README가 필요합니다:

```markdown
# Module Name

## Purpose
Brief description of what this module creates and why.

## Usage
```hcl
module "example" {
  source = "./modules/module-name"

  name = "my-resource"
  # ... other variables
}
```

## Requirements
- Terraform >= 1.5.0
- AWS Provider >= 5.0.0

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Resource name | string | - | yes |

## Outputs
| Name | Description |
|------|-------------|
| resource_id | Resource identifier |

## Examples
- [Basic](./examples/basic/) - Minimal configuration
- [Advanced](./examples/advanced/) - Full-featured setup
```

#### 환경 README 템플릿
각 환경 디렉터리는 다음 내용을 문서화해야 합니다:

```markdown
# {Environment} Environment

## Overview
Description of this environment's purpose and configuration.

## Deployment
```bash
cd infra/terraform/environments/{env}
terraform init
terraform plan
terraform apply
```

## Configuration
- **AWS Account**: 123456789012
- **Region**: ap-northeast-2
- **VPC ID**: vpc-xxxxx
- **Cluster**: {environment}-{service}-cluster

## Outputs
Key outputs and how to use them.

## Troubleshooting
Common issues and solutions.
```

---

## 중앙 모듈 참조

### 개요

인프라 리포지토리는 서비스 팀이 참조하여 사용할 수 있는 중앙화된 프로덕션 준비 완료 Terraform 모듈을 제공합니다. 이 섹션은 서비스 리포지토리에서 이러한 중앙 모듈을 검색, 참조, 버전 관리하는 방법을 설명합니다.

### 중앙 모듈을 사용하는 이유

**이점**:
- **사전 검증된 패턴**: 조직 표준에 대해 검증된 모듈
- **일관된 인프라**: 모든 서비스에 동일한 패턴 적용
- **개발 시간 단축**: 공통 패턴을 재발명할 필요 없음
- **베스트 프랙티스 내장**: 보안, 모니터링, 거버넌스 기본 포함
- **중앙 관리**: 업데이트/개선의 혜택이 모든 서비스에 공유

**중앙 모듈 사용 적합 시나리오**:
- 표준 AWS 리소스(ECS 서비스, RDS 인스턴스, ALB, 보안 그룹)
- 공통 인프라 패턴(로깅, 모니터링, 태깅)
- 거버넌스 요구사항(필수 태그, 네이밍 컨벤션, 보안 베이스라인)

**서비스 전용 모듈을 생성할 때**:
- 서비스 고유의 비즈니스 로직/워크플로우가 필요한 경우
- 중앙 모듈에서 제공하지 않는 커스텀 조합이 필요한 경우
- 중앙 리포지토리에 기여하기 전 임시 실험이 필요한 경우

### 모듈 검색

#### 사용 가능한 모듈 찾기

**주요 출처**: 인프라 리포지토리 모듈 카탈로그
```bash
# Clone or navigate to infrastructure repository
cd infrastructure/

# View available modules
ls -la terraform/modules/

# Output example:
# alb/
# cloudwatch-log-group/
# common-tags/
# ecs-service/
# iam-role-policy/
# rds-instance/
# security-group/
```

**모듈 문서**:
각 모듈은 다음과 같은 포괄적 문서를 포함합니다:

```
terraform/modules/{module-name}/
├── README.md              # Primary documentation
│   ├── Purpose
│   ├── Usage examples
│   ├── Input variables
│   ├── Output values
│   ├── Requirements
│   └── Examples
├── CHANGELOG.md           # Version history and changes
└── examples/
    ├── basic/             # Simple usage example
    └── advanced/          # Full-featured example
```

**모듈 카탈로그 참조**:
- [Terraform Modules README](../../../terraform/modules/README.md) - 전체 모듈 카탈로그
- [Module Directory Structure](../../modules/MODULES_DIRECTORY_STRUCTURE.md) - 조직화 패턴
- [Module Standards Guide](../../modules/MODULE_STANDARDS_GUIDE.md) - 코딩 컨벤션

#### 모듈 카테고리

**코어 인프라**:
- `common-tags` - 모든 리소스에 표준화된 태깅
- `cloudwatch-log-group` - 보존/암호화 설정된 로그 그룹
- `iam-role-policy` - 최소 권한 정책의 IAM 역할
- `security-group` - 검증 포함 보안 그룹

**컴퓨트**:
- `ecs-service` - 오토스케일링 지원 ECS Fargate 서비스
- `ecs-task-definition` - 컨테이너 구성을 포함한 태스크 정의
- `lambda-function` - 모니터링 포함 Lambda 함수

**데이터베이스 & 스토리지**:
- `rds-instance` - 멀티 AZ, 암호화, 백업을 갖춘 RDS
- `elasticache-redis` - 복제를 지원하는 Redis 클러스터
- `s3-bucket` - 버저닝/암호화/수명주기 설정 S3

**네트워킹**:
- `alb` - 타깃 그룹을 포함한 ALB
- `vpc` - 퍼블릭/프라이빗 서브넷을 갖춘 VPC
- `vpc-endpoint` - AWS 서비스용 VPC 엔드포인트

**모니터링 & 가시성**:
- `cloudwatch-dashboard` - 커스텀 CloudWatch 대시보드
- `cloudwatch-alarm` - SNS 통합 알람
- `log-metric-filter` - 로그 기반 메트릭

### Git URL 모듈 참조

#### 기본 문법

중앙 모듈은 다음 패턴의 Git URL로 참조합니다:

```hcl
module "module_name" {
  source = "git::https://github.com/{org}/{repo}.git//{path}?ref={version}"

  # Module inputs
  # ...
}
```

**구성 요소**:
- `git::` - Git 소스를 나타내는 프로토콜 접두사
- `https://github.com/{org}/{repo}.git` - 리포지토리 URL
- `//` - 경로 구분자(슬래시 2개 필요)
- `{path}` - 리포지토리 내 모듈 경로
- `?ref={version}` - 사용할 버전 태그

#### Complete Example

```hcl
module "common_tags" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/common-tags?ref=modules/common-tags/v1.0.0"

  environment = "prod"
  service     = "user-api"
  team        = "backend-team"
  owner       = "backend-team@company.com"
  cost_center = "product-development"
}

module "app_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=modules/ecs-service/v2.1.0"

  name              = "prod-user-api-service"
  cluster_id        = var.cluster_id
  vpc_id            = var.vpc_id
  subnet_ids        = var.subnet_ids
  desired_count     = 3
  cpu               = 512
  memory            = 1024
  enable_autoscaling = true

  common_tags = module.common_tags.tags
}
```

#### 대체 Git 프로토콜

**SSH(SSH 키를 사용하는 프라이빗 리포지토리용)**:
```hcl
module "example" {
  source = "git::ssh://git@github.com/{org}/{repo}.git//{path}?ref={version}"
}
```

**자격증명을 포함한 HTTPS(비권장, SSH 또는 토큰 사용 권장)**:
```hcl
# Avoid hardcoding credentials
# Use environment variables or SSH keys
```

#### 로컬 개발 참조

모듈 개발/테스트 중에는 로컬 경로를 사용하세요:

```hcl
module "app_service" {
  source = "../../modules/ecs-service"  # Relative path

  # Same inputs as production
  name = "dev-user-api-service"
  # ...
}
```

**워크플로우**:
1. **개발**: 로컬 경로 사용 `source = "../../modules/ecs-service"`
2. **테스트**: `terraform init`, `terraform plan` 으로 검증
3. **프로덕션**: 버전을 포함한 Git URL로 전환 `source = "git::...?ref=v1.0.0"`

### 버전 관리 전략

#### 시맨틱 버저닝

모든 중앙 모듈은 [Semantic Versioning 2.0.0](https://semver.org/)을 따릅니다:

```
{MAJOR}.{MINOR}.{PATCH}
```

**버전 구성 요소**:
- **MAJOR** (1.0.0 → 2.0.0): 코드 변경이 필요한 파괴적 변경
- **MINOR** (1.0.0 → 1.1.0): 신규 기능, 하위 호환 유지
- **PATCH** (1.0.0 → 1.0.1): 버그 수정, 하위 호환 유지

**예시**:

| 변경 유형 | 예시 | 버전 영향 |
|----------|------|-----------|
| 필수 변수 추가 | `variable "new_required" {}` | **MAJOR** 1.0.0 → 2.0.0 |
| 변수 제거 | `variable "old_var"` 제거 | **MAJOR** 1.0.0 → 2.0.0 |
| 선택 변수 추가 | `variable "new_opt" { default = "value" }` | **MINOR** 1.0.0 → 1.1.0 |
| 출력 추가 | `output "new_id" { value = aws_resource.id }` | **MINOR** 1.0.0 → 1.1.0 |
| 버그 수정 | 태그 병합 로직 수정 | **PATCH** 1.0.0 → 1.0.1 |
| 문서 업데이트 | README 개선 | **PATCH** 1.0.0 → 1.0.1 |

#### 버전 고정 모범 사례

**프로덕션에서는 항상 특정 버전에 고정하세요**:

```hcl
✅ Good - Explicit version
module "ecs_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=modules/ecs-service/v1.2.0"
}

❌ Bad - No version (uses latest commit)
module "ecs_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service"
}

❌ Bad - Branch reference (unpredictable)
module "ecs_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=main"
}
```

**환경별 버전 고정 전략**:

| 환경 | 전략 | 예시 | 근거 |
|------|------|------|------|
| **Development** | 최신 안정 마이너 | `?ref=v1.2.0` | 신규 기능을 조기에 테스트 |
| **Staging** | 프로덕션 후보와 동일 | `?ref=v1.1.5` | 프로덕션 전 검증 |
| **Production** | 검증 완료된 특정 버전 | `?ref=v1.1.5` | 최대 안정성 |

#### 버전 업그레이드 프로세스

**단계별 업그레이드 워크플로우**:

```
1. Review CHANGELOG
   ↓
2. Identify breaking changes (MAJOR) vs. enhancements (MINOR/PATCH)
   ↓
3. Test in Development
   ↓
4. Validate in Staging
   ↓
5. Deploy to Production
```

**자세한 단계**:

**1. 모듈 변경 로그 확인**
```bash
# View module changelog
cd infrastructure/terraform/modules/ecs-service
cat CHANGELOG.md

# Or visit GitHub releases
# https://github.com/ryuqqq/infrastructure/releases/tag/modules/ecs-service/v2.0.0
```

**2. 버전 영향도 평가**

**MAJOR 버전(파괴적 변경)**:
```hcl
# v1.x.x → v2.x.x requires code changes

# BEFORE (v1.0.0)
module "app_service" {
  source = "git::...?ref=modules/ecs-service/v1.0.0"

  name = "my-service"
  # ...
}

# AFTER (v2.0.0) - Breaking change example
module "app_service" {
  source = "git::...?ref=modules/ecs-service/v2.0.0"

  service_name = "my-service"  # Variable renamed
  # New required variable added
  health_check_grace_period = 60
}
```

**MINOR/PATCH 버전(안전 업그레이드)**:
```hcl
# v1.0.0 → v1.1.0 or v1.0.1 - No code changes needed

module "app_service" {
  source = "git::...?ref=modules/ecs-service/v1.1.0"  # Just update ref

  name = "my-service"
  # Same variables work
}
```

**3. 개발 환경에서 테스트**
```bash
cd infra/terraform/environments/dev

# Update module version
# Edit main.tf to change ?ref=v1.0.0 to ?ref=v2.0.0

# Re-initialize to download new version
terraform init -upgrade

# Review changes
terraform plan

# Expected output for MAJOR version:
# - Some resources will be modified in-place
# - Check for resource recreation (⚠️)
# - Validate expected behavior

# Apply changes
terraform apply
```

**4. 스테이징에서 검증**
```bash
cd ../staging

# Same process as dev
terraform init -upgrade
terraform plan
terraform apply

# Verify service health
# Run integration tests
# Monitor for 24-48 hours
```

**5. 프로덕션에 배포**
```bash
cd ../prod

# Only after successful staging validation
terraform init -upgrade
terraform plan -out=tfplan

# Review plan carefully
# Get approval if required
terraform apply tfplan
```

#### 버전 호환성 매트릭스

**모듈 의존성 추적**:

```hcl
# environments/prod/versions.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

# Track module versions in comments or documentation
# Module Versions (Last Updated: 2025-10-18)
# - common-tags: v1.0.0
# - ecs-service: v2.1.0
# - rds-instance: v1.2.0
# - alb: v1.1.0
```

**버전 호환성 점검**:

각 모듈의 README에는 호환성 정보가 포함됩니다:

```markdown
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws provider | >= 5.0.0 |

## Compatible Module Versions

This module is tested with:
- common-tags: v1.x.x
- security-group: v1.x.x
- iam-role-policy: v1.x.x
```

### 모듈 버전 의사결정 트리

```
Need to use a central module?
│
├─ Development/Testing?
│  └─ Use latest stable MINOR version
│     Example: ?ref=modules/ecs-service/v1.2.0
│
├─ Staging Environment?
│  └─ Use same version planned for production
│     Example: ?ref=modules/ecs-service/v1.1.5
│
├─ Production Environment?
│  └─ Use specific tested version
│     Example: ?ref=modules/ecs-service/v1.1.5
│
└─ Upgrade existing version?
   ├─ PATCH update (v1.0.0 → v1.0.1)?
   │  └─ Low risk: Review CHANGELOG → Test in dev → Deploy
   │
   ├─ MINOR update (v1.0.0 → v1.1.0)?
   │  └─ Medium risk: Review CHANGELOG → Test in dev → Validate in staging → Deploy
   │
   └─ MAJOR update (v1.0.0 → v2.0.0)?
      └─ High risk: Review migration guide → Update code → Test thoroughly in dev →
         Validate in staging for 48h → Get approval → Deploy with rollback plan
```

### 모듈 업데이트 추적

#### 신규 릴리스 모니터링

**최신 상태를 유지하는 방법**:

1. **GitHub Watch** (Recommended)
   ```
   - Go to: https://github.com/ryuqqq/infrastructure
   - Click "Watch" → "Custom" → Select "Releases"
   - Receive notifications for new module versions
   ```

2. **릴리스 노트 확인(Release Notes Review)**
   ```bash
   # Check recent releases
   gh release list --repo ryuqqq/infrastructure --limit 10

   # View specific release
   gh release view modules/ecs-service/v2.0.0 --repo ryuqqq/infrastructure
   ```

3. **변경 로그 모니터링(Changelog Monitoring)**
   - Subscribe to infrastructure repository updates
   - Review CHANGELOG.md files periodically
   - Attend infrastructure team office hours (if available)

#### 모듈 버전 문서화

**서비스 리포지토리 내**:

Create `infra/MODULE_VERSIONS.md`:
```markdown
# Module Version Tracking

Last Updated: 2025-10-18

## Production Modules

| Module | Version | Last Updated | Notes |
|--------|---------|--------------|-------|
| common-tags | v1.0.0 | 2025-10-01 | Initial version |
| ecs-service | v2.1.0 | 2025-10-15 | Upgraded for autoscaling improvements |
| rds-instance | v1.2.0 | 2025-10-10 | Security patches |
| alb | v1.1.0 | 2025-10-05 | Added WAF support (not using yet) |

## Planned Upgrades

| Module | Current | Target | Timeline | Owner |
|--------|---------|--------|----------|-------|
| ecs-service | v2.1.0 | v2.2.0 | 2025-11-01 | @backend-team |
| rds-instance | v1.2.0 | v1.3.0 | 2025-11-15 | @backend-team |

## Upgrade History

### 2025-10-15: ecs-service v2.0.0 → v2.1.0
- **Reason**: Improved autoscaling metrics
- **Impact**: No breaking changes
- **Validation**: Tested in dev (10/12), staging (10/14)
- **Result**: Deployed successfully
```

### 흔한 이슈와 해결책

#### 이슈 1: 모듈을 찾을 수 없음

**오류**:
```
Error: Failed to download module
Module source: git::https://github.com/org/infrastructure.git//terraform/modules/wrong-name?ref=v1.0.0
Could not download module
```

**해결**:
```bash
# 1. Verify module exists
ls infrastructure/terraform/modules/

# 2. Check exact path spelling
# Correct: ecs-service (kebab-case)
# Wrong:   ecs_service, ecsService

# 3. Verify tag exists
git ls-remote --tags https://github.com/ryuqqq/infrastructure.git | grep "modules/ecs-service"
```

#### 이슈 2: 버전을 찾을 수 없음

**Error**:
```
Error: Failed to checkout ref
Ref: modules/ecs-service/v1.0.0 does not exist
```

**Solutions**:
```bash
# 1. List available versions
git ls-remote --tags https://github.com/ryuqqq/infrastructure.git | grep "modules/ecs-service"

# 2. Check GitHub releases
# Visit: https://github.com/ryuqqq/infrastructure/releases

# 3. Use existing version
# Update ?ref= to valid version tag
```

#### 이슈 3: 호환되지 않는 버전

**Error**:
```
Error: Unsupported Terraform version
Module requires: >= 1.5.0
Current version: 1.3.0
```

**Solutions**:
```bash
# 1. Upgrade Terraform
brew upgrade terraform  # macOS
# or download from: https://www.terraform.io/downloads

# 2. Or use compatible module version
# Check module's CHANGELOG for older versions with lower requirements
```

#### 이슈 4: 인증 실패

**Error**:
```
Error: Failed to clone repository
Authentication failed for 'https://github.com/org/infrastructure.git'
```

**Solutions**:
```bash
# 1. Use SSH instead of HTTPS (recommended for private repos)
source = "git::ssh://git@github.com/org/infrastructure.git//path?ref=version"

# 2. Configure Git credentials
git config --global credential.helper store

# 3. Use GitHub token
export GIT_TOKEN=your_token
# Or configure in ~/.netrc
```

### 모범 사례 요약

**해야 할 것**:
- ✅ Always pin to specific versions in production (`?ref=modules/name/v1.0.0`)
- ✅ Read CHANGELOG before upgrading
- ✅ Test upgrades in dev → staging → prod sequence
- ✅ Document module versions in your repository
- ✅ Use semantic versioning for understanding impact
- ✅ Subscribe to release notifications
- ✅ Validate with `terraform plan` before applying

**하지 말아야 할 것**:
- ❌ Use branch names as refs (`?ref=main`)
- ❌ Omit version entirely (unpredictable)
- ❌ Skip testing in lower environments
- ❌ Upgrade multiple major versions at once
- ❌ Ignore breaking changes in MAJOR updates
- ❌ Mix local and Git references for same module across environments

### 관련 문서

For deeper understanding of module management:

- **[Module Versioning Guide](../../modules/VERSIONING.md)** - Detailed versioning strategy and Git tagging rules
- **[Module Standards Guide](../../modules/MODULE_STANDARDS_GUIDE.md)** - Coding conventions and best practices
- **[Terraform Modules Catalog](../../../terraform/modules/README.md)** - Complete list of available modules
- **[Module Directory Structure](../../modules/MODULES_DIRECTORY_STRUCTURE.md)** - Module organization patterns

---

## Terraform 백엔드 구성

### 개요

Terraform backend configuration is critical for team collaboration and safe infrastructure management. Remote state storage in S3 with DynamoDB locking ensures that:

- **Multiple team members** can work on infrastructure without conflicts
- **State is centralized** and accessible to the entire team
- **State history is preserved** with S3 versioning
- **Concurrent modifications are prevented** through state locking
- **Sensitive data is encrypted** at rest and in transit

### 리모트 상태가 중요한 이유

#### 로컬 상태의 문제

**Local state files** (`terraform.tfstate` on your machine) create several problems:

- ❌ **No collaboration**: Team members can't see or use each other's infrastructure state
- ❌ **No locking**: Risk of concurrent modifications corrupting state
- ❌ **No history**: No backup if state file is lost or corrupted
- ❌ **Security risk**: Sensitive data stored in plain text on local disk
- ❌ **Manual sharing**: Difficult to share state for team workflows

#### 리모트 상태의 이점

**Remote state with S3 backend** solves these problems:

- ✅ **Team collaboration**: Centralized state accessible to all team members
- ✅ **State locking**: DynamoDB prevents concurrent modifications
- ✅ **Version history**: S3 versioning provides rollback capability
- ✅ **Encryption**: Data encrypted at rest with KMS
- ✅ **Access control**: IAM policies control who can read/write state
- ✅ **Durability**: S3 provides 99.999999999% durability

### 백엔드 구성 구조

#### 표준 backend.tf

Create a `backend.tf` file in each environment directory:

```hcl
# File: infra/terraform/environments/prod/backend.tf
# Purpose: Configure remote state backend for production environment

terraform {
  backend "s3" {
    # S3 bucket for state storage
    bucket = "myorg-terraform-state"

    # State file path within bucket
    key = "services/{service-name}/{environment}/terraform.tfstate"

    # AWS region for state bucket
    region = "ap-northeast-2"

    # Enable encryption at rest
    encrypt = true

    # KMS key for encryption (optional but recommended)
    kms_key_id = "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"

    # DynamoDB table for state locking
    dynamodb_table = "terraform-state-lock"
  }
}
```

#### 구성 요소

**S3 버킷**(`bucket`):
- **Purpose**: Store Terraform state files
- **Naming**: Organization-wide bucket (e.g., `myorg-terraform-state`)
- **Creation**: Created once by platform team, shared across all services
- **Features**: Versioning enabled, encryption required, lifecycle policies configured

**상태 키**(`key`):
- **Purpose**: Path to state file within S3 bucket
- **Pattern**: `services/{service-name}/{environment}/terraform.tfstate`
- **Examples**:
  - `services/user-api/prod/terraform.tfstate`
  - `services/payment-service/staging/terraform.tfstate`
  - `shared/network/terraform.tfstate`
- **Isolation**: Each environment has separate state file

**리전**(`region`):
- **Purpose**: AWS region where state bucket is located
- **Recommendation**: Use your primary infrastructure region
- **Consistency**: Should match your main infrastructure region

**암호화**(`encrypt`):
- **Purpose**: Enable server-side encryption for state files
- **Required**: Always set to `true`
- **Protection**: Encrypts state at rest in S3

**KMS 키**(`kms_key_id`):
- **Purpose**: Customer-managed encryption key for enhanced security
- **Optional**: Can omit to use AWS-managed keys (SSE-S3)
- **Recommended**: Use KMS for production environments
- **Format**: Full KMS key ARN

**DynamoDB 테이블**(`dynamodb_table`):
- **Purpose**: Implement state locking mechanism
- **Required**: Strongly recommended for team environments
- **Naming**: Organization-wide table (e.g., `terraform-state-lock`)
- **Partition Key**: Must be `LockID` (string type)

### 환경별 백엔드 구성

#### 개발 환경

```hcl
# File: infra/terraform/environments/dev/backend.tf

terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "services/user-api/dev/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

**개발 환경 특징**:
- Rapid iteration and frequent changes
- Lower security requirements (but still encrypted)
- Can use AWS-managed encryption (no KMS key required)
- Full state locking still recommended

#### 스테이징 환경

```hcl
# File: infra/terraform/environments/staging/backend.tf

terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "services/user-api/staging/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    dynamodb_table = "terraform-state-lock"
  }
}
```

**스테이징 특징**:
- Production-like configuration
- KMS encryption recommended
- State locking required
- Separate state from production

#### 프로덕션 환경

```hcl
# File: infra/terraform/environments/prod/backend.tf

terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "services/user-api/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    dynamodb_table = "terraform-state-lock"
  }
}
```

**프로덕션 특징**:
- Maximum security configuration
- KMS encryption required
- State locking mandatory
- Strict access controls via IAM
- S3 versioning and lifecycle policies

### 상태 관리 모범 사례

#### 상태 파일 구성

**디렉터리 기반 접근**(권장):
```
S3 Bucket: myorg-terraform-state/
├── services/
│   ├── user-api/
│   │   ├── dev/terraform.tfstate
│   │   ├── staging/terraform.tfstate
│   │   └── prod/terraform.tfstate
│   ├── payment-service/
│   │   ├── dev/terraform.tfstate
│   │   ├── staging/terraform.tfstate
│   │   └── prod/terraform.tfstate
│   └── notification-service/
│       └── prod/terraform.tfstate
└── shared/
    ├── network/terraform.tfstate
    └── kms/terraform.tfstate
```

**장점**:
- Clear separation between services and environments
- Easy to manage IAM permissions per service
- Intuitive navigation and discovery
- No workspace confusion

**워크스페이스 기반 접근**(서비스 리포에 비권장):
```
S3 Bucket: myorg-terraform-state/
└── services/
    └── user-api/
        ├── terraform.tfstate (default workspace)
        ├── env:/dev/terraform.tfstate
        ├── env:/staging/terraform.tfstate
        └── env:/prod/terraform.tfstate
```

**비권장 이유**:
- Complex workspace management
- Easy to forget which workspace you're in
- Harder to implement fine-grained IAM permissions
- Risk of accidentally applying to wrong workspace

#### 상태 락킹 메커니즘

**상태 락킹 동작 방식**:

1. **Before `terraform apply`**:
   ```
   Terraform → DynamoDB: Create lock item with LockID
   ↓
   Lock acquired? → Proceed with operation
   Lock exists? → Wait or fail
   ```

2. **During operation**:
   ```
   DynamoDB maintains lock item
   Other users/processes blocked from acquiring lock
   ```

3. **After operation completes**:
   ```
   Terraform → DynamoDB: Delete lock item
   Lock released → Next operation can proceed
   ```

**DynamoDB 락 테이블 구조**:
```hcl
# Platform team creates this once
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "terraform-state-lock"
    Purpose   = "Terraform state locking"
    ManagedBy = "Terraform"
  }
}
```

**락 동작**:
- ✅ **Prevents concurrent modifications**: Only one operation at a time
- ✅ **Automatic lock release**: Released after successful apply/destroy
- ✅ **Force unlock capability**: Can manually unlock if operation crashes
- ⚠️ **Lock timeout**: Default 10 minutes, configurable

#### 보안 고려사항

**S3 버킷 보안**:

```hcl
# Platform team S3 bucket configuration
resource "aws_s3_bucket" "terraform_state" {
  bucket = "myorg-terraform-state"

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "terraform-state"
    Purpose   = "Terraform state storage"
    ManagedBy = "Terraform"
  }
}

# Enable versioning for state history
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**IAM 접근 제어**:

```hcl
# Service team IAM policy for state access
resource "aws_iam_policy" "user_api_state_access" {
  name        = "user-api-terraform-state-access"
  description = "Allow user-api team to access their Terraform state"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::myorg-terraform-state"
        Condition = {
          StringLike = {
            "s3:prefix" = "services/user-api/*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::myorg-terraform-state/services/user-api/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:ap-northeast-2:123456789012:table/terraform-state-lock"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
      }
    ]
  })
}
```

**보안 모범 사례**:
- ✅ Always enable S3 bucket versioning for state history
- ✅ Use KMS encryption for production environments
- ✅ Implement least-privilege IAM policies per service
- ✅ Enable S3 bucket logging for audit trail
- ✅ Block public access to state bucket
- ✅ Use MFA delete for production state bucket
- ✅ Regularly review state access logs

#### 상태 파일 버저닝

**S3 버저닝의 이점**:
- **Rollback capability**: Recover from corrupted state
- **Audit trail**: Track state changes over time
- **Disaster recovery**: Restore deleted state files
- **Safety net**: Protection against accidental modifications

**상태 버전 조회**:
```bash
# List state file versions
aws s3api list-object-versions \
  --bucket myorg-terraform-state \
  --prefix services/user-api/prod/terraform.tfstate

# Download specific version
aws s3api get-object \
  --bucket myorg-terraform-state \
  --key services/user-api/prod/terraform.tfstate \
  --version-id {version-id} \
  terraform.tfstate.backup
```

**수명주기 정책**:
```hcl
# Retain old versions for disaster recovery
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }
}
```

### 설정 사전 준비

#### 필요한 AWS 리소스

Before configuring backend for your service, ensure these resources exist (created by platform team):

1. **S3 Bucket for State Storage**:
   - Bucket name: `myorg-terraform-state`
   - Region: `ap-northeast-2` (or your infrastructure region)
   - Versioning: Enabled
   - Encryption: Enabled with KMS
   - Public access: Blocked

2. **DynamoDB Table for Locking**:
   - Table name: `terraform-state-lock`
   - Partition key: `LockID` (String type)
   - Billing mode: PAY_PER_REQUEST (recommended)

3. **KMS Key for Encryption** (optional but recommended):
   - Key alias: `alias/terraform-state`
   - Key policy: Allow service teams to use for encryption/decryption

4. **IAM Permissions**:
   - S3: Read/Write access to your service's state path
   - DynamoDB: Read/Write access to lock table
   - KMS: Encrypt/Decrypt permissions on state encryption key

#### 사전 준비 검증

```bash
# Check S3 bucket exists
aws s3 ls s3://myorg-terraform-state/

# Check DynamoDB table exists
aws dynamodb describe-table --table-name terraform-state-lock

# Check KMS key exists (optional)
aws kms describe-key --key-id alias/terraform-state

# Verify your IAM permissions
aws sts get-caller-identity
```

### 초기 백엔드 구성

#### 1단계: backend.tf 생성

Create `backend.tf` in your environment directory:

```bash
# Navigate to environment directory
cd infra/terraform/environments/dev

# Create backend.tf
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "services/user-api/dev/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
EOF
```

#### 2단계: 백엔드 초기화

```bash
# Initialize Terraform with backend configuration
terraform init

# Expected output:
# Initializing the backend...
# Successfully configured the backend "s3"!
#
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0.0"...
# - Installing hashicorp/aws v5.0.1...
#
# Terraform has been successfully initialized!
```

#### 3단계: 백엔드 구성 검증

```bash
# Verify backend is configured
terraform show

# Check state file location
aws s3 ls s3://myorg-terraform-state/services/user-api/dev/

# Verify state locking (attempt concurrent operation)
# Terminal 1:
terraform plan

# Terminal 2 (should fail with lock error):
terraform plan
# Error: Error acquiring the state lock
```

### 로컬 상태에서 리모트 상태로 마이그레이션

#### 시나리오: 기존 로컬 상태

If you've been working with local state and need to migrate to remote state:

**단계별 마이그레이션**:

1. **Backup Local State**:
   ```bash
   # Create backup of local state
   cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)
   ```

2. **Create backend.tf**:
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "myorg-terraform-state"
       key            = "services/user-api/dev/terraform.tfstate"
       region         = "ap-northeast-2"
       encrypt        = true
       dynamodb_table = "terraform-state-lock"
     }
   }
   ```

3. **Reinitialize Terraform**:
   ```bash
   terraform init

   # Terraform will detect state migration:
   # Backend configuration changed!
   #
   # Terraform has detected that the configuration specified for the backend
   # has changed. Terraform will now check for existing state in the backends.
   #
   # Do you want to copy existing state to the new backend?
   #   Enter a value: yes
   ```

4. **Confirm Migration**:
   ```bash
   # Verify state was migrated
   aws s3 ls s3://myorg-terraform-state/services/user-api/dev/
   # Should show: terraform.tfstate

   # Verify local state is no longer used
   terraform plan
   # Should reference remote state, not local
   ```

5. **Clean Up Local State** (optional):
   ```bash
   # Remove local state file (keep backup)
   rm terraform.tfstate

   # Keep backup for safety
   ls terraform.tfstate.backup.*
   ```

**중요 참고사항**:
- ⚠️ **Team coordination**: Notify team before migration
- ✅ **Backup first**: Always backup local state before migration
- ✅ **Verify migration**: Ensure state was copied correctly
- ✅ **Test operations**: Run `terraform plan` to confirm remote state works
- ⚠️ **One-time operation**: Migration happens once during `terraform init`

### 멀티 리전 고려사항

#### 크로스 리전 상태 접근

If your infrastructure spans multiple regions, consider:

**옵션 1: 단일 리전 상태 버킷**(권장):
```hcl
# All environments use same region state bucket
terraform {
  backend "s3" {
    bucket = "myorg-terraform-state"
    key    = "services/user-api/prod-us-east-1/terraform.tfstate"
    region = "ap-northeast-2"  # State bucket region
    # Resources can be in any region
  }
}
```

**Advantages**:
- Centralized state management
- Simpler access control
- Lower cost (single bucket)

**옵션 2: 리전별 상태 버킷**:
```hcl
# US region infrastructure
terraform {
  backend "s3" {
    bucket = "myorg-terraform-state-us-east-1"
    key    = "services/user-api/prod/terraform.tfstate"
    region = "us-east-1"
  }
}

# Asia region infrastructure
terraform {
  backend "s3" {
    bucket = "myorg-terraform-state-ap-northeast-2"
    key    = "services/user-api/prod/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
```

**Advantages**:
- Data locality compliance
- Lower latency for region-specific ops
- Regional isolation

**고려사항**:
- More complex management
- Higher cost (multiple buckets)
- Duplicate lock tables needed

### 백엔드 공통 문제 해결

#### Issue 1: Backend Configuration Change Error

**Error**:
```
Error: Backend configuration changed

A change in the backend configuration has been detected, which may require
migrating existing state.

If you wish to attempt automatic migration of the state, use "terraform init -migrate-state".
```

**해결**:
```bash
# Option 1: Migrate state to new backend
terraform init -migrate-state

# Option 2: Reconfigure backend (overwrites state location)
terraform init -reconfigure

# Option 3: Cancel and review changes
# Review backend.tf changes carefully before migrating
```

**옵션별 사용 시점**:
- `-migrate-state`: When intentionally moving state to new backend
- `-reconfigure`: When correcting a backend configuration mistake (⚠️ careful!)
- Review first: When unsure what changed in backend.tf

#### Issue 2: State Lock Timeout

**Error**:
```
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        a1b2c3d4-5e6f-7g8h-9i0j-k1l2m3n4o5p6
  Path:      myorg-terraform-state/services/user-api/prod/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Created:   2025-10-18 10:30:00 UTC

Terraform acquires a state lock to protect the state from being written
by multiple users at the same time. Please resolve the issue above and try
again. For most commands, you can disable locking with the "-lock=false"
flag, but this is not recommended.
```

**원인**: 다른 작업이 진행 중이거나 비정상 종료로 락이 해제되지 않음

**해결 1: 락 해제 대기**:
```bash
# Check who has the lock
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "myorg-terraform-state/services/user-api/prod/terraform.tfstate"}}'

# Wait for operation to complete
# Lock will auto-release when operation finishes
```

**해결 2: 강제 해제(Force Unlock)** (⚠️ 주의해서 사용):
```bash
# Only if you're certain no operation is running
terraform force-unlock a1b2c3d4-5e6f-7g8h-9i0j-k1l2m3n4o5p6

# Verify no other team members are running operations
# This could corrupt state if used incorrectly
```

**예방**:
- Always complete or cancel operations properly (Ctrl+C gracefully)
- Communicate with team before long-running operations
- Use CI/CD for apply operations to avoid manual lock issues

#### Issue 3: Access Denied to State Bucket

**Error**:
```
Error: error configuring S3 Backend: error validating provider credentials:
error calling sts:GetCallerIdentity: operation error STS: GetCallerIdentity

Error: AccessDenied: Access Denied
```

**원인**: S3 버킷 또는 KMS 키에 대한 IAM 권한 부족

**Solution**:
```bash
# Check your IAM identity
aws sts get-caller-identity

# Verify S3 bucket access
aws s3 ls s3://myorg-terraform-state/services/user-api/

# Verify KMS key permissions
aws kms describe-key --key-id alias/terraform-state

# Contact platform team to grant permissions:
# - S3: Read/Write on services/{your-service}/* path
# - DynamoDB: Read/Write on terraform-state-lock table
# - KMS: Encrypt/Decrypt on terraform state key
```

**필요한 IAM 권한**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::myorg-terraform-state",
      "Condition": {
        "StringLike": {
          "s3:prefix": "services/your-service/*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::myorg-terraform-state/services/your-service/*"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:DeleteItem"],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-lock"
    },
    {
      "Effect": "Allow",
      "Action": ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"],
      "Resource": "arn:aws:kms:*:*:key/*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "s3.ap-northeast-2.amazonaws.com"
        }
      }
    }
  ]
}
```

#### Issue 4: State File Not Found

**Error**:
```
Error: Failed to get existing workspaces: S3 bucket does not exist.

The referenced S3 bucket must have been previously created. If the S3 bucket
was created within the last minute, please wait for a minute or two and try again.
```

**Cause**: S3 bucket or state file doesn't exist

**Solution**:
```bash
# Verify bucket exists
aws s3 ls | grep terraform-state

# If bucket doesn't exist, contact platform team to create it
# If bucket exists but state file doesn't, this is expected for first init

# For first-time setup:
terraform init  # Creates empty state
terraform plan  # Plan infrastructure
terraform apply # Create resources and state
```

#### Issue 5: DynamoDB Table Not Found

**Error**:
```
Error: error acquiring the state lock: ResourceNotFoundException:
Requested resource not found: Table: terraform-state-lock not found
```

**Cause**: DynamoDB lock table doesn't exist

**Solution**:
```bash
# Verify table exists
aws dynamodb describe-table --table-name terraform-state-lock

# If table doesn't exist, contact platform team to create it
# Temporary workaround (not recommended for team environments):
# Remove dynamodb_table from backend.tf (disables locking)
```

#### Issue 6: State File Corruption

**Error**:
```
Error: state snapshot was created by Terraform v1.6.0, which is newer than
current v1.5.7; upgrade to Terraform v1.6.0 or greater to work with this state
```

**Cause**: State file created by newer Terraform version

**Solution 1: Upgrade Terraform**:
```bash
# Check current version
terraform version

# Upgrade Terraform
# macOS
brew upgrade terraform

# Verify upgrade
terraform version
```

**Solution 2: Rollback State** (if upgrade not possible):
```bash
# Download previous state version from S3
aws s3api list-object-versions \
  --bucket myorg-terraform-state \
  --prefix services/user-api/prod/terraform.tfstate

# Download specific version
aws s3api get-object \
  --bucket myorg-terraform-state \
  --key services/user-api/prod/terraform.tfstate \
  --version-id {previous-version-id} \
  terraform.tfstate

# Upload as current state (⚠️ careful - team coordination required)
aws s3 cp terraform.tfstate \
  s3://myorg-terraform-state/services/user-api/prod/terraform.tfstate
```

### Backend Configuration Checklist

Before deploying infrastructure with remote backend:

- [ ] **S3 bucket exists** and is accessible
- [ ] **DynamoDB table exists** with `LockID` partition key
- [ ] **KMS key configured** (for production environments)
- [ ] **IAM permissions granted** for S3, DynamoDB, and KMS
- [ ] **backend.tf created** in each environment directory
- [ ] **State key path follows convention**: `services/{service}/{env}/terraform.tfstate`
- [ ] **Encryption enabled** with `encrypt = true`
- [ ] **State locking enabled** with `dynamodb_table`
- [ ] **Terraform initialized** with `terraform init`
- [ ] **Backend verified** with test `terraform plan`
- [ ] **Team notified** of backend configuration
- [ ] **Documentation updated** with backend details

### Related Documentation

For more information on backend configuration:

- **[Terraform Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)** - Official S3 backend reference
- **[State Management Best Practices](https://www.terraform.io/docs/language/state/remote.html)** - Terraform state management guide
- **[AWS S3 Backend Setup](https://developer.hashicorp.com/terraform/language/settings/backends/s3)** - Complete backend setup guide
- **[Security Best Practices](../../governance/SECURITY_SCAN_REPORT_TEMPLATE.md)** - Infrastructure security guidelines

---

## Atlantis Workflow Automation

### Overview

[Atlantis](https://www.runatlantis.io/) is a pull request automation tool for Terraform that enables teams to review and apply infrastructure changes directly from GitHub pull requests. Atlantis bridges the gap between code review workflows and infrastructure deployment by providing automated planning, security scanning, and controlled apply operations.

**What Atlantis Does**:
- Automatically runs `terraform plan` when PRs are opened or updated
- Posts plan output as PR comments for team visibility
- Allows controlled `terraform apply` via PR comments
- Enforces approval and merge requirements before apply
- Manages state locking to prevent concurrent modifications
- Provides audit trail of infrastructure changes

**Why Use Atlantis**:
- **Collaboration**: Team members review infrastructure changes in familiar PR workflow
- **Safety**: Enforces approval requirements and prevents unauthorized applies
- **Visibility**: Plan output visible to all PR reviewers
- **Automation**: Eliminates manual `terraform plan` and `apply` runs
- **Consistency**: Standardizes deployment workflow across all services
- **Audit Trail**: All infrastructure changes tracked through PR history

### atlantis.yaml Configuration

Atlantis is configured via `atlantis.yaml` file in your repository root. This file defines projects, workflows, and automation rules.

#### Basic File Structure

```yaml
version: 3

# Global settings
automerge: false
delete_source_branch_on_merge: false
parallel_plan: false
parallel_apply: false

# Projects configuration
projects:
  - name: project-name
    dir: terraform/path
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

# Workflows
workflows:
  default:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply
```

#### Configuration Components

**Version** (`version`):
- **Purpose**: Atlantis configuration schema version
- **Current**: `version: 3` (latest stable)
- **Compatibility**: Determines available features and syntax

**Global Settings**:

```yaml
# Prevent automatic merging after successful apply
automerge: false

# Keep source branches after merge for audit trail
delete_source_branch_on_merge: false

# Disable parallel operations to prevent plugin cache conflicts
parallel_plan: false
parallel_apply: false
```

**Why Parallel Operations are Disabled**:
- Multiple concurrent Terraform operations can cause plugin cache conflicts
- Race conditions when multiple `terraform init` operations access shared cache
- Error: "text file busy" when plugins are being used by multiple processes
- Sequential execution ensures reliable operation without file locking issues

**Project Definition**:

```yaml
projects:
  - name: user-api-prod
    # Directory containing Terraform configuration
    dir: infra/terraform/environments/prod

    # Terraform workspace (usually 'default' for directory-based isolation)
    workspace: default

    # Terraform version to use
    terraform_version: v1.5.0

    # Autoplan configuration
    autoplan:
      # Trigger plan when these files are modified
      when_modified: ["*.tf", "*.tfvars"]
      # Enable automatic planning on PR creation/update
      enabled: true

    # Requirements before apply is allowed
    apply_requirements: ["approved", "mergeable"]

    # Workflow to use for this project
    workflow: default
```

**Apply Requirements**:
- `approved`: PR must have required approvals
- `mergeable`: PR must pass all checks and have no conflicts
- `undiverged`: Local branch must not be behind base branch

#### Infrastructure Repository Example

From the actual `atlantis.yaml` configuration:

```yaml
version: 3

# Global settings
automerge: false
delete_source_branch_on_merge: false
parallel_plan: false
parallel_apply: false

# Projects configuration
projects:
  # Atlantis Server Infrastructure
  - name: atlantis-prod
    dir: terraform/atlantis
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default

  # Test Infrastructure
  - name: atlantis-test
    dir: terraform/test
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default
```

**Configuration Highlights**:
- Two separate projects for production and test environments
- Both use Terraform v1.5.0 for consistency
- Automatic planning triggers on `.tf` and `.tfvars` changes
- Both require PR approval and mergeable state before apply
- Sequential execution prevents plugin cache conflicts

#### Service Repository Example

For your service repository, create `atlantis.yaml`:

```yaml
version: 3

# Global settings
automerge: false
delete_source_branch_on_merge: false
parallel_plan: false
parallel_apply: false

# Projects configuration
projects:
  # Development environment
  - name: user-api-dev
    dir: infra/terraform/environments/dev
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["**/*.tf", "**/*.tfvars"]
      enabled: true
    apply_requirements: ["mergeable"]  # Dev: less strict, no approval required
    workflow: development

  # Staging environment
  - name: user-api-staging
    dir: infra/terraform/environments/staging
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["**/*.tf", "**/*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]  # Staging: requires approval
    workflow: default

  # Production environment
  - name: user-api-prod
    dir: infra/terraform/environments/prod
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["**/*.tf", "**/*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]  # Prod: requires approval
    workflow: production

# Workflows
workflows:
  # Development workflow - faster iteration
  development:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply

  # Default workflow - standard operations
  default:
    plan:
      steps:
        - init:
            extra_args: ["-upgrade"]
        - plan
    apply:
      steps:
        - apply

  # Production workflow - enhanced validation
  production:
    plan:
      steps:
        - init:
            extra_args: ["-upgrade"]
        - plan
    apply:
      steps:
        - run: terraform fmt -check -recursive
        - run: terraform validate
        - apply
```

**Environment-Specific Configuration**:
- **Development**: No approval required, fast iteration
- **Staging**: Approval required, standard workflow
- **Production**: Approval required, enhanced validation with format and validate checks

### Workflow Customization

Workflows define the exact steps Atlantis executes for `plan` and `apply` operations. You can customize workflows to add validation, security scanning, or custom scripts.

#### Default Workflow

The basic workflow from the infrastructure repository:

```yaml
workflows:
  default:
    plan:
      steps:
        # Disable shared plugin cache to prevent race conditions
        - env:
            name: TF_PLUGIN_CACHE_DIR
            value: ""
        - init:
            extra_args:
              - "-upgrade"
        - plan
    apply:
      steps:
        - apply
```

**Key Steps**:

1. **Environment Variable** (`env`):
   - Disables Terraform plugin cache
   - Prevents "text file busy" errors in concurrent operations
   - Forces project-local plugin installation

2. **Init** (`init`):
   - Initializes Terraform working directory
   - Downloads providers and modules
   - `-upgrade`: Updates providers to latest allowed versions

3. **Plan** (`plan`):
   - Generates execution plan
   - Shows what changes will be made
   - Output posted as PR comment

4. **Apply** (`apply`):
   - Executes planned changes
   - Only runs when explicitly requested via comment
   - Must meet `apply_requirements`

#### Enhanced Validation Workflow

Add security scanning and compliance checks:

```yaml
workflows:
  production:
    plan:
      steps:
        # Step 1: Disable plugin cache
        - env:
            name: TF_PLUGIN_CACHE_DIR
            value: ""

        # Step 2: Initialize Terraform
        - init:
            extra_args: ["-upgrade"]

        # Step 3: Format check
        - run: terraform fmt -check -recursive

        # Step 4: Validate configuration
        - run: terraform validate

        # Step 5: Security scan with tfsec
        - run: |
            tfsec . --format json --out tfsec-results.json || true
            if [ -s tfsec-results.json ]; then
              echo "Security issues found - review tfsec-results.json"
            fi

        # Step 6: Generate plan
        - plan:
            extra_args: ["-out=tfplan"]

        # Step 7: Policy compliance check
        - run: |
            checkov -f tfplan --framework terraform_plan --output json || true

    apply:
      steps:
        # Pre-apply validation
        - run: terraform fmt -check -recursive
        - run: terraform validate

        # Execute apply
        - apply

        # Post-apply notification (optional)
        - run: |
            echo "Apply completed for production environment"
            # Add notification logic here (Slack, email, etc.)
```

**Workflow Features**:
- **Pre-plan validation**: Format and validate before planning
- **Security scanning**: tfsec detects security issues
- **Policy compliance**: checkov validates against policies
- **Pre-apply checks**: Ensures code quality before apply
- **Post-apply hooks**: Notifications or additional actions

#### Environment-Specific Workflows

Different workflows for different environment risk levels:

```yaml
workflows:
  # Fast development workflow
  development:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply

  # Standard staging workflow
  staging:
    plan:
      steps:
        - init:
            extra_args: ["-upgrade"]
        - run: terraform validate
        - plan
    apply:
      steps:
        - apply

  # Strict production workflow
  production:
    plan:
      steps:
        - env:
            name: TF_PLUGIN_CACHE_DIR
            value: ""
        - init:
            extra_args: ["-upgrade", "-backend-config=backend-prod.hcl"]
        - run: terraform fmt -check -recursive
        - run: terraform validate
        - run: ./scripts/validators/check-tags.sh
        - run: ./scripts/validators/check-encryption.sh
        - plan:
            extra_args: ["-out=tfplan"]
        - run: |
            # Cost estimation
            infracost breakdown --path tfplan --format json --out-file cost.json
            # Check cost thresholds
            ./scripts/validators/check-cost.sh cost.json
    apply:
      steps:
        - run: echo "Applying to PRODUCTION - ensure PR is approved"
        - apply
        - run: |
            # Post-apply verification
            terraform output -json > outputs.json
            # Notify team of changes
            ./scripts/notify-deployment.sh
```

**Workflow Progression**:
- **Development**: Minimal checks, fast feedback
- **Staging**: Basic validation, moderate safety
- **Production**: Full validation, maximum safety, cost checks, notifications

#### Custom Steps and Hooks

**Custom Script Execution**:

```yaml
workflows:
  custom:
    plan:
      steps:
        - init
        # Custom pre-plan script
        - run: ./scripts/pre-plan-checks.sh
        - plan
        # Custom post-plan analysis
        - run: ./scripts/analyze-plan.sh
    apply:
      steps:
        # Backup current state
        - run: ./scripts/backup-state.sh
        - apply
        # Run smoke tests
        - run: ./scripts/smoke-tests.sh
```

**Conditional Execution**:

```yaml
workflows:
  conditional:
    plan:
      steps:
        - init
        - plan
        # Only run for production
        - run: |
            if [ "$ATLANTIS_PROJECT_NAME" = "user-api-prod" ]; then
              echo "Running production-specific checks"
              ./scripts/prod-validation.sh
            fi
```

**Multi-Step Init**:

```yaml
workflows:
  multi-region:
    plan:
      steps:
        # Configure AWS credentials
        - run: |
            export AWS_REGION=ap-northeast-2
            export AWS_PROFILE=prod
        # Initialize with specific backend
        - init:
            extra_args:
              - "-backend-config=bucket=myorg-terraform-state"
              - "-backend-config=key=services/${ATLANTIS_PROJECT_NAME}/terraform.tfstate"
        - plan
```

### Automation Rules

Atlantis automation rules control when plans are generated and when applies are allowed.

#### Autoplan Configuration

**Basic Autoplan**:

```yaml
projects:
  - name: user-api-prod
    autoplan:
      # Enable automatic planning
      enabled: true

      # Trigger plan when these files change
      when_modified: ["*.tf", "*.tfvars"]
```

**Advanced Autoplan Patterns**:

```yaml
projects:
  - name: comprehensive-autoplan
    autoplan:
      enabled: true
      # Include patterns (relative to project dir)
      when_modified:
        # Terraform files
        - "*.tf"
        - "*.tfvars"
        # Module changes
        - "../../modules/**/*.tf"
        # Scripts that affect infrastructure
        - "scripts/deploy.sh"
        # Atlantis configuration itself
        - "../../atlantis.yaml"
```

**Conditional Autoplan**:

```yaml
projects:
  # Production: Manual planning only
  - name: user-api-prod
    autoplan:
      enabled: false  # Require explicit 'atlantis plan' command
    apply_requirements: ["approved", "mergeable"]

  # Development: Automatic planning
  - name: user-api-dev
    autoplan:
      enabled: true
      when_modified: ["**/*.tf", "**/*.tfvars"]
    apply_requirements: ["mergeable"]
```

**Why Disable Autoplan for Production**:
- Prevents accidental plan generation from work-in-progress changes
- Requires intentional `atlantis plan` comment
- Gives team more control over when plans are generated
- Reduces noise in high-change PRs

#### Apply Requirements

Control who can apply changes and under what conditions:

**Standard Requirements**:

```yaml
projects:
  - name: production
    apply_requirements:
      - approved         # PR must have required approvals
      - mergeable        # PR must pass all checks
      - undiverged       # Branch must be up to date
```

**Approval Configuration**:

GitHub branch protection rules work with Atlantis:

1. **Configure in GitHub**:
   ```
   Repository Settings → Branches → Branch protection rules

   ✅ Require a pull request before merging
   ✅ Require approvals (1-2 approvers)
   ✅ Dismiss stale pull request approvals when new commits are pushed
   ✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging
   ```

2. **Atlantis Enforces Rules**:
   - Checks if PR has required approvals
   - Verifies all status checks pass
   - Ensures branch is up to date with base
   - Blocks apply if any requirement fails

**Environment-Specific Requirements**:

```yaml
projects:
  # Development: No approval needed
  - name: user-api-dev
    apply_requirements: ["mergeable"]

  # Staging: 1 approval required
  - name: user-api-staging
    apply_requirements: ["approved", "mergeable"]

  # Production: Strict requirements
  - name: user-api-prod
    apply_requirements:
      - approved        # GitHub approval required
      - mergeable       # All checks must pass
      - undiverged      # Must be up to date
```

#### Workspace Management

Atlantis supports Terraform workspaces for multi-environment management:

**Default Workspace** (Recommended for Service Repos):

```yaml
projects:
  # Separate directories for each environment
  - name: user-api-dev
    dir: infra/terraform/environments/dev
    workspace: default  # Always use 'default'

  - name: user-api-prod
    dir: infra/terraform/environments/prod
    workspace: default  # Separate state via directory
```

**Why Use `default` Workspace**:
- Simpler mental model: one directory = one environment
- Clear state file organization in S3
- Easier IAM permission management per environment
- Reduces risk of accidentally applying to wrong workspace

**Multiple Workspaces** (Alternative Pattern):

```yaml
projects:
  # Same directory, different workspaces
  - name: user-api-dev
    dir: infra/terraform
    workspace: dev

  - name: user-api-staging
    dir: infra/terraform
    workspace: staging

  - name: user-api-prod
    dir: infra/terraform
    workspace: prod
```

**Workspace Pattern Trade-offs**:

| Aspect | Directory-Based (Recommended) | Workspace-Based |
|--------|-------------------------------|-----------------|
| **Clarity** | ✅ Explicit environment separation | ⚠️ Must remember current workspace |
| **State Management** | ✅ Separate state files per dir | ⚠️ State files in same S3 prefix |
| **IAM Permissions** | ✅ Easy per-environment control | ⚠️ Complex path-based policies |
| **Configuration** | ✅ Environment-specific tfvars | ⚠️ Shared tfvars or conditionals |
| **Safety** | ✅ Hard to apply to wrong env | ⚠️ Easy to forget workspace switch |
| **Complexity** | ✅ Simple and explicit | ⚠️ Requires workspace discipline |

### Pull Request Integration

Atlantis integrates directly with GitHub pull requests, providing infrastructure change visibility and control within your team's existing code review workflow.

#### How Atlantis Comments Work

**Atlantis Bot Comments**:

When a PR is opened or updated:

1. **Automatic Plan Comment**:
   ```
   Atlantis Plan

   Ran Plan for 2 projects:

   1. project: user-api-dev dir: infra/terraform/environments/dev workspace: default
      ✅ Plan: 3 to add, 2 to change, 0 to destroy.

   2. project: user-api-prod dir: infra/terraform/environments/prod workspace: default
      ✅ Plan: 5 to add, 0 to change, 0 to destroy.
   ```

2. **Plan Output** (collapsed by default):
   ```
   Show Output

   Terraform used the selected providers to generate the following execution plan.
   Resource actions are indicated with the following symbols:
     + create
     ~ update in-place
     - destroy

   Terraform will perform the following actions:

     # aws_ecs_service.app will be created
     + resource "aws_ecs_service" "app" {
         + cluster         = "prod-cluster"
         + desired_count   = 3
         + name            = "user-api-service"
         ...
     }

   Plan: 5 to add, 0 to change, 0 to destroy.
   ```

3. **Apply Result Comment**:
   ```
   Atlantis Apply

   Ran Apply for project: user-api-prod dir: infra/terraform/environments/prod

   Apply: 5 added, 0 changed, 0 destroyed.

   Outputs:

   service_url = "https://api.example.com"
   ```

#### Available Atlantis Commands

Team members interact with Atlantis via PR comments:

**Planning Commands**:

```bash
# Run plan for all projects in PR
atlantis plan

# Run plan for specific project
atlantis plan -p user-api-prod

# Run plan for specific directory
atlantis plan -d infra/terraform/environments/prod

# Force re-plan (ignore cache)
atlantis plan -p user-api-prod --clear-plan-cache
```

**Apply Commands**:

```bash
# Apply all planned changes
atlantis apply

# Apply specific project
atlantis apply -p user-api-prod

# Apply specific directory
atlantis apply -d infra/terraform/environments/prod
```

**Utility Commands**:

```bash
# Show Atlantis version and configuration
atlantis version

# Unlock state if operation crashed
atlantis unlock

# Show help
atlantis help
```

**Command Options**:

| Option | Description | Example |
|--------|-------------|---------|
| `-p PROJECT` | Target specific project by name | `atlantis plan -p user-api-prod` |
| `-d DIR` | Target project by directory | `atlantis plan -d infra/terraform/environments/dev` |
| `-w WORKSPACE` | Target specific workspace | `atlantis plan -w prod` |
| `--verbose` | Show detailed output | `atlantis plan --verbose` |
| `--clear-plan-cache` | Discard cached plan and regenerate | `atlantis plan --clear-plan-cache` |

#### PR Lifecycle with Atlantis

**Complete PR Workflow**:

```
1. Create Feature Branch
   ↓
   git checkout -b feature/add-cache-layer

2. Make Infrastructure Changes
   ↓
   # Edit infra/terraform/environments/prod/main.tf
   # Add ElastiCache resource

3. Create Pull Request
   ↓
   git push origin feature/add-cache-layer
   # Open PR on GitHub

4. Atlantis Auto-Plans (if enabled)
   ↓
   Atlantis bot comments with plan output
   Atlantis Plan
   ✅ Plan: 2 to add, 1 to change, 0 to destroy

5. Team Reviews Changes
   ↓
   Reviewers examine:
   - Terraform plan output
   - Security scan results (if configured)
   - Cost impact (if using Infracost)
   - Code changes

6. Address Review Feedback
   ↓
   # Make code changes
   git commit -am "Address review feedback"
   git push
   # Atlantis automatically re-plans

7. Get Approval
   ↓
   Reviewer approves PR
   ✅ Approved by @team-lead

8. Apply Changes
   ↓
   Comment: atlantis apply -p user-api-prod
   Atlantis executes apply
   Apply: 2 added, 1 changed, 0 destroyed

9. Verify Deployment
   ↓
   Check outputs and verify resources created
   service_url = "https://api.example.com"

10. Merge PR
    ↓
    Merge pull request → main
    (Optionally delete branch)
```

**Handling Multiple Environments**:

When PR affects multiple environments:

```bash
# Scenario: Changes to shared module affect dev, staging, and prod

# PR opened → Atlantis auto-plans all affected projects
Atlantis Plan

1. project: user-api-dev
   ✅ Plan: 1 to add, 0 to change, 0 to destroy

2. project: user-api-staging
   ✅ Plan: 1 to add, 0 to change, 0 to destroy

3. project: user-api-prod
   ✅ Plan: 1 to add, 0 to change, 0 to destroy

# Apply in order: dev → staging → prod
atlantis apply -p user-api-dev
# Verify dev changes

atlantis apply -p user-api-staging
# Verify staging changes

atlantis apply -p user-api-prod
# Verify production changes
```

#### Handling Failed Plans/Applies

**Plan Failures**:

```
Atlantis Plan

Ran Plan for project: user-api-prod
❌ Error: Error running plan:

Error: Reference to undeclared resource
  on main.tf line 23, in resource "aws_ecs_service" "app":
  23:   cluster = aws_ecs_cluster.missing.id
```

**Resolution Steps**:

1. **Review Error Message**:
   - Read Atlantis comment for error details
   - Identify which file and line caused error

2. **Fix Locally**:
   ```bash
   # Fix the error in your code
   vim infra/terraform/environments/prod/main.tf

   # Test locally (optional but recommended)
   cd infra/terraform/environments/prod
   terraform init
   terraform plan
   ```

3. **Push Fix**:
   ```bash
   git commit -am "Fix: Correct ECS cluster reference"
   git push
   # Atlantis automatically re-plans
   ```

**Apply Failures**:

```
Atlantis Apply

Ran Apply for project: user-api-prod
❌ Error applying plan:

Error: Error creating ECS Service: InvalidParameterException:
  Cluster not found
```

**Recovery Steps**:

1. **Understand Failure**:
   - Review apply error output
   - Check if partial apply occurred
   - Verify current state: `terraform state list`

2. **Fix and Re-Plan**:
   ```bash
   # Fix the underlying issue
   git commit -am "Fix: Create ECS cluster before service"
   git push

   # Wait for auto-plan or manually trigger
   atlantis plan -p user-api-prod
   ```

3. **Verify State**:
   ```bash
   # If partial apply occurred, verify state
   atlantis plan -p user-api-prod
   # Check for unexpected changes or drift
   ```

4. **Re-Apply**:
   ```bash
   # Once plan looks correct
   atlantis apply -p user-api-prod
   ```

**State Lock Issues**:

```
Error: Error acquiring the state lock

Lock Info:
  ID:        abc-123-def-456
  Path:      s3://bucket/path/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Created:   2025-10-18 10:30:00 UTC
```

**Unlock State**:

```bash
# Verify no one is actually running terraform
# Then unlock via Atlantis comment
atlantis unlock -p user-api-prod

# Or use Terraform directly if Atlantis fails
terraform force-unlock abc-123-def-456
```

**Prevention**:
- Always complete or cancel operations properly
- Avoid manual `terraform apply` outside Atlantis
- Use `-lock-timeout` for transient lock conflicts
- Coordinate with team before force-unlocking

### Best Practices

#### Project Naming Conventions

**Descriptive Project Names**:

```yaml
✅ Good: Clear and descriptive
projects:
  - name: user-api-prod
  - name: payment-service-staging
  - name: notification-service-dev

❌ Bad: Vague or unclear
projects:
  - name: project1
  - name: prod
  - name: infra
```

**Naming Pattern**:
```
{service-name}-{environment}

Examples:
- user-api-prod
- user-api-staging
- user-api-dev
- payment-service-prod
- notification-service-dev
```

**Benefits**:
- Immediately clear which service and environment
- Easy to filter and search in logs
- Consistent with resource naming conventions
- Reduces errors from targeting wrong project

#### When to Use Different Workflows

**Development Workflow** - Fast Iteration:
```yaml
workflows:
  development:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply
```

**Use When**:
- Rapid development and testing
- Low-risk environment
- Frequent infrastructure changes
- Developer experimentation

**Standard Workflow** - Balanced Approach:
```yaml
workflows:
  default:
    plan:
      steps:
        - init:
            extra_args: ["-upgrade"]
        - run: terraform validate
        - plan
    apply:
      steps:
        - apply
```

**Use When**:
- Staging environments
- Moderate risk tolerance
- Standard change management
- Balance between speed and safety

**Production Workflow** - Maximum Safety:
```yaml
workflows:
  production:
    plan:
      steps:
        - env:
            name: TF_PLUGIN_CACHE_DIR
            value: ""
        - init:
            extra_args: ["-upgrade"]
        - run: terraform fmt -check -recursive
        - run: terraform validate
        - run: ./scripts/validators/check-tags.sh
        - run: ./scripts/validators/check-encryption.sh
        - run: tfsec . --minimum-severity MEDIUM
        - plan:
            extra_args: ["-out=tfplan"]
        - run: infracost breakdown --path tfplan
    apply:
      steps:
        - run: echo "🚨 Applying to PRODUCTION"
        - apply
        - run: ./scripts/notify-deployment.sh
```

**Use When**:
- Production environments
- High-risk changes
- Compliance requirements
- Maximum validation needed

#### Security and Approval Policies

**Approval Requirements by Environment**:

```yaml
projects:
  # Development: Self-service
  - name: service-dev
    apply_requirements: ["mergeable"]
    # Developers can apply without approval

  # Staging: Peer review
  - name: service-staging
    apply_requirements: ["approved", "mergeable"]
    # Requires 1 approval from team member

  # Production: Senior review
  - name: service-prod
    apply_requirements: ["approved", "mergeable"]
    # Requires approval from designated approvers
    # Configure in GitHub: Settings → Branches → Require review from Code Owners
```

**GitHub Branch Protection Setup**:

1. **Create CODEOWNERS file**:
   ```
   # File: .github/CODEOWNERS
   # Production infrastructure requires senior review
   /infra/terraform/environments/prod/ @team-leads @platform-team

   # Staging requires team review
   /infra/terraform/environments/staging/ @backend-team

   # Shared modules require platform team review
   /infra/terraform/modules/ @platform-team
   ```

2. **Configure Branch Protection**:
   ```
   Repository Settings → Branches → Add rule

   Branch name pattern: main

   ✅ Require a pull request before merging
      ✅ Require approvals: 1
      ✅ Require review from Code Owners
      ✅ Dismiss stale pull request approvals when new commits are pushed

   ✅ Require status checks to pass before merging
      ✅ Require branches to be up to date before merging
      Status checks: terraform-plan, security-scan

   ✅ Require conversation resolution before merging
   ✅ Include administrators
   ```

**Security Scanning Integration**:

```yaml
workflows:
  secure:
    plan:
      steps:
        - init
        - run: |
            # Security scan
            tfsec . --format json --out tfsec-results.json
            # Fail on critical issues
            tfsec . --minimum-severity CRITICAL
        - run: |
            # Policy compliance
            checkov -d . --framework terraform --output json
        - plan
```

#### Parallel Execution Considerations

**Why Parallel is Disabled**:

```yaml
# Global setting
parallel_plan: false
parallel_apply: false
```

**Problems with Parallel Execution**:

1. **Plugin Cache Conflicts**:
   ```
   Error: text file busy

   Concurrent terraform init operations race for plugin cache files
   One process locks file while another tries to write
   ```

2. **State Lock Contention**:
   ```
   Multiple projects trying to lock same DynamoDB table
   Unnecessary lock wait times
   Potential deadlocks in complex scenarios
   ```

3. **Resource Exhaustion**:
   ```
   Atlantis server CPU/memory overwhelmed
   Multiple concurrent AWS API calls
   Provider rate limiting issues
   ```

**When Sequential is Better**:
- Small to medium repositories (< 10 projects)
- Projects share dependencies or modules
- Limited Atlantis server resources
- Simpler to debug and understand operation order

**When Parallel May Help**:
- Large repositories (> 20 projects)
- Projects are completely independent
- Powerful Atlantis server infrastructure
- Time-sensitive deployment windows

**Enabling Parallel Safely**:

```yaml
# Only if you have:
# - Powerful Atlantis server (4+ CPU, 8GB+ RAM)
# - Independent projects (no shared modules)
# - Disabled plugin cache (already configured)

parallel_plan: true
parallel_apply: false  # Keep apply sequential for safety

# Project-specific overrides
projects:
  - name: independent-service
    execution_order_group: 1  # Execute in parallel with same group

  - name: another-service
    execution_order_group: 1  # Same group = parallel execution

  - name: dependent-service
    execution_order_group: 2  # Different group = waits for group 1
```

### Common Atlantis Commands Reference

#### Quick Command Reference

```bash
# Planning
atlantis plan                          # Plan all projects
atlantis plan -p PROJECT_NAME          # Plan specific project
atlantis plan -d DIR_PATH              # Plan specific directory
atlantis plan --verbose                # Detailed output
atlantis plan --clear-plan-cache       # Force fresh plan

# Applying
atlantis apply                         # Apply all projects
atlantis apply -p PROJECT_NAME         # Apply specific project
atlantis apply -d DIR_PATH             # Apply specific directory

# Utility
atlantis unlock                        # Unlock all projects
atlantis unlock -p PROJECT_NAME        # Unlock specific project
atlantis version                       # Show Atlantis version
atlantis help                          # Show help message

# Status
# (No explicit status command - plans show current state)
```

#### Workflow Diagrams

**Standard PR Workflow**:

```
┌─────────────────────────────────────────────────────────────┐
│                     PR Opened/Updated                        │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │   Autoplan Enabled?   │
                └───────┬───────────────┘
                        │
           ┌────────────┴────────────┐
           │                         │
          Yes                       No
           │                         │
           ▼                         ▼
  ┌────────────────┐      ┌──────────────────────┐
  │ Atlantis Plan  │      │  Wait for Manual      │
  │  (automatic)   │      │  'atlantis plan'      │
  └────────┬───────┘      └──────────┬───────────┘
           │                         │
           └────────────┬────────────┘
                        │
                        ▼
              ┌─────────────────────┐
              │  Plan Posted to PR  │
              └──────────┬──────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   Team Reviews Plan  │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Changes Requested?   │
              └──────┬───────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
       Yes                       No
        │                         │
        ▼                         ▼
┌───────────────┐      ┌──────────────────┐
│  Fix Issues   │      │   PR Approved?   │
│  Push Update  │      └─────────┬────────┘
└───────┬───────┘                │
        │              ┌──────────┴─────────┐
        │              │                    │
        └──────────────┤                   Yes
                       │                    │
                      No                    ▼
                       │         ┌────────────────────┐
                       │         │ 'atlantis apply'   │
                       │         └─────────┬──────────┘
                       │                   │
                       │                   ▼
                       │         ┌────────────────────┐
                       │         │  Apply Executes    │
                       │         └─────────┬──────────┘
                       │                   │
                       │                   ▼
                       │         ┌────────────────────┐
                       │         │ Success/Failure?   │
                       │         └─────────┬──────────┘
                       │                   │
                       │      ┌────────────┴──────────┐
                       │      │                       │
                       │   Success                 Failure
                       │      │                       │
                       │      ▼                       ▼
                       │  ┌────────┐         ┌──────────────┐
                       │  │ Merge  │         │ Debug & Fix  │
                       │  │   PR   │         └──────────────┘
                       │  └────────┘
                       │
                       └──► (Loop back to review)
```

**Multi-Environment Apply Workflow**:

```
┌─────────────────────────────────────┐
│  PR Affects Multiple Environments   │
└────────────────┬────────────────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │   Atlantis Auto-Plans │
      │   All Environments    │
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │  Review All Plans    │
      │  - Dev               │
      │  - Staging           │
      │  - Production        │
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │  Apply Development   │
      │  'atlantis apply     │
      │   -p service-dev'    │
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │  Verify Dev Changes  │
      │  - Check outputs     │
      │  - Run smoke tests   │
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │  Apply Staging       │
      │  'atlantis apply     │
      │   -p service-staging'│
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │ Verify Staging       │
      │ - Integration tests  │
      │ - Performance tests  │
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │  Get Final Approval  │
      │  for Production      │
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │  Apply Production    │
      │  'atlantis apply     │
      │   -p service-prod'   │
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │ Verify Production    │
      │ - Health checks      │
      │ - Monitoring alerts  │
      └──────────┬───────────┘
                 │
                 ▼
      ┌──────────────────────┐
      │     Merge PR         │
      └──────────────────────┘
```

### Troubleshooting Common Issues

#### Issue 1: Autoplan Not Triggering

**Symptoms**:
- PR opened but Atlantis doesn't comment
- No plan output visible in PR

**Possible Causes & Solutions**:

1. **Autoplan Disabled**:
   ```yaml
   # Check atlantis.yaml
   projects:
     - name: user-api-prod
       autoplan:
         enabled: false  # ← Problem: disabled
   ```

   **Solution**: Enable autoplan
   ```yaml
   autoplan:
     enabled: true
     when_modified: ["*.tf", "*.tfvars"]
   ```

2. **Modified Files Don't Match Pattern**:
   ```yaml
   # atlantis.yaml pattern
   when_modified: ["*.tf"]  # Only matches .tf files

   # But you modified:
   infra/terraform/modules/app/variables.tfvars  # .tfvars not matched
   ```

   **Solution**: Update pattern to include all relevant files
   ```yaml
   when_modified: ["**/*.tf", "**/*.tfvars", "modules/**/*.tf"]
   ```

3. **Files Outside Project Directory**:
   ```yaml
   projects:
     - name: user-api-prod
       dir: infra/terraform/environments/prod
       when_modified: ["*.tf"]  # Only matches files in prod/
   ```

   **Modified file**: `infra/terraform/modules/shared/main.tf` (outside prod/)

   **Solution**: Add module path to `when_modified`
   ```yaml
   when_modified:
     - "*.tf"
     - "*.tfvars"
     - "../../modules/**/*.tf"  # Include module changes
   ```

4. **Atlantis Webhook Not Configured**:
   - GitHub → Repository Settings → Webhooks
   - Verify webhook exists for Atlantis server
   - Check webhook delivery logs for failures

   **Solution**: Reconfigure webhook or contact platform team

#### Issue 2: Apply Requirements Not Met

**Symptoms**:
```
Atlantis Apply

❌ Can't apply a discarded plan. Please run `atlantis plan` first.
```
or
```
❌ Pull request must be approved before running apply.
```

**Possible Causes & Solutions**:

1. **No Approval**:
   ```yaml
   apply_requirements: ["approved", "mergeable"]
   ```

   **Solution**: Get required PR approval
   - Request review from team member
   - Wait for approval before `atlantis apply`

2. **PR Not Mergeable**:
   - Merge conflicts exist
   - Required status checks failing
   - Branch not up to date

   **Solution**:
   ```bash
   # Resolve conflicts
   git pull origin main
   git push

   # Fix failing checks
   # Wait for all checks to pass
   ```

3. **Stale Plan**:
   - Code changed after plan was generated
   - Plan was discarded

   **Solution**:
   ```bash
   # Re-generate plan
   atlantis plan -p user-api-prod

   # Then apply
   atlantis apply -p user-api-prod
   ```

4. **Wrong Project Name**:
   ```bash
   # Typo in project name
   atlantis apply -p user-api-production  # ← Wrong

   # Correct project name from atlantis.yaml
   atlantis apply -p user-api-prod  # ← Correct
   ```

#### Issue 3: Terraform Init Failures

**Symptoms**:
```
Error: Failed to initialize Terraform

Error: Failed to download module "common_tags"
```

**Possible Causes & Solutions**:

1. **Missing AWS Credentials**:
   ```
   Error: error configuring S3 Backend: NoCredentialProviders
   ```

   **Solution**: Verify Atlantis has AWS credentials configured
   - Contact platform team to check Atlantis server IAM role
   - Verify service repository has access to state bucket

2. **Backend Configuration Missing**:
   ```
   Error: Backend initialization required
   ```

   **Solution**: Create or verify `backend.tf`
   ```hcl
   terraform {
     backend "s3" {
       bucket = "myorg-terraform-state"
       key    = "services/user-api/prod/terraform.tfstate"
       region = "ap-northeast-2"
     }
   }
   ```

3. **Module Source Unreachable**:
   ```
   Error: Failed to download module
   Module source: git::https://github.com/org/infrastructure.git//terraform/modules/common-tags?ref=v1.0.0
   ```

   **Solution**: Verify module reference
   - Check Git URL is correct
   - Verify version tag exists
   - Ensure Atlantis can access private repository (SSH key or token)

4. **Plugin Cache Conflicts**:
   ```
   Error: text file busy
   ```

   **Solution**: Already configured in infrastructure repository
   ```yaml
   workflows:
     default:
       plan:
         steps:
           - env:
               name: TF_PLUGIN_CACHE_DIR
               value: ""  # Disables shared cache
           - init
   ```

#### Issue 4: State Lock Conflicts

**Symptoms**:
```
Error: Error acquiring the state lock

Lock Info:
  ID:        abc-123-def-456
  Path:      myorg-terraform-state/services/user-api/prod/terraform.tfstate
  Operation: OperationTypeApply
  Who:       atlantis@hostname
  Created:   2025-10-18 10:30:00 UTC
```

**Possible Causes & Solutions**:

1. **Previous Operation Crashed**:
   - Atlantis server restarted mid-operation
   - Network interruption during apply

   **Solution**: Force unlock
   ```bash
   # Via Atlantis comment
   atlantis unlock -p user-api-prod

   # Or directly with Terraform (if Atlantis fails)
   terraform force-unlock abc-123-def-456
   ```

2. **Concurrent Operations**:
   - Multiple team members trying to apply simultaneously
   - Manual `terraform apply` running outside Atlantis

   **Solution**: Coordinate with team
   - Check who has the lock (from error message)
   - Wait for their operation to complete
   - Communicate via Slack/chat before force-unlocking

3. **Stuck Lock After Failed Apply**:
   - Apply failed but didn't release lock

   **Solution**: Verify no operation running, then unlock
   ```bash
   # Check Atlantis server logs to confirm operation finished
   # Then unlock
   atlantis unlock -p user-api-prod
   ```

4. **Long-Running Operation**:
   - Large infrastructure apply taking longer than expected

   **Solution**: Wait for completion
   - Check Atlantis server logs for progress
   - Increase lock timeout if needed (configure in backend.tf)
   - Don't force-unlock if operation is actually running

#### Issue 5: Plan Shows Unexpected Changes

**Symptoms**:
```
Atlantis Plan

Plan: 10 to add, 5 to change, 3 to destroy

# But you only changed 1 resource
```

**Possible Causes & Solutions**:

1. **State Drift**:
   - Resources modified outside Terraform
   - Manual changes in AWS Console

   **Solution**: Review drift and decide
   ```bash
   # Option 1: Accept drift and update Terraform
   # Commit changes to align Terraform with reality

   # Option 2: Revert manual changes
   # Fix resources in AWS to match Terraform state

   # Option 3: Import resources
   terraform import aws_resource.name resource-id
   ```

2. **Provider Version Upgrade**:
   - Provider schema changes
   - New required attributes

   **Solution**: Review provider changelog
   ```hcl
   # Pin provider version to prevent unexpected changes
   terraform {
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = "~> 5.0.0"  # Pin to specific version
       }
     }
   }
   ```

3. **Module Version Changed**:
   - Module updated with breaking changes
   - New required variables added

   **Solution**: Review module changelog and update code
   ```hcl
   # Before
   module "ecs_service" {
     source = "git::https://github.com/org/infrastructure.git//modules/ecs?ref=v1.0.0"
   }

   # After - update to new version with required variables
   module "ecs_service" {
     source = "git::https://github.com/org/infrastructure.git//modules/ecs?ref=v2.0.0"

     # New required variable in v2.0.0
     health_check_grace_period = 60
   }
   ```

4. **Shared Module Changes**:
   - Another team updated shared module
   - Changes affect your environment

   **Solution**: Coordinate with other teams
   - Review shared module changes
   - Test in dev/staging first
   - Apply production after validation

### Integration with GitHub Actions

Atlantis works alongside GitHub Actions for comprehensive infrastructure automation. While Atlantis handles Terraform workflows, GitHub Actions can provide additional validation and checks.

**Complementary Workflow Pattern**:

```yaml
# .github/workflows/terraform-plan.yml
# Runs in parallel with Atlantis for additional checks

name: Terraform Validation

on:
  pull_request:
    paths:
      - 'infra/terraform/**'

jobs:
  validate:
    name: Additional Validation
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      # Security scanning
      - name: Run tfsec
        run: |
          curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
          tfsec infra/terraform --minimum-severity MEDIUM

      # Policy compliance
      - name: Run Checkov
        run: |
          pip install checkov
          checkov -d infra/terraform --framework terraform

      # Cost estimation
      - name: Infracost
        uses: infracost/actions/setup@v3
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      - name: Generate cost estimate
        run: |
          cd infra/terraform/environments/prod
          terraform init
          terraform plan -out=tfplan
          infracost breakdown --path tfplan
```

**Division of Responsibilities**:

| Tool | Purpose | When It Runs |
|------|---------|--------------|
| **Atlantis** | Terraform plan/apply execution | On PR open/update, manual commands |
| **GitHub Actions** | Security scanning, policy checks, cost estimation | On PR open/update (automated) |
| **Atlantis** | Infrastructure deployment | Manual `atlantis apply` command |
| **GitHub Actions** | Post-deployment verification | After merge to main |

### Related Documentation

For deeper understanding of Atlantis and infrastructure automation:

- **[Atlantis Official Documentation](https://www.runatlantis.io/)** - Complete Atlantis reference
- **[Atlantis Server Configuration](https://www.runatlantis.io/docs/server-configuration.html)** - Server-side setup guide
- **[GitHub Actions Terraform Guide](../setup/github_actions_setup.md)** - CI/CD integration patterns
- **[Terraform Backend Configuration](#terraform-backend-configuration)** - State management setup
- **[Infrastructure Governance](../../governance/infrastructure_governance.md)** - Approval and policy requirements
- **[Security Guidelines](../../governance/SECURITY_SCAN_REPORT_TEMPLATE.md)** - Security scanning standards

---

## File Placement Guidelines

### When to Create Files

#### `main.tf`
- **Always Required**: Every module and environment must have `main.tf`
- **Content**: Primary resource definitions and module calls
- **Size Guideline**: If exceeds 300 lines, consider splitting into resource-specific files

#### `variables.tf`
- **Always Required**: Declare all input variables
- **Organization**: Sort variables alphabetically, required variables first
- **Validation**: Include validation blocks for critical variables

#### `outputs.tf`
- **Always Required**: Export important resource attributes
- **Purpose**: Enable other modules/environments to reference outputs
- **Security**: Mark sensitive outputs with `sensitive = true`

#### `versions.tf`
- **Always Required**: Specify Terraform and provider version constraints
- **Content**:
```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}
```

#### `backend.tf`
- **Required for Environments**: Configure S3 backend for remote state
- **Optional for Modules**: Modules inherit backend from calling environment
- **Security**: Always enable encryption and state locking

#### `provider.tf`
- **Required for Environments**: Configure AWS provider with region and assume role
- **Optional for Modules**: Modules inherit provider from calling environment
- **Pattern**:
```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Service   = var.service_name
    }
  }
}
```

#### `locals.tf` (Optional)
- **When to Create**: When you have complex computed values used across resources
- **Purpose**: DRY principle for repeated expressions
- **Example Use Cases**:
  - Computed tag merging
  - Conditional logic
  - String transformations

#### `data.tf` (Optional)
- **When to Create**: When you have 5+ data sources
- **Purpose**: Centralize external data lookups
- **Example**:
```hcl
data "aws_vpc" "main" {
  tags = {
    Name = "${var.environment}-vpc"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
}
```

#### Resource-Specific Files (Optional)
- **When to Create**:
  - `main.tf` exceeds 300 lines
  - Logical grouping improves readability
  - Team convention prefers resource separation
- **Common Patterns**:
  - `ecs.tf` - ECS cluster, services, task definitions
  - `rds.tf` - RDS instances, parameter groups, subnet groups
  - `security-groups.tf` - All security group definitions
  - `iam.tf` - IAM roles, policies, and attachments
  - `monitoring.tf` - CloudWatch alarms, dashboards, log groups
  - `networking.tf` - VPC, subnets, route tables, gateways

### Where to Place Different Resource Types

#### Compute Resources
- **Location**: `environments/{env}/main.tf` or `environments/{env}/ecs.tf`
- **Resources**: ECS services, task definitions, EC2 instances, Auto Scaling groups
- **Module Pattern**: Use central `ecs-service` module or create service-specific module

#### Database Resources
- **Location**: `environments/{env}/main.tf` or `environments/{env}/rds.tf`
- **Resources**: RDS instances, parameter groups, subnet groups, read replicas
- **Module Pattern**: Use central `rds` module with environment-specific configurations

#### Networking Resources
- **Location**:
  - Shared infrastructure: `shared/network/main.tf`
  - Environment-specific: `environments/{env}/networking.tf`
- **Resources**: VPCs, subnets, route tables, NAT gateways, internet gateways
- **Guideline**: Create VPCs in shared/ if used across environments, otherwise in environments/

#### Security Resources
- **Location**: `environments/{env}/security-groups.tf` or `environments/{env}/iam.tf`
- **Resources**:
  - Security groups and rules
  - IAM roles, policies, and attachments
  - KMS keys and aliases
- **Module Pattern**: Use central `security-group` and `iam-role-policy` modules

#### Monitoring Resources
- **Location**: `environments/{env}/monitoring.tf`
- **Resources**: CloudWatch alarms, dashboards, log groups, metric filters
- **Module Pattern**: Use central `cloudwatch-log-group` module

#### Load Balancing Resources
- **Location**: `environments/{env}/main.tf` or `environments/{env}/load-balancers.tf`
- **Resources**: ALB, NLB, target groups, listeners
- **Module Pattern**: Use central `alb` module with environment-specific configurations

### File Organization Decision Tree

```
Start with main.tf for all resources
│
├─ < 10 resources?
│  └─ YES → Keep everything in main.tf
│
├─ 10-30 resources?
│  └─ YES → Split into 2-3 logical files (ecs.tf, rds.tf, etc.)
│
├─ 30-50 resources?
│  └─ YES → Split into 5-7 resource-type files
│
└─ > 50 resources?
   └─ YES → Consider:
      - Creating service-specific modules
      - Using subdirectories for categories
      - Splitting into multiple environments/layers
```

### Common Mistakes to Avoid

#### ❌ Don't Do This
```
# Mixing application code and infrastructure
service-repository/
├── src/
├── main.tf              # DON'T: Infrastructure at root level
└── variables.tf

# Unclear naming
infra/terraform/
├── module1/             # DON'T: Vague naming
├── stuff/               # DON'T: Unclear purpose
└── new/                 # DON'T: Temporary naming

# No environment separation
infra/terraform/
└── main.tf              # DON'T: Single file for all environments

# Hardcoded values
resource "aws_instance" "app" {
  instance_type = "t3.large"  # DON'T: Hardcode values
  subnet_id     = "subnet-12345"  # DON'T: Hardcode IDs
}
```

#### ✅ Do This Instead
```
# Clear separation and organization
service-repository/
├── infra/
│   └── terraform/
│       ├── modules/
│       │   └── app-service/
│       └── environments/
│           ├── dev/
│           ├── staging/
│           └── prod/
└── src/

# Descriptive naming
infra/terraform/modules/
├── ecs-api-service/
├── rds-primary-database/
└── elasticache-session-store/

# Environment-specific configurations
infra/terraform/environments/
├── dev/
│   ├── main.tf
│   └── terraform.tfvars
├── staging/
│   ├── main.tf
│   └── terraform.tfvars
└── prod/
    ├── main.tf
    └── terraform.tfvars

# Parameterized resources
resource "aws_instance" "app" {
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = module.common_tags.tags
}
```

---

## Your First Infrastructure PR: A Complete Tutorial

### Overview

This hands-on tutorial walks you through creating your first infrastructure pull request from start to finish. You'll deploy a simple ECS service for a new API application, experiencing the complete workflow from branch creation to merge.

**What You'll Build**:
- An ECS Fargate service running a containerized API
- Security groups with proper network isolation
- CloudWatch log groups for application logging
- All integrated with Atlantis for automated planning and deployment

**Learning Objectives**:
- Create proper Terraform configuration structure
- Configure remote state backend correctly
- Set up Atlantis project configuration
- Navigate the PR and review process
- Work with Atlantis commands and plan output
- Handle common issues and troubleshooting

**Time Estimate**: 60-90 minutes for first-time completion

#### Prerequisites Checklist

Before starting, ensure you have:

- [ ] **Repository Access**: Clone or fork access to your service repository
- [ ] **AWS Access**: Valid AWS credentials configured (`aws configure` completed)
- [ ] **Terraform Installed**: Version 1.5.0 or later (`terraform version`)
- [ ] **Git Configured**: Name and email set (`git config user.name` and `user.email`)
- [ ] **GitHub Access**: Ability to create pull requests and request reviews
- [ ] **Infrastructure Repository Access**: Read access to central infrastructure modules
- [ ] **Required Information**:
  - [ ] Service name (e.g., "product-api")
  - [ ] Container image URL (ECR repository or Docker Hub)
  - [ ] VPC ID and subnet IDs for deployment
  - [ ] ECS cluster ID
  - [ ] IAM role ARNs (execution role and task role)

**Verify Prerequisites**:
```bash
# Check Terraform version
terraform version
# Output should be: Terraform v1.5.0 or later

# Check AWS credentials
aws sts get-caller-identity
# Should return your AWS account ID and user/role

# Check Git configuration
git config --list | grep user
# Should show user.name and user.email
```

---

### Step 1: Repository Setup and Branching

#### 1.1 Clone and Inspect Repository

```bash
# Clone your service repository
git clone git@github.com:org/product-api.git
cd product-api

# Check current status and branch
git status
git branch

# Expected output:
# On branch main
# Your branch is up to date with 'origin/main'.
# nothing to commit, working tree clean
```

#### 1.2 Create Feature Branch

**Branch Naming Convention**: Use descriptive names with task/issue reference
- Pattern: `feature/{task-id}-{description}`
- Example: `feature/IN-200-add-ecs-service`

```bash
# Create and switch to feature branch
git checkout -b feature/IN-200-add-ecs-service

# Verify branch creation
git branch
# Output:
#   main
# * feature/IN-200-add-ecs-service
```

**Why Proper Branch Names Matter**:
- Traceable to task management system (Jira, Linear, etc.)
- Clear purpose for reviewers
- Easy to search in Git history
- Professional team collaboration

#### 1.3 Verify Repository Structure

```bash
# Check if infra directory exists
ls -la

# If infra/ doesn't exist, create standard structure
mkdir -p infra/terraform/environments/dev
mkdir -p infra/terraform/environments/staging
mkdir -p infra/terraform/environments/prod

# Verify structure
tree infra/ -L 3
# Expected output:
# infra/
# └── terraform/
#     └── environments/
#         ├── dev/
#         ├── staging/
#         └── prod/
```

**Time Checkpoint**: ~5 minutes elapsed

---

### Step 2: Creating Directory Structure

We'll start with the development environment for safe experimentation.

#### 2.1 Create Development Environment Files

```bash
# Navigate to dev environment
cd infra/terraform/environments/dev

# Create required files
touch main.tf
touch variables.tf
touch terraform.tfvars
touch backend.tf
touch provider.tf
touch outputs.tf
touch README.md

# Verify files created
ls -la
# Expected files:
# main.tf
# variables.tf
# terraform.tfvars
# backend.tf
# provider.tf
# outputs.tf
# README.md
```

#### 2.2 File Purpose Quick Reference

| File | Purpose | Contains |
|------|---------|----------|
| `main.tf` | Resource definitions | Module calls, data sources |
| `variables.tf` | Variable declarations | Input variable definitions (no values) |
| `terraform.tfvars` | Variable values | Environment-specific values |
| `backend.tf` | State configuration | S3 backend setup |
| `provider.tf` | Provider config | AWS provider, region, assume role |
| `outputs.tf` | Output values | Service URLs, ARNs, IDs to export |
| `README.md` | Documentation | Environment description, deployment instructions |

**Time Checkpoint**: ~10 minutes elapsed

---

### Step 3: Writing Terraform Configuration

#### 3.1 Configure Provider (provider.tf)

This file sets up the AWS provider with your region and credentials.

```hcl
# File: infra/terraform/environments/dev/provider.tf
# Purpose: Configure AWS provider for development environment

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"  # Seoul region

  # Default tags applied to all resources
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "dev"
      Service     = "product-api"
    }
  }
}
```

**Configuration Highlights**:
- Terraform version constraint ensures team uses compatible versions
- AWS provider version `~> 5.0` means >= 5.0.0 and < 6.0.0
- Default tags automatically applied to all resources (reduces duplication)
- Region set to Seoul (change to your preferred region)

#### 3.2 Declare Variables (variables.tf)

Variables make your configuration reusable and environment-specific.

```hcl
# File: infra/terraform/environments/dev/variables.tf
# Purpose: Variable declarations for development environment

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "container_image" {
  description = "Docker image URL for the container"
  type        = string
}

variable "container_port" {
  description = "Port on which the container listens"
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Number of tasks to run"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "Task CPU units"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB"
  type        = number
  default     = 512
}

variable "vpc_id" {
  description = "VPC ID where service will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role ARN for ECS task"
  type        = string
}
```

**Variable Best Practices**:
- Clear descriptions for team understanding
- Explicit types for validation
- Sensible defaults for optional values
- No default values for required configuration (forces explicit setting)

#### 3.3 Set Variable Values (terraform.tfvars)

**IMPORTANT**: Replace placeholder values with your actual AWS resource IDs.

```hcl
# File: infra/terraform/environments/dev/terraform.tfvars
# Purpose: Development environment variable values

environment  = "dev"
service_name = "product-api"

# Container configuration
container_image = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/product-api:latest"
container_port  = 8080

# Service sizing
desired_count = 1
cpu           = 256
memory        = 512

# Network configuration
# IMPORTANT: Replace with your actual VPC and subnet IDs
vpc_id     = "vpc-0123456789abcdef0"  # ← Replace this
subnet_ids = [
  "subnet-0123456789abcdef0",         # ← Replace these
  "subnet-0123456789abcdef1"
]

# ECS configuration
# IMPORTANT: Replace with your actual cluster ID
cluster_id = "arn:aws:ecs:ap-northeast-2:123456789012:cluster/dev-cluster"

# IAM roles
# IMPORTANT: Replace with your actual IAM role ARNs
execution_role_arn = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
task_role_arn      = "arn:aws:iam::123456789012:role/ecsTaskRole"
```

**How to Find Your Values**:

```bash
# Find VPC ID
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table

# Find Subnet IDs (private subnets for ECS tasks)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxx" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' --output table

# Find ECS Cluster
aws ecs list-clusters
aws ecs describe-clusters --clusters dev-cluster

# Find IAM Roles
aws iam get-role --role-name ecsTaskExecutionRole --query 'Role.Arn'
aws iam get-role --role-name ecsTaskRole --query 'Role.Arn'
```

#### 3.4 Define Main Resources (main.tf)

This is where you compose modules and resources.

```hcl
# File: infra/terraform/environments/dev/main.tf
# Purpose: Main resource definitions for product-api development environment

# Data source: Get current AWS region
data "aws_region" "current" {}

# Common tags module - provides standardized tags for all resources
module "common_tags" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/common-tags?ref=v1.0.0"

  environment = var.environment
  service     = var.service_name
  team        = "product-team"
  owner       = "product-team@company.com"
  cost_center = "product-development"
}

# Security group for ECS tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-${var.service_name}-ecs-tasks"
  description = "Security group for ${var.service_name} ECS tasks in ${var.environment}"
  vpc_id      = var.vpc_id

  # Ingress: Allow traffic on container port from within VPC
  ingress {
    description = "Allow inbound traffic on container port"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Adjust to your VPC CIDR
  }

  # Egress: Allow all outbound traffic (for pulling images, API calls, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    module.common_tags.tags,
    {
      Name = "${var.environment}-${var.service_name}-ecs-tasks"
    }
  )
}

# CloudWatch Log Group for container logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.environment}/${var.service_name}"
  retention_in_days = 7

  tags = module.common_tags.tags
}

# ECS Service using central module
module "ecs_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=v1.0.0"

  # Service identification
  name           = "${var.environment}-${var.service_name}"
  cluster_id     = var.cluster_id
  container_name = var.service_name
  container_port = var.container_port

  # Container configuration
  container_image = var.container_image
  cpu             = var.cpu
  memory          = var.memory
  desired_count   = var.desired_count

  # Network configuration
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.ecs_tasks.id]
  assign_public_ip   = false

  # IAM roles
  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn

  # Container environment variables
  container_environment = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "SERVICE_NAME"
      value = var.service_name
    },
    {
      name  = "PORT"
      value = tostring(var.container_port)
    }
  ]

  # Logging configuration
  log_configuration = {
    log_driver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.app.name
      "awslogs-region"        = data.aws_region.current.name
      "awslogs-stream-prefix" = "ecs"
    }
  }

  # Deployment configuration
  deployment_circuit_breaker_enable   = true
  deployment_circuit_breaker_rollback = true
  deployment_maximum_percent          = 200
  deployment_minimum_healthy_percent  = 100

  # Tags
  common_tags = module.common_tags.tags
}
```

**Configuration Highlights**:
- **Data source** gets current region automatically
- **Common tags module** ensures consistent tagging
- **Security group** allows inbound on container port, outbound to internet
- **CloudWatch log group** with 7-day retention for dev (cheaper)
- **ECS service module** handles task definition, service, and best practices
- **Circuit breaker** enabled for automatic rollback on failed deployments

#### 3.5 Define Outputs (outputs.tf)

Outputs make important values available after apply.

```hcl
# File: infra/terraform/environments/dev/outputs.tf
# Purpose: Export important values from infrastructure deployment

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = module.ecs_service.service_id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.service_name
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.ecs_service.task_definition_arn
}

output "security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app.name
}

# Convenient commands for operators
output "useful_commands" {
  description = "Useful AWS CLI commands for this service"
  value = <<-EOT
    # View service status
    aws ecs describe-services --cluster ${var.cluster_id} --services ${module.ecs_service.service_name}

    # View service logs
    aws logs tail /ecs/${var.environment}/${var.service_name} --follow

    # List running tasks
    aws ecs list-tasks --cluster ${var.cluster_id} --service-name ${module.ecs_service.service_name}
  EOT
}
```

**Output Best Practices**:
- Descriptive names and descriptions
- Export IDs/ARNs for use in other configurations or CI/CD
- Helpful commands for operators (debugging, monitoring)

**Time Checkpoint**: ~30 minutes elapsed

---

### Step 4: Configuring Backend

The backend configuration tells Terraform where to store state files.

#### 4.1 Set Up S3 Backend (backend.tf)

```hcl
# File: infra/terraform/environments/dev/backend.tf
# Purpose: Configure remote state backend for development environment

terraform {
  backend "s3" {
    # IMPORTANT: Replace with your organization's Terraform state bucket
    bucket = "myorg-terraform-state"

    # State file path follows pattern: services/{service}/{environment}/terraform.tfstate
    key = "services/product-api/dev/terraform.tfstate"

    # Region where state bucket is located
    region = "ap-northeast-2"

    # Enable encryption at rest
    encrypt = true

    # KMS key for state encryption
    # IMPORTANT: Replace with your organization's Terraform state KMS key
    kms_key_id = "arn:aws:kms:ap-northeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"

    # DynamoDB table for state locking
    # IMPORTANT: Replace with your organization's lock table name
    dynamodb_table = "terraform-state-lock"
  }
}
```

**Backend Configuration Requirements**:

**S3 Bucket**: Get from platform team or create once for organization
```bash
# Check if bucket exists
aws s3 ls s3://myorg-terraform-state

# If it doesn't exist, platform team should create with:
# - Versioning enabled
# - Encryption enabled
# - Bucket policy restricting access
# - Lifecycle rules for old versions
```

**KMS Key**: Get ARN from platform team or infrastructure repository
```bash
# Find KMS key
aws kms list-aliases --query "Aliases[?contains(AliasName, 'terraform')].{Alias:AliasName,KeyId:TargetKeyId}"

# Get full key ARN
aws kms describe-key --key-id <key-id> --query 'KeyMetadata.Arn'
```

**DynamoDB Table**: Platform team creates this once for organization
```bash
# Check if lock table exists
aws dynamodb describe-table --table-name terraform-state-lock
```

**Key Pattern Best Practice**:
```
services/{service-name}/{environment}/terraform.tfstate

Examples:
services/product-api/dev/terraform.tfstate
services/product-api/staging/terraform.tfstate
services/product-api/prod/terraform.tfstate
services/user-service/dev/terraform.tfstate
```

This pattern provides:
- Clear organization by service
- Environment isolation
- Easy discovery and management

#### 4.2 Create Environment README

```markdown
# Product API - Development Environment

## Overview
Development environment for Product API service running on ECS Fargate.

## Configuration
- **AWS Account**: 123456789012 (dev account)
- **Region**: ap-northeast-2 (Seoul)
- **VPC**: vpc-0123456789abcdef0
- **ECS Cluster**: dev-cluster

## Deployment

### Prerequisites
- AWS credentials configured for dev account
- Terraform v1.5.0 or later

### Commands
```bash
# Initialize Terraform (first time only)
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output

# Destroy resources (when needed)
terraform destroy
```

## Outputs
After `terraform apply`, you'll get:
- ECS service ID and name
- Task definition ARN
- Security group ID
- CloudWatch log group name
- Useful AWS CLI commands

## Troubleshooting

### Issue: Service not starting
```bash
# Check service events
aws ecs describe-services --cluster dev-cluster --services dev-product-api \
  --query 'services[0].events[0:5]'

# Check task status
aws ecs list-tasks --cluster dev-cluster --service-name dev-product-api
```

### Issue: Container failing
```bash
# View container logs
aws logs tail /ecs/dev/product-api --follow
```

## Support
- **Platform Team**: platform-team@company.com
- **Slack**: #product-team
```

**Time Checkpoint**: ~40 minutes elapsed

---

### Step 5: Setting Up Atlantis Configuration

Atlantis needs to know about your Terraform project.

#### 5.1 Create or Update atlantis.yaml

Navigate to repository root and create/update `atlantis.yaml`:

```bash
# Navigate to repository root
cd /path/to/product-api

# Create or edit atlantis.yaml
cat > atlantis.yaml <<'EOF'
version: 3

# Global settings
automerge: false
delete_source_branch_on_merge: false
parallel_plan: false
parallel_apply: false

# Projects configuration
projects:
  # Development environment
  - name: product-api-dev
    dir: infra/terraform/environments/dev
    workspace: default
    terraform_version: v1.5.0
    autoplan:
      when_modified: ["**/*.tf", "**/*.tfvars"]
      enabled: true
    apply_requirements: ["mergeable"]  # Dev: no approval required
    workflow: default

  # Staging environment (add when ready)
  # - name: product-api-staging
  #   dir: infra/terraform/environments/staging
  #   workspace: default
  #   terraform_version: v1.5.0
  #   autoplan:
  #     when_modified: ["**/*.tf", "**/*.tfvars"]
  #     enabled: true
  #   apply_requirements: ["approved", "mergeable"]
  #   workflow: default

  # Production environment (add when ready)
  # - name: product-api-prod
  #   dir: infra/terraform/environments/prod
  #   workspace: default
  #   terraform_version: v1.5.0
  #   autoplan:
  #     when_modified: ["**/*.tf", "**/*.tfvars"]
  #     enabled: true
  #   apply_requirements: ["approved", "mergeable"]
  #   workflow: production

# Workflows
workflows:
  default:
    plan:
      steps:
        - env:
            name: TF_PLUGIN_CACHE_DIR
            value: ""
        - init:
            extra_args: ["-upgrade"]
        - plan
    apply:
      steps:
        - apply

  production:
    plan:
      steps:
        - env:
            name: TF_PLUGIN_CACHE_DIR
            value: ""
        - init:
            extra_args: ["-upgrade"]
        - run: terraform fmt -check -recursive
        - run: terraform validate
        - plan
    apply:
      steps:
        - apply
EOF
```

#### 5.2 Understanding Atlantis Configuration

**Project Definition**:
```yaml
- name: product-api-dev              # Unique project identifier
  dir: infra/terraform/environments/dev  # Path to Terraform configuration
  workspace: default                  # Terraform workspace (usually default)
  terraform_version: v1.5.0          # Terraform version to use
  autoplan:
    when_modified: ["**/*.tf", "**/*.tfvars"]  # Trigger plan on these file changes
    enabled: true                     # Auto-plan on PR creation/update
  apply_requirements: ["mergeable"]   # Requirements before apply allowed
  workflow: default                   # Which workflow to use
```

**Apply Requirements**:
- `mergeable`: PR must pass checks and have no conflicts
- `approved`: PR must be approved by reviewer (omitted for dev)
- `undiverged`: Branch must not be behind base branch

**Workflow Steps**:
1. **env**: Disable plugin cache to prevent race conditions
2. **init -upgrade**: Initialize and update providers
3. **plan**: Generate execution plan
4. **apply**: Execute changes (only when explicitly requested)

**Time Checkpoint**: ~50 minutes elapsed

---

### Step 6: Testing Locally (Optional but Recommended)

Before creating the PR, test your configuration locally.

#### 6.1 Initialize Terraform

```bash
cd infra/terraform/environments/dev

# Initialize Terraform - downloads providers and modules
terraform init

# Expected output:
# Initializing the backend...
# Initializing provider plugins...
# - Finding hashicorp/aws versions matching "~> 5.0"...
# - Installing hashicorp/aws v5.x.x...
# Terraform has been successfully initialized!
```

**Common Init Issues**:

**Issue**: Backend bucket doesn't exist
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```
**Solution**: Ask platform team for correct bucket name or create bucket

**Issue**: Insufficient permissions
```
Error: error configuring S3 Backend: AccessDenied
```
**Solution**: Verify AWS credentials have access to state bucket and DynamoDB table

#### 6.2 Validate Configuration

```bash
# Check configuration syntax
terraform validate

# Expected output:
# Success! The configuration is valid.

# Format code (fix any formatting issues)
terraform fmt -recursive

# Expected output:
# main.tf
# variables.tf
# (Lists files that were reformatted)
```

#### 6.3 Generate Plan

```bash
# Generate execution plan
terraform plan

# Expected output (abbreviated):
# Terraform will perform the following actions:
#
#   # aws_cloudwatch_log_group.app will be created
#   + resource "aws_cloudwatch_log_group" "app" {
#       + name              = "/ecs/dev/product-api"
#       + retention_in_days = 7
#     }
#
#   # aws_security_group.ecs_tasks will be created
#   + resource "aws_security_group" "ecs_tasks" {
#       + name        = "dev-product-api-ecs-tasks"
#       + vpc_id      = "vpc-0123456789abcdef0"
#     }
#
#   # module.ecs_service.aws_ecs_service.main will be created
#   + resource "aws_ecs_service" "main" {
#       + name            = "dev-product-api"
#       + cluster         = "arn:aws:ecs:...:cluster/dev-cluster"
#       + desired_count   = 1
#       + launch_type     = "FARGATE"
#     }
#
# Plan: 15 to add, 0 to change, 0 to destroy.
```

**Reviewing the Plan**:
- **Green `+`**: Resources to be created
- **Yellow `~`**: Resources to be modified
- **Red `-`**: Resources to be destroyed
- **`-/+`**: Resources to be replaced (destroyed and recreated)

**Plan Review Checklist**:
- [ ] Resource count matches expectations (~10-15 for this example)
- [ ] No unintended deletions (red `-`)
- [ ] No resource replacements (`-/+`) unless expected
- [ ] Resource names follow naming conventions
- [ ] Tags are present on all resources
- [ ] Security group rules are correct
- [ ] No sensitive data in output

#### 6.4 Fix Common Planning Issues

**Issue**: Module not found
```
Error: Failed to download module
Could not download module "ecs_service"
```
**Solution**: Check module source URL and ref version, verify network access to GitHub

**Issue**: Invalid variable type
```
Error: Invalid value for variable
The given value is not suitable for var.subnet_ids declared type
```
**Solution**: Check variable type in terraform.tfvars matches declaration in variables.tf

**Issue**: Resource already exists
```
Error: creating CloudWatch Log Group: ResourceAlreadyExistsException
```
**Solution**: Import existing resource or choose different name

**DO NOT APPLY LOCALLY** - We'll apply via Atlantis in the PR workflow

**Time Checkpoint**: ~60 minutes elapsed

---

### Step 7: Creating the Pull Request

#### 7.1 Stage and Commit Changes

```bash
# Navigate to repository root
cd /path/to/product-api

# Check what files changed
git status

# Expected output:
# On branch feature/IN-200-add-ecs-service
# Untracked files:
#   atlantis.yaml
#   infra/terraform/environments/dev/

# Review changes
git diff HEAD

# Stage all infrastructure files
git add atlantis.yaml
git add infra/

# Verify staged files
git status

# Create commit with descriptive message
git commit -m "feat(infra): Add ECS service for product-api development environment

- Add ECS Fargate service configuration
- Configure security group for container networking
- Set up CloudWatch log group with 7-day retention
- Configure Atlantis project for automated planning
- Use central ecs-service module v1.0.0

Refs: IN-200"

# Push to remote
git push origin feature/IN-200-add-ecs-service

# Expected output:
# Enumerating objects: 15, done.
# Writing objects: 100% (15/15), 3.45 KiB | 3.45 MiB/s, done.
# Total 15 (delta 2), reused 0 (delta 0)
# To github.com:org/product-api.git
#  * [new branch]      feature/IN-200-add-ecs-service -> feature/IN-200-add-ecs-service
```

**Commit Message Best Practices**:
- **Format**: `type(scope): description`
- **Types**: feat, fix, docs, refactor, test, chore
- **Scope**: Area affected (infra, api, database, etc.)
- **Description**: Imperative mood, what changes do
- **Body**: Why changes were made, additional context
- **Footer**: References to tasks/issues

#### 7.2 Open Pull Request on GitHub

1. **Navigate to GitHub**:
   ```
   https://github.com/org/product-api/pulls
   ```

2. **Click "New Pull Request"**

3. **Select Branches**:
   - Base: `main`
   - Compare: `feature/IN-200-add-ecs-service`

4. **Fill PR Template**:

```markdown
## Summary
Add ECS Fargate service infrastructure for Product API in development environment.

## Changes
- **Infrastructure**: New ECS service using Fargate launch type
- **Networking**: Security group allowing inbound on port 8080 from VPC
- **Logging**: CloudWatch log group with 7-day retention
- **Automation**: Atlantis configuration for dev environment

## Module References
- `common-tags`: v1.0.0 - Standard tagging
- `ecs-service`: v1.0.0 - ECS service with best practices

## Testing
- [x] Local `terraform validate` passed
- [x] Local `terraform plan` reviewed (15 resources to add)
- [ ] Atlantis plan pending (will run automatically)
- [ ] Manual testing after apply (service health check)

## Deployment Plan
1. Atlantis will auto-plan on PR creation
2. Review plan output in PR comments
3. After approval, apply with `atlantis apply` comment
4. Verify service health in AWS console
5. Monitor CloudWatch logs for startup issues

## Rollback Plan
If service fails to start or has issues:
1. Comment `atlantis apply` to rollback (will destroy resources)
2. Fix issues in new commit
3. Re-plan and re-apply

## Checklist
- [x] Backend configuration uses organization state bucket
- [x] All required variables have values in terraform.tfvars
- [x] Security group rules follow least privilege
- [x] Tags include Environment, Service, ManagedBy
- [x] Module versions are pinned
- [x] README documentation added
- [x] Atlantis project configuration added

## References
- Task: [IN-200](https://company.atlassian.net/browse/IN-200)
- Documentation: [Service Repository Onboarding Guide](../infrastructure/docs/guides/onboarding/SERVICE_REPO_ONBOARDING.md)

## Questions for Reviewers
- Does the security group configuration look appropriate?
- Are the CPU/memory allocations (256/512) sufficient for dev?
- Should we add health checks in the initial version?
```

5. **Request Reviewers**:
   - Add platform team member
   - Add service team member
   - Add any required CODEOWNERS reviewers

6. **Add Labels**:
   - `infrastructure`
   - `development`
   - `needs-review`

7. **Click "Create Pull Request"**

**Time Checkpoint**: ~70 minutes elapsed

---

### Step 8: Working with Atlantis in the PR

Once you create the PR, Atlantis automatically starts working.

#### 8.1 Understanding Atlantis Comments

**Autoplan Trigger** (appears immediately after PR creation):

```
atlantis plan -d infra/terraform/environments/dev
```

Atlantis will comment:

```
Ran Plan for dir: infra/terraform/environments/dev workspace: default

Show Output

Planning: Atlantis is running terraform plan...
```

**Successful Plan Output**:

```
Ran Plan for dir: infra/terraform/environments/dev workspace: default

Terraform will perform the following actions:

  # aws_cloudwatch_log_group.app will be created
  + resource "aws_cloudwatch_log_group" "app" {
      + arn               = (known after apply)
      + name              = "/ecs/dev/product-api"
      + retention_in_days = 7
      + tags              = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Service"     = "product-api"
        }
    }

  # aws_security_group.ecs_tasks will be created
  + resource "aws_security_group" "ecs_tasks" {
      + arn         = (known after apply)
      + description = "Security group for product-api ECS tasks in dev"
      + egress      = [
          + {
              + cidr_blocks      = ["0.0.0.0/0"]
              + description      = "Allow all outbound traffic"
              + from_port        = 0
              + protocol         = "-1"
              + to_port          = 0
            },
        ]
      + ingress     = [
          + {
              + cidr_blocks      = ["10.0.0.0/8"]
              + description      = "Allow inbound traffic on container port"
              + from_port        = 8080
              + protocol         = "tcp"
              + to_port          = 8080
            },
        ]
      + name        = "dev-product-api-ecs-tasks"
      + vpc_id      = "vpc-0123456789abcdef0"
      + tags        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "dev-product-api-ecs-tasks"
          + "Service"     = "product-api"
        }
    }

  # module.ecs_service.aws_ecs_service.main will be created
  + resource "aws_ecs_service" "main" {
      + cluster                            = "arn:aws:ecs:ap-northeast-2:123456789012:cluster/dev-cluster"
      + deployment_maximum_percent         = 200
      + deployment_minimum_healthy_percent = 100
      + desired_count                      = 1
      + enable_ecs_managed_tags            = true
      + enable_execute_command             = false
      + launch_type                        = "FARGATE"
      + name                               = "dev-product-api"
      + platform_version                   = "LATEST"
      + scheduling_strategy                = "REPLICA"
      + tags                               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Service"     = "product-api"
        }
      + task_definition                    = (known after apply)
      + deployment_circuit_breaker {
          + enable   = true
          + rollback = true
        }
      + network_configuration {
          + assign_public_ip = false
          + security_groups  = (known after apply)
          + subnets          = [
              + "subnet-0123456789abcdef0",
              + "subnet-0123456789abcdef1",
            ]
        }
    }

  # module.ecs_service.aws_ecs_task_definition.main will be created
  + resource "aws_ecs_task_definition" "main" {
      + arn                      = (known after apply)
      + container_definitions    = (known after apply)
      + cpu                      = "256"
      + execution_role_arn       = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
      + family                   = "dev-product-api"
      + memory                   = "512"
      + network_mode             = "awsvpc"
      + requires_compatibilities = ["FARGATE"]
      + task_role_arn            = "arn:aws:iam::123456789012:role/ecsTaskRole"
      + tags                     = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Service"     = "product-api"
        }
    }

Plan: 15 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + ecs_service_id       = (known after apply)
  + ecs_service_name     = "dev-product-api"
  + log_group_name       = "/ecs/dev/product-api"
  + security_group_id    = (known after apply)
  + task_definition_arn  = (known after apply)
  + useful_commands      = <<-EOT
        # View service status
        aws ecs describe-services --cluster arn:aws:ecs:...:cluster/dev-cluster --services dev-product-api

        # View service logs
        aws logs tail /ecs/dev/product-api --follow

        # List running tasks
        aws ecs list-tasks --cluster arn:aws:ecs:...:cluster/dev-cluster --service-name dev-product-api
    EOT

---
* To discard this plan click here
* To apply this plan comment: atlantis apply -d infra/terraform/environments/dev
```

#### 8.2 Reviewing Plan Output

**What to Look For**:

✅ **Good Signs**:
- Resource count matches expectations (~15 resources)
- All resources have proper tags
- Security group rules match requirements
- No unexpected deletions or replacements
- Output values look correct
- Module references show correct versions

⚠️ **Warning Signs**:
- Resources being destroyed (`- resource`)
- Resources being replaced (`-/+ resource`)
- Missing tags on resources
- Overly permissive security groups (0.0.0.0/0 for ingress)
- Sensitive data in output

❌ **Red Flags**:
- Production resources affected in dev PR
- State file conflicts or errors
- Authentication or permission errors
- Invalid resource configurations

#### 8.3 Common Plan Issues and Solutions

**Issue 1: Module Not Found**

```
Error downloading modules:
- module.ecs_service: failed to download module: 404 Not Found
```

**Diagnosis**: Module reference is incorrect or version doesn't exist

**Solution**:
```bash
# Check module exists and version is tagged
git ls-remote --tags https://github.com/ryuqqq/infrastructure.git | grep ecs-service

# Fix module source in main.tf
module "ecs_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=v1.0.0"
  #                                                                                             ^^^^^^^^ Verify this exists
}

# Commit and push fix
git add infra/terraform/environments/dev/main.tf
git commit -m "fix(infra): Correct ecs-service module version reference"
git push origin feature/IN-200-add-ecs-service
```

Atlantis will automatically re-plan when you push the fix.

**Issue 2: Resource Already Exists**

```
Error: creating CloudWatch Log Group (/ecs/dev/product-api): ResourceAlreadyExistsException
```

**Diagnosis**: Resource already exists in AWS (from previous deployment or manual creation)

**Solution Option A** - Import existing resource:
```bash
# Import existing log group into Terraform state
# Add to PR comment for documentation:
cd infra/terraform/environments/dev
terraform import aws_cloudwatch_log_group.app /ecs/dev/product-api
```

**Solution Option B** - Use different name:
```hcl
# Change log group name in main.tf
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/dev/product-api-v2"  # Changed name
  retention_in_days = 7
}
```

**Issue 3: Invalid Variable Value**

```
Error: Invalid value for variable "cpu"
CPU must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384
```

**Diagnosis**: Variable value doesn't pass validation constraint

**Solution**:
```hcl
# Fix value in terraform.tfvars
cpu = 256  # Changed from invalid value (e.g., 300)
```

**Issue 4: Insufficient IAM Permissions**

```
Error: creating ECS Service: AccessDeniedException
User: arn:aws:iam::123456789012:user/atlantis is not authorized to perform: ecs:CreateService
```

**Diagnosis**: Atlantis IAM role lacks required permissions

**Solution**: Contact platform team to update Atlantis IAM role with required permissions

#### 8.4 Re-planning After Changes

When you push new commits to fix issues:

```bash
# Make your changes
vim infra/terraform/environments/dev/main.tf

# Commit fix
git add infra/terraform/environments/dev/main.tf
git commit -m "fix(infra): Correct CPU value to valid tier"
git push origin feature/IN-200-add-ecs-service
```

Atlantis automatically re-plans:
- Detects the new commit
- Runs `terraform plan` again
- Posts updated plan output as new PR comment

**Manual Re-plan** (if needed):
```
Comment on PR: atlantis plan -d infra/terraform/environments/dev
```

**Time Checkpoint**: ~80 minutes elapsed

---

### Step 9: Addressing Review Feedback

Reviewers will comment on your PR with feedback.

#### 9.1 Common Review Comments and Fixes

**Comment: "Add health check configuration for production readiness"**

**Response**:
```bash
# Edit main.tf to add health check
vim infra/terraform/environments/dev/main.tf
```

```hcl
# In module "ecs_service" block, add:
module "ecs_service" {
  # ... existing configuration ...

  # Add health check
  health_check_command = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
  health_check_interval = 30
  health_check_retries = 3
  health_check_start_period = 60
  health_check_timeout = 5

  # ... rest of configuration ...
}
```

```bash
# Commit change
git add infra/terraform/environments/dev/main.tf
git commit -m "feat(infra): Add container health check configuration

- Add health check endpoint on /health
- Set reasonable intervals and timeouts
- Configure grace period for application startup

Addresses review feedback from @platform-team"
git push origin feature/IN-200-add-ecs-service
```

**Comment: "Security group ingress is too permissive - limit to specific sources"**

**Response**:
```hcl
# Update security group in main.tf
resource "aws_security_group" "ecs_tasks" {
  # ... existing configuration ...

  ingress {
    description = "Allow inbound traffic from ALB only"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    # Changed from 10.0.0.0/8 to specific ALB security group
    security_groups = [var.alb_security_group_id]  # Add this variable
  }
}
```

**Comment: "Increase log retention for compliance requirements"**

**Response**:
```hcl
# Update log group in main.tf
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/dev/product-api"
  retention_in_days = 30  # Changed from 7 to 30 days

  tags = module.common_tags.tags
}
```

#### 9.2 Responding to Review Comments

**Professional Response Template**:

```markdown
@reviewer-name Thanks for the feedback!

**Issue**: [Summarize the concern]

**Resolution**: [Describe what you changed]
- Change 1
- Change 2

**Updated in**: [commit SHA]

The plan has been updated automatically. Please review the new output above.
```

**Example**:
```markdown
@alice Thanks for catching the health check omission!

**Issue**: Missing container health check configuration could lead to unhealthy containers serving traffic.

**Resolution**: Added comprehensive health check configuration:
- Health endpoint: `/health`
- Check interval: 30 seconds
- Retries before unhealthy: 3
- Grace period: 60 seconds (allows app startup time)
- Timeout: 5 seconds

**Updated in**: abc1234

The plan has been updated. You'll see the health check in the task definition configuration now.
```

---

### Step 10: Applying Changes via Atlantis

Once your PR is approved and plan looks good, it's time to apply.

#### 10.1 Pre-Apply Checklist

Before commenting `atlantis apply`, verify:

- [ ] **PR Approved**: Required reviewers have approved
- [ ] **Checks Passing**: All CI/CD checks green
- [ ] **Plan Reviewed**: Plan output reviewed and confirmed correct
- [ ] **No Conflicts**: Branch is up to date with main
- [ ] **Apply Requirements Met**: Atlantis shows "Apply allowed"
- [ ] **Resources Expected**: Number and type of resources match expectations
- [ ] **No Destructive Changes**: No unintended deletions or replacements
- [ ] **Notifications Sent**: Team informed of upcoming deployment (if required)

#### 10.2 Execute Apply

**Comment on PR**:
```
atlantis apply -d infra/terraform/environments/dev
```

**Atlantis Response**:

```
atlantis apply -d infra/terraform/environments/dev

Applying: Running terraform apply...

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

ecs_service_id = "arn:aws:ecs:ap-northeast-2:123456789012:service/dev-cluster/dev-product-api"
ecs_service_name = "dev-product-api"
task_definition_arn = "arn:aws:ecs:ap-northeast-2:123456789012:task-definition/dev-product-api:1"
security_group_id = "sg-0abcdef1234567890"
log_group_name = "/ecs/dev/product-api"
useful_commands = <<EOT
# View service status
aws ecs describe-services --cluster arn:aws:ecs:ap-northeast-2:123456789012:cluster/dev-cluster --services dev-product-api

# View service logs
aws logs tail /ecs/dev/product-api --follow

# List running tasks
aws ecs list-tasks --cluster arn:aws:ecs:ap-northeast-2:123456789012:cluster/dev-cluster --service-name dev-product-api
EOT
```

✅ **Success!** Your infrastructure is now deployed.

#### 10.3 Understanding Apply Output

**Key Sections**:

1. **Resources Summary**:
   ```
   Resources: 15 added, 0 changed, 0 destroyed.
   ```
   - **added**: New resources created
   - **changed**: Existing resources modified
   - **destroyed**: Resources deleted

2. **Outputs**: Values you defined in `outputs.tf`
   - Service IDs and ARNs for reference
   - Helpful commands for operations
   - URLs and endpoints (if applicable)

3. **Execution Time**: How long apply took
   - Useful for understanding deployment duration
   - Plan for maintenance windows in production

#### 10.4 Verifying Deployment

**Check ECS Service Status**:
```bash
# Use the command from outputs
aws ecs describe-services \
  --cluster arn:aws:ecs:ap-northeast-2:123456789012:cluster/dev-cluster \
  --services dev-product-api \
  --query 'services[0].[serviceName,status,runningCount,desiredCount,deployments[0].status]' \
  --output table

# Expected output:
# --------------------------------
# |      DescribeServices        |
# +------------------------------+
# |  dev-product-api            |
# |  ACTIVE                     |
# |  1                          |
# |  1                          |
# |  PRIMARY                    |
# +------------------------------+
```

**Check Task Status**:
```bash
# List running tasks
aws ecs list-tasks \
  --cluster arn:aws:ecs:ap-northeast-2:123456789012:cluster/dev-cluster \
  --service-name dev-product-api

# Describe task details
aws ecs describe-tasks \
  --cluster arn:aws:ecs:ap-northeast-2:123456789012:cluster/dev-cluster \
  --tasks <task-arn-from-above>
```

**View Container Logs**:
```bash
# Tail logs in real-time
aws logs tail /ecs/dev/product-api --follow

# View recent logs
aws logs tail /ecs/dev/product-api --since 5m
```

**Verify Service Health**:
```bash
# If you have a health check endpoint
curl http://<load-balancer-url>/health

# Expected response:
# {"status": "healthy", "version": "1.0.0"}
```

#### 10.5 Common Apply Issues

**Issue: Apply Fails Midway**

```
Error: error creating ECS Service: InvalidParameterException:
Unable to assume role and validate the specified targetGroupArn
```

**Diagnosis**: IAM role doesn't have permission to access target group

**Recovery**:
1. Terraform automatically rolls back partial changes
2. Fix IAM permissions
3. Comment `atlantis apply` again to retry

**Issue: Service Stuck in PENDING**

```bash
# Check service events
aws ecs describe-services --cluster dev-cluster --services dev-product-api \
  --query 'services[0].events[0:5]'

# Common causes:
# - Container fails to start
# - Cannot pull container image
# - Insufficient resources in cluster
# - Health check failing immediately
```

**Solution**:
```bash
# Check container logs for errors
aws logs tail /ecs/dev/product-api --follow

# Common fixes:
# - Verify container image URL is correct
# - Check IAM execution role has ECR pull permissions
# - Verify health check endpoint exists
# - Increase CPU/memory if resource-constrained
```

**Time Checkpoint**: ~90 minutes elapsed

---

### Step 11: Merging and Cleanup

#### 11.1 Post-Apply Verification

Before merging, verify everything works:

```bash
# Service health check (wait 2-3 minutes for service to stabilize)
aws ecs describe-services --cluster dev-cluster --services dev-product-api \
  --query 'services[0].[runningCount,desiredCount]'
# Should show [1, 1] - running count equals desired count

# Check for any service events indicating issues
aws ecs describe-services --cluster dev-cluster --services dev-product-api \
  --query 'services[0].events[0:3]'
# Should NOT show steady state errors

# Verify container is logging
aws logs tail /ecs/dev/product-api --since 5m
# Should show application startup logs
```

**Success Criteria**:
- [ ] Running count equals desired count
- [ ] No error events in service events
- [ ] Container logs show successful startup
- [ ] Health check passing (if configured)
- [ ] Service accessible (if behind load balancer)

#### 11.2 Update PR with Apply Results

Add a comment documenting successful apply:

```markdown
## Apply Complete ✅

**Applied**: 2025-10-18 14:30 KST

**Resources Created**: 15
- ECS Service: `dev-product-api`
- Task Definition: `dev-product-api:1`
- Security Group: `sg-0abcdef1234567890`
- CloudWatch Log Group: `/ecs/dev/product-api`
- + 11 related resources

**Verification**:
- [x] Service status: ACTIVE
- [x] Running count: 1/1
- [x] Container logs: Showing startup success
- [x] No error events

**Outputs**:
```
ecs_service_name = "dev-product-api"
log_group_name = "/ecs/dev/product-api"
```

**Next Steps**:
- Monitor service for next 30 minutes
- Ready to merge if no issues observed

**Screenshots**:
[Optional: Add screenshots of AWS Console showing service running]
```

#### 11.3 Merge Pull Request

Once verified and approved:

1. **Squash and Merge** (recommended) or **Merge Commit**
   ```
   Squash and merge helps keep main branch history clean
   ```

2. **Merge Commit Message**:
   ```
   feat(infra): Add ECS service for product-api development environment (#123)

   - Add ECS Fargate service configuration
   - Configure security group for container networking
   - Set up CloudWatch log group with 7-day retention
   - Configure Atlantis project for automated planning
   - Use central ecs-service module v1.0.0

   Resources created: 15
   Applied: 2025-10-18 14:30 KST

   Refs: IN-200
   ```

3. **Delete Branch** (recommended after merge)
   ```
   Check "Delete branch" after merge completes
   ```

#### 11.4 Post-Merge Cleanup

```bash
# Switch back to main branch
git checkout main

# Pull latest changes (includes your merged PR)
git pull origin main

# Delete local feature branch
git branch -d feature/IN-200-add-ecs-service

# Verify branch is gone
git branch
# Should only show: * main

# Verify remote branch was deleted
git fetch --prune
git branch -r | grep IN-200
# Should return nothing
```

#### 11.5 Monitoring After Merge

**Monitor service for stability**:

```bash
# Check service every 5 minutes for next 30 minutes
watch -n 300 'aws ecs describe-services --cluster dev-cluster --services dev-product-api --query "services[0].[runningCount,desiredCount,deployments[0].status]"'

# Monitor container logs for errors
aws logs tail /ecs/dev/product-api --follow --filter-pattern "ERROR"

# Set up CloudWatch alarm (optional but recommended)
# This would be in a separate infrastructure update
```

**Success Metrics** (first 24 hours):
- Service maintains desired count
- No task failures or restarts
- Container logs show no critical errors
- Response times are acceptable
- No unexpected cost increases

**Time Checkpoint**: ~100 minutes total (including monitoring)

---

### Step 12: What Happens After Merge

#### 12.1 Infrastructure State

**Terraform State**:
- State file updated in S3: `s3://myorg-terraform-state/services/product-api/dev/terraform.tfstate`
- State contains complete resource inventory
- Locked during operations via DynamoDB
- Versioned in S3 for rollback capability

**Check State**:
```bash
cd infra/terraform/environments/dev

# List resources in state
terraform state list

# Expected output:
# aws_cloudwatch_log_group.app
# aws_security_group.ecs_tasks
# module.common_tags.data.aws_caller_identity.current
# module.ecs_service.aws_ecs_service.main
# module.ecs_service.aws_ecs_task_definition.main
# ... (15 total resources)

# Show specific resource details
terraform state show module.ecs_service.aws_ecs_service.main
```

#### 12.2 AWS Resources

**View in AWS Console**:

1. **ECS Service**:
   ```
   AWS Console → ECS → Clusters → dev-cluster → Services → dev-product-api
   ```

2. **Running Tasks**:
   ```
   AWS Console → ECS → Clusters → dev-cluster → Tasks → [task-id]
   ```

3. **CloudWatch Logs**:
   ```
   AWS Console → CloudWatch → Logs → Log groups → /ecs/dev/product-api
   ```

4. **Security Group**:
   ```
   AWS Console → VPC → Security Groups → dev-product-api-ecs-tasks
   ```

**Resource Tags Verification**:
```bash
# Check tags on ECS service
aws ecs describe-services --cluster dev-cluster --services dev-product-api \
  --query 'services[0].tags'

# Expected tags:
# {
#   "Environment": "dev",
#   "ManagedBy": "Terraform",
#   "Service": "product-api",
#   "Team": "product-team",
#   "Owner": "product-team@company.com",
#   "CostCenter": "product-development"
# }
```

#### 12.3 Cost Tracking

**Estimate Monthly Costs**:

For this configuration (dev environment):
- **ECS Fargate**: 1 task × 0.25 vCPU × 0.5 GB RAM
  - ~$5-10/month (assuming 24/7 runtime)
- **CloudWatch Logs**: ~1-2 GB/month
  - ~$0.50/month (7-day retention)
- **Data Transfer**: Minimal in dev
  - ~$1/month

**Total**: ~$7-13/month

**Monitor Costs**:
```bash
# Use AWS Cost Explorer
# Filter by tags: Service=product-api, Environment=dev

# Or use Infracost (if integrated in CI/CD)
# Would have been shown in PR as comment
```

#### 12.4 Next Development Steps

**Common Follow-Up Changes**:

1. **Add Staging Environment**:
   ```bash
   # Copy dev configuration to staging
   cp -r infra/terraform/environments/dev infra/terraform/environments/staging

   # Update staging-specific values
   # - Increase task count (desired_count = 2)
   # - Increase resources (cpu = 512, memory = 1024)
   # - Extend log retention (retention_in_days = 30)
   # - Add load balancer configuration
   ```

2. **Add Autoscaling**:
   ```hcl
   # In main.tf, add to ecs_service module:
   enable_autoscaling      = true
   autoscaling_min_capacity = 1
   autoscaling_max_capacity = 4
   autoscaling_target_cpu   = 70
   autoscaling_target_memory = 80
   ```

3. **Add Load Balancer**:
   ```hcl
   # Create ALB and target group
   # Then add to ecs_service module:
   load_balancer_config = {
     target_group_arn = aws_lb_target_group.app.arn
     container_name   = var.service_name
     container_port   = var.container_port
   }
   ```

4. **Add Database**:
   ```hcl
   # Create RDS instance using central module
   module "database" {
     source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/rds?ref=v1.0.0"
     # ... configuration
   }
   ```

#### 12.5 Rollback Procedures

**If Issues Arise After Merge**:

**Option 1: Rollback via Terraform Destroy** (for complete removal)
```bash
# Create rollback PR
git checkout -b hotfix/rollback-product-api-ecs

cd infra/terraform/environments/dev

# Review what will be destroyed
terraform plan -destroy

# Create PR with destroy plan
# In PR: Comment "atlantis apply -d infra/terraform/environments/dev"
# This destroys all resources
```

**Option 2: Modify Configuration** (for fixing issues)
```bash
# Create fix PR
git checkout -b fix/product-api-config-adjustment

# Make necessary changes
vim infra/terraform/environments/dev/main.tf

# Commit and create PR
git commit -m "fix: Adjust ECS task memory allocation"
git push origin fix/product-api-config-adjustment

# Atlantis will plan, review, and apply changes
```

**Option 3: Emergency Manual Rollback**
```bash
# Only in true emergencies - bypasses PR workflow
cd infra/terraform/environments/dev

# Destroy specific resources
terraform destroy -target=module.ecs_service

# Or scale down to zero (less destructive)
aws ecs update-service --cluster dev-cluster \
  --service dev-product-api --desired-count 0
```

**Important**: Always prefer Option 1 or 2 (PR-based) for audit trail and team visibility.

---

### Troubleshooting Guide

#### Common Issues and Solutions

**Issue: "Atlantis not commenting on PR"**

**Symptoms**: No automatic plan appears after creating PR

**Diagnosis**:
1. Check Atlantis is running: `curl https://atlantis.your-domain.com/healthz`
2. Check GitHub webhook: Repository Settings → Webhooks → Recent Deliveries
3. Check Atlantis logs for errors

**Solutions**:
- Verify `atlantis.yaml` exists in repository root
- Check `autoplan.enabled: true` in project config
- Verify `when_modified` patterns match your file changes
- Manual trigger: Comment `atlantis plan` on PR

---

**Issue: "State lock timeout"**

**Symptoms**:
```
Error: Error acquiring the state lock
Lock Info:
  ID:        abc123-456-789
  Operation: OperationTypePlan
```

**Diagnosis**: Previous Terraform operation didn't release lock (crash, timeout, etc.)

**Solutions**:
```bash
# Option 1: Wait for lock timeout (usually 10-15 minutes)

# Option 2: Force unlock (use with caution)
cd infra/terraform/environments/dev
terraform force-unlock abc123-456-789

# Option 3: Via Atlantis comment
# Comment on PR: atlantis unlock -d infra/terraform/environments/dev
```

**Prevention**: Don't run local Terraform operations during Atlantis workflows

---

**Issue: "Backend initialization failed"**

**Symptoms**:
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Diagnosis**: Backend configuration references non-existent or inaccessible S3 bucket

**Solutions**:
1. Verify bucket name with platform team
2. Check AWS credentials have access to bucket
3. Verify bucket exists: `aws s3 ls s3://myorg-terraform-state`
4. Verify region matches bucket region
5. Update `backend.tf` with correct values

---

**Issue: "Module download failed"**

**Symptoms**:
```
Error: Failed to download module
Could not download module "ecs_service"
```

**Diagnosis**: Module source URL incorrect, version doesn't exist, or network issue

**Solutions**:
```bash
# Verify module exists
git ls-remote --tags https://github.com/ryuqqq/infrastructure.git | grep ecs-service

# Check your source format
# Correct: git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=v1.0.0
# Wrong:   https://github.com/ryuqqq/infrastructure.git/terraform/modules/ecs-service?ref=v1.0.0
#          (missing git:: prefix and //)

# Verify network access to GitHub
curl -I https://github.com/ryuqqq/infrastructure
```

---

**Issue: "Container fails to start"**

**Symptoms**: ECS service shows tasks starting and stopping repeatedly

**Diagnosis**:
```bash
# Check service events
aws ecs describe-services --cluster dev-cluster --services dev-product-api \
  --query 'services[0].events[0:10]'

# Common causes:
# - "Task failed container health checks"
# - "CannotPullContainerError"
# - "ResourceInitializationError"
```

**Solutions by Error**:

1. **CannotPullContainerError**:
   ```bash
   # Verify image exists
   aws ecr describe-images --repository-name product-api --image-ids imageTag=latest

   # Verify IAM execution role has ECR permissions
   aws iam get-role-policy --role-name ecsTaskExecutionRole --policy-name ECRAccess

   # Add permission if missing:
   # Policy: AmazonEC2ContainerRegistryReadOnly
   ```

2. **Container health checks failing**:
   ```bash
   # Check container logs for startup errors
   aws logs tail /ecs/dev/product-api --follow

   # Adjust health check grace period in main.tf:
   health_check_start_period = 120  # Give more time to start
   ```

3. **ResourceInitializationError**:
   ```bash
   # Usually insufficient resources or subnet issues
   # Check task stopped reason:
   aws ecs describe-tasks --cluster dev-cluster --tasks <task-arn>

   # Increase CPU/memory:
   cpu    = 512
   memory = 1024
   ```

---

### Summary and Next Steps

**🎉 Congratulations!** You've successfully:

✅ Created proper infrastructure code structure
✅ Configured remote state backend
✅ Set up Atlantis automation
✅ Created and reviewed a pull request
✅ Worked with Atlantis planning and apply
✅ Deployed infrastructure to AWS
✅ Verified deployment success
✅ Merged changes and cleaned up

**Skills Gained**:
- Terraform module composition
- Remote state management
- Atlantis workflow automation
- Infrastructure PR best practices
- AWS ECS service deployment
- Troubleshooting common issues

**Next Learning Steps**:

1. **Add Staging Environment** (~30 min)
   - Copy dev configuration
   - Adjust for staging requirements
   - Add staging Atlantis project
   - Deploy and test

2. **Implement Autoscaling** (~45 min)
   - Configure target tracking scaling
   - Set min/max capacity
   - Test scaling behavior
   - Monitor scaling metrics

3. **Add Load Balancer** (~60 min)
   - Create ALB with central module
   - Configure target group
   - Update security groups
   - Test load balancing

4. **Integrate with Database** (~90 min)
   - Deploy RDS instance
   - Configure security groups
   - Set up secrets management
   - Update application configuration

5. **Production Deployment** (~120 min)
   - Review all governance requirements
   - Configure production-grade settings
   - Set up monitoring and alerting
   - Implement backup and recovery

**Reference Documentation**:
- [Module Standards Guide](../../modules/MODULE_STANDARDS_GUIDE.md)
- [Naming Conventions](../../governance/NAMING_CONVENTION.md)
- [Tagging Standards](../../governance/TAGGING_STANDARDS.md)
- [Security Best Practices](../../governance/SECURITY_SCAN_REPORT_TEMPLATE.md)
- [PR Governance](../../governance/infrastructure_pr.md)

**Getting Help**:
- Platform Team: platform-team@company.com
- Slack: #infrastructure-help
- Office Hours: Wednesdays 2-3 PM KST
- Documentation: [Infrastructure Wiki](https://wiki.company.com/infrastructure)

**Feedback**:
Help us improve this tutorial! Share your experience:
- What was confusing?
- What took longer than expected?
- What would have helped you?

Submit feedback: [GitHub Issue](https://github.com/org/infrastructure/issues/new?template=tutorial-feedback.md)

---

## Next Steps

After understanding the folder structure, proceed to:

1. **[Module Standards](../../modules/MODULE_STANDARDS_GUIDE.md)** - Coding conventions and best practices
2. **[Naming Conventions](../../governance/NAMING_CONVENTION.md)** - Resource naming standards
3. **[Tagging Standards](../../governance/TAGGING_STANDARDS.md)** - Required tags and patterns
4. **[Security Guidelines](../../governance/SECURITY_SCAN_REPORT_TEMPLATE.md)** - Security best practices

## Related Documentation

- [Infrastructure Repository README](../../../README.md)
- [Terraform Modules Catalog](../../../terraform/modules/README.md)
- [Module Directory Structure](../../modules/MODULES_DIRECTORY_STRUCTURE.md)
- [GitHub Actions Setup Guide](../setup/github_actions_setup.md)

## Support

For questions or assistance:
- **Platform Team**: platform-team@company.com
- **Infrastructure Repository**: [GitHub Issues](https://github.com/org/infrastructure/issues)
- **Jira Epic**: [IN-102 - Documentation and Onboarding](https://ryuqqq.atlassian.net/browse/IN-102)
- **Task**: [IN-134 - Service Repository Onboarding Guide](https://ryuqqq.atlassian.net/browse/IN-134)
