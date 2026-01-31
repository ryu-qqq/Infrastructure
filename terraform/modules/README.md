# Terraform Modules Catalog

재사용 가능한 Terraform 모듈 카탈로그입니다. 모든 모듈은 **common-tags 의무화 패턴**을 사용하여 거버넌스 표준을 자동으로 적용합니다.

## 📋 모듈 목록

### Core Infrastructure Modules

| 모듈 | 버전 | 설명 | 상태 |
|------|------|------|------|
| [common-tags](./common-tags/) | 1.0.0 | 표준 태그 생성 모듈 (모든 모듈의 기반) | ✅ Active |
| [cloudwatch-log-group](./cloudwatch-log-group/) | 1.0.0 | CloudWatch Log Group 생성 및 관리 | ✅ Active |
| [iam-role-policy](./iam-role-policy/) | 1.0.0 | IAM Role 및 Policy 관리 | ✅ Active |
| [security-group](./security-group/) | 1.0.0 | Security Group 및 규칙 관리 | ✅ Active |

### Compute Modules

| 모듈 | 버전 | 설명 | 상태 |
|------|------|------|------|
| [ecs-service](./ecs-service/) | 1.0.0 | ECS Fargate Service 표준 모듈 | ✅ Active |
| [lambda](./lambda/) | 1.0.0 | Lambda Function 및 통합 | ✅ Active |

### Networking Modules

| 모듈 | 버전 | 설명 | 상태 |
|------|------|------|------|
| [alb](./alb/) | 1.0.0 | Application Load Balancer 모듈 | ✅ Active |
| [cloudfront](./cloudfront/) | 1.0.0 | CloudFront Distribution 모듈 | ✅ Active |
| [route53-record](./route53-record/) | 1.0.0 | Route53 DNS Record 관리 | ✅ Active |
| [waf](./waf/) | 1.0.0 | WAF Web ACL 및 규칙 | ✅ Active |

### Database & Cache Modules

| 모듈 | 버전 | 설명 | 상태 |
|------|------|------|------|
| [rds](./rds/) | 1.0.0 | RDS Instance 표준 모듈 | ✅ Active |
| [elasticache](./elasticache/) | 1.0.0 | ElastiCache Redis/Memcached | ✅ Active |

### Messaging Modules

| 모듈 | 버전 | 설명 | 상태 |
|------|------|------|------|
| [sns](./sns/) | 1.0.0 | SNS Topic 및 Subscription | ✅ Active |
| [sqs](./sqs/) | 1.0.0 | SQS Queue 및 DLQ | ✅ Active |
| [messaging-pattern](./messaging-pattern/) | 1.0.0 | SNS+SQS 통합 패턴 | ✅ Active |

### Storage Modules

| 모듈 | 버전 | 설명 | 상태 |
|------|------|------|------|
| [s3-bucket](./s3-bucket/) | 1.0.0 | S3 Bucket 및 정책 관리 | ✅ Active |
| [ecr](./ecr/) | 1.0.0 | ECR Repository 관리 | ✅ Active |

### Event & Orchestration Modules

| 모듈 | 버전 | 설명 | 상태 |
|------|------|------|------|
| [eventbridge](./eventbridge/) | 1.0.0 | EventBridge Rule 및 Target | ✅ Active |

## 🚀 빠른 시작

### 기본 사용법 (v1.0.0)

**2025-11-23 기준**: 모든 모듈이 v1.0.0으로 표준화되었습니다.

**주요 특징**:
- ✅ `common-tags` 모듈이 내부적으로 통합됨
- ✅ 개별 태그 변수 필수: `environment`, `service_name`, `team`, `owner`, `cost_center`
- ✅ 한국어 문서화 및 사용 예제 제공
- ✅ 거버넌스 규칙 자동 적용

```hcl
# 모듈 사용 예시
module "example_ecr" {
  source = "../../modules/ecr"

  # ECR 설정
  name        = "myapp"
  kms_key_arn = data.terraform_remote_state.kms.outputs.ecr_key_arn

  # 필수: 태그 변수 (common-tags 모듈로 내부 전달)
  environment  = "prod"
  service_name = "myapp"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  # 선택적: 기본값이 제공되지만 커스터마이징 가능
  project    = "infrastructure"  # 기본값: "infrastructure"
  data_class = "confidential"    # 기본값: 모듈별 상이

  # 선택적: 추가 태그
  additional_tags = {
    Application = "web-api"
    Version     = "2.0"
  }
}
```

### 모듈 버전 정보

모든 모듈은 현재 **v1.0.0**입니다 (2025-11-23 초기 릴리스).

| 모듈 | 버전 | 릴리스 날짜 |
|------|------|-------------|
| 모든 18개 모듈 | v1.0.0 | 2025-11-23 |

각 모듈의 상세 버전 정보는 개별 모듈의 CHANGELOG.md를 참조하세요.

## 📚 모듈 개발 가이드

### 표준 디렉터리 구조

```
terraform/modules/{module-name}/
├── README.md           # 모듈 문서 (필수) - 사용 예제 포함
├── main.tf             # 주요 리소스 정의 (필수)
├── variables.tf        # 입력 변수 (필수)
├── outputs.tf          # 출력 값 (필수)
├── versions.tf         # Provider 버전 제약 (권장)
├── locals.tf           # Local 값 (선택)
├── data.tf             # Data Sources (선택)
└── CHANGELOG.md        # 변경 이력 (필수)
```

### 필수 패턴: common-tags 모듈 통합

모든 모듈은 내부적으로 common-tags 모듈을 사용해야 합니다:

```hcl
# main.tf
module "tags" {
  source = "../common-tags"

  environment = var.environment
  service     = var.service_name
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
  project     = var.project
  data_class  = var.data_class

  additional_tags = var.additional_tags
}

resource "aws_*" "this" {
  # ...

  tags = merge(
    module.tags.tags,
    {
      Name      = "resource-name"
      Component = "component-type"
    }
  )
}
```

### 필수 변수 (모든 모듈 공통)

```hcl
# variables.tf

# Required Tagging Variables
variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stage", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stage, staging, prod."
  }
}

variable "service_name" {
  description = "Service name (kebab-case)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.service_name))
    error_message = "Service name must use kebab-case."
  }
}

variable "team" {
  description = "Team responsible for the resource"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.team))
    error_message = "Team must use kebab-case."
  }
}

variable "owner" {
  description = "Resource owner email"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner))
    error_message = "Owner must be a valid email address."
  }
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cost_center))
    error_message = "Cost center must use kebab-case."
  }
}

# Optional Tagging Variables
variable "project" {
  description = "Project name"
  type        = string
  default     = "infrastructure"
}

variable "data_class" {
  description = "Data classification (confidential, internal, public)"
  type        = string
  default     = "confidential"  # 모듈별 적절한 기본값 설정
  validation {
    condition     = contains(["confidential", "internal", "public"], var.data_class)
    error_message = "Data class must be one of: confidential, internal, public."
  }
}

variable "additional_tags" {
  description = "Additional tags to merge"
  type        = map(string)
  default     = {}
}
```

### 모듈별 기본 data_class

| 모듈 | 기본 data_class | 이유 |
|------|----------------|------|
| **cloudwatch-log-group** | confidential | 로그에 민감정보 포함 가능 |
| **ecr** | confidential | 컨테이너 이미지는 코드 자산 |
| **ecs-service** | confidential | 애플리케이션 워크로드 |
| **elasticache** | confidential | 캐시 데이터는 민감정보 |
| **iam-role-policy** | confidential | IAM 정책은 보안 민감 |
| **lambda** | confidential | 함수 코드 및 환경변수 |
| **rds** | confidential | 데이터베이스는 민감정보 |
| **s3-bucket** | confidential | 버킷 내용물에 따라 다름 |
| **waf** | confidential | 보안 규칙은 민감정보 |
| **alb** | internal | 내부 트래픽 라우팅 |
| **messaging-pattern** | internal | 메시지 큐/토픽 |
| **route53-record** | internal | DNS 레코드 |
| **security-group** | internal | 네트워크 규칙 |
| **sns** | internal | 메시징 서비스 |
| **sqs** | internal | 큐 서비스 |
| **cloudfront** | public | CDN은 공개 콘텐츠 |
| **eventbridge** | confidential | 이벤트 패턴에 민감정보 |

## ✅ 모듈 품질 기준

### 거버넌스 준수 체크리스트

모듈이 다음 기준을 충족해야 합니다:

- [x] common-tags 모듈 내부 통합
- [x] 8개 필수 태그 자동 생성 (Owner, CostCenter, Environment, Lifecycle, DataClass, Service, ManagedBy, Project)
- [x] Variables에 validation 블록 포함
- [x] README.md 완성 (사용 예제 inline 포함, Variables, Outputs)
- [x] CHANGELOG.md 유지 (Semantic Versioning)
- [x] terraform fmt 적용
- [x] terraform validate 통과

### 코딩 표준

- **변수 정렬**: 알파벳 순서
- **변수 우선순위**: Required (Tagging) → Required (Config) → Optional
- **출력 정렬**: 알파벳 순서
- **네이밍**:
  - 리소스: kebab-case
  - 변수/출력: snake_case
- **들여쓰기**: 2 spaces

## 🏷️ 버전 관리

### Semantic Versioning

모든 모듈은 [Semantic Versioning 2.0.0](https://semver.org/)을 따릅니다.

- **MAJOR (v1.0.0 → v2.0.0)**: Breaking changes
- **MINOR (v2.0.0 → v2.1.0)**: 새로운 기능 추가 (호환 가능)
- **PATCH (v2.0.0 → v2.0.1)**: 버그 수정 (호환 가능)

### Git 태그 규칙 (향후 적용 예정)

```bash
# 개별 모듈 버전
modules/{module-name}/v{major}.{minor}.{patch}
# 예: modules/ecr/v2.0.0

# 전체 모듈 릴리스 (여러 모듈 동시 릴리스)
modules/v{major}.{minor}.{patch}
# 예: modules/v2.0.0
```

## 📊 모듈 현황

### 통계

- **활성 모듈**: 18개
- **현재 버전**: v1.0.0 (2025-11-23 초기 릴리스)
- **거버넌스 준수율**: 100%

### v1.0.0 주요 특징 (2025-11-23)

✅ **모든 18개 모듈 표준화 완료**:
- common-tags 모듈 내부 통합
- 거버넌스 표준 자동 적용
- Validation 규칙 강화
- 한국어 문서화 (README + CHANGELOG)
- 사용 예제 inline 포함

### 로드맵

- ✅ Phase 1: 공통 모듈 (common-tags) - **완료** (v1.0.0)
- ✅ Phase 2: 전체 모듈 common-tags 의무화 - **완료** (v1.0.0)
- ✅ Phase 3: 한국어 문서화 및 표준화 - **완료** (v1.0.0)
- 📝 Phase 4: Git 태그 기반 버전 관리 - **계획중**
- 📝 Phase 5: 모듈 테스트 자동화 - **계획중**
- 📝 Phase 6: 모듈 레지스트리 구축 - **계획중**

## 🔗 관련 문서

- [모듈 개발 템플릿](../../docs/MODULE_TEMPLATE.md)
- [거버넌스 표준](../../docs/governance/GOVERNANCE_STANDARDS.md)
- [태그 표준](../../docs/TAGGING_STANDARDS.md)
- [모듈 리팩토링 보고서](./MODULE_REFACTORING_REPORT.md)

## 📞 문의 및 기여

- **문의**: Platform Team (platform@example.com)
- **Slack**: #infrastructure-team
- **기여 가이드**: [CONTRIBUTING.md](../../CONTRIBUTING.md)

## ✅ 모듈 사용 체크리스트

### 새 모듈 추가 시

- [ ] 표준 디렉터리 구조 준수
- [ ] common-tags 모듈 내부 통합
- [ ] 8개 필수 태그 변수 정의 (validation 포함)
- [ ] README.md 작성 (한국어, 사용 예제 inline)
- [ ] CHANGELOG.md 작성 (Keep a Changelog 형식)
- [ ] terraform fmt 실행
- [ ] terraform validate 통과

### 모듈 사용 시

- [ ] 필수 태그 변수 5개 제공: environment, service_name, team, owner, cost_center
- [ ] 변수 validation 규칙 준수 (kebab-case, email 형식 등)
- [ ] 선택적 변수 검토: project, data_class, additional_tags
- [ ] terraform plan으로 리소스 확인
- [ ] 태그가 올바르게 적용되었는지 검증

---

**Last Updated**: 2025-11-23
**Version**: 1.0.0 (초기 릴리스 - 18개 모듈 표준화)
**Maintained By**: Platform Team
