# Common Tags Module

## 개요

모든 AWS 리소스에 대한 표준화된 태깅 스키마를 제공하는 핵심 모듈입니다. 이 모듈은 infrastructure 프로젝트의 가장 기본적이고 중요한 구성 요소로, 거버넌스 표준을 준수하고 리소스 추적, 비용 관리, 보안 정책을 통합적으로 관리합니다.

**모듈 버전**: v1.0.0
**마지막 업데이트**: 2025-11-23

## 중요성

이 모듈은 다음과 같은 이유로 infrastructure 프로젝트의 **필수 기반 모듈**입니다:

1. **거버넌스 준수**: 모든 AWS 리소스는 8개의 필수 태그를 가져야 하며, 이를 자동화
2. **비용 추적**: CostCenter, Service, Environment 태그를 통한 정확한 비용 배분
3. **보안 분류**: DataClass 태그를 통한 데이터 민감도 관리
4. **운영 효율성**: Owner, Team 태그를 통한 책임 소재 명확화
5. **자동화 기반**: ManagedBy 태그를 통한 리소스 관리 방식 추적
6. **일관성 보장**: 모든 리소스에 동일한 태깅 표준 적용

## 기능

- **8개 필수 태그 자동 생성**: Owner, CostCenter, Environment, Lifecycle, DataClass, Service, ManagedBy, Project
- **환경별 Lifecycle 자동 매핑**: dev → development, staging → staging, prod → production
- **입력 검증**: 모든 필수 변수에 대한 validation rules 적용
- **추가 태그 지원**: 리소스별 고유 태그를 required tags와 병합
- **명명 규칙 강제**: kebab-case, email 형식 등 표준 준수

## 사용법

### 기본 사용

```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

resource "aws_ecr_repository" "app" {
  name = "api-server"

  tags = module.common_tags.tags
}
```

### 추가 태그와 함께 사용

```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "database"
  team        = "data-team"
  owner       = "data-team@example.com"
  cost_center = "engineering"

  additional_tags = {
    Name      = "prod-postgres-main"
    Component = "database"
    Backup    = "daily"
  }
}

resource "aws_db_instance" "main" {
  identifier = "prod-postgres-main"
  # ... other configuration ...

  tags = module.common_tags.tags
}
```

### Required Tags만 사용

```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "dev"
  service     = "cache"
  team        = "backend-team"
  owner       = "backend-team"
  cost_center = "engineering"
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id = "dev-cache-redis"
  # ... other configuration ...

  tags = module.common_tags.required_tags  # Required tags only
}
```

### 프로젝트 및 데이터 분류 지정

```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "analytics"
  team        = "data-team"
  owner       = "data-analytics@example.com"
  cost_center = "data-science"

  project    = "customer-insights"
  data_class = "confidential"
  managed_by = "terraform"
}
```

## 입력 변수

### 필수 변수

| 변수 | 타입 | 설명 | 제약 조건 |
|------|------|------|-----------|
| `environment` | string | 환경 이름 | dev, staging, prod 중 하나 |
| `service` | string | 서비스 이름 | kebab-case 형식 필수 |
| `team` | string | 리소스 담당 팀 | kebab-case 형식 필수 |
| `owner` | string | 리소스 소유자 | email 또는 kebab-case 형식 |
| `cost_center` | string | 비용 센터 | kebab-case 형식 필수 |

### 선택적 변수 (기본값 포함)

| 변수 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `managed_by` | string | "terraform" | 리소스 관리 방식 (terraform, manual, cloudformation, cdk) |
| `project` | string | "infrastructure" | 프로젝트 이름 (kebab-case) |
| `data_class` | string | "confidential" | 데이터 분류 (confidential, internal, public) |
| `additional_tags` | map(string) | {} | 추가 태그 맵 |

## 출력 값

| 출력 | 타입 | 설명 |
|------|------|------|
| `tags` | map(string) | 필수 태그 + 추가 태그가 병합된 완전한 태그 세트 |
| `required_tags` | map(string) | 필수 태그만 포함한 태그 세트 |

## 생성되는 태그

이 모듈은 다음 8개의 필수 태그를 자동으로 생성합니다:

| 태그 키 | 설명 | 예시 값 |
|---------|------|---------|
| `Owner` | 리소스 소유자 (이메일 또는 식별자) | platform@example.com |
| `CostCenter` | 비용 센터 | engineering |
| `Environment` | 환경 (dev/staging/prod) | prod |
| `Lifecycle` | 생명주기 (자동 매핑) | production |
| `DataClass` | 데이터 분류 수준 | confidential |
| `Service` | 서비스 이름 | api-server |
| `ManagedBy` | 관리 도구 | terraform |
| `Project` | 프로젝트 이름 | infrastructure |

## Lifecycle 자동 매핑

Environment 값에 따라 Lifecycle이 자동으로 매핑됩니다:

- `prod` → `production`
- `staging` → `staging`
- `dev` → `development`
- 기타 → `temporary`

## Validation Rules

### Environment
- **허용 값**: dev, staging, prod
- **에러 예**: "test", "qa", "demo" 사용 시 validation 실패

### Service, Team, Cost Center, Project
- **형식**: kebab-case (소문자, 숫자, 하이픈만 허용)
- **규칙**: 첫 글자와 마지막 글자는 문자 또는 숫자여야 함
- **올바른 예**: api-server, platform-team, backend-team, data-science
- **잘못된 예**: API-Server, platform_team, -backend, team-

### Owner
- **형식 1**: 유효한 이메일 주소 (예: user@example.com)
- **형식 2**: kebab-case 식별자 (예: platform-team)
- **올바른 예**: platform@example.com, backend-team
- **잘못된 예**: invalid.email, Backend_Team

### Managed By
- **허용 값**: terraform, manual, cloudformation, cdk
- **에러 예**: "ansible", "script" 사용 시 validation 실패

### Data Class
- **허용 값**: confidential, internal, public
- **에러 예**: "secret", "private" 사용 시 validation 실패

## 모범 사례

### 1. 모든 리소스에 일관되게 적용

```hcl
# 각 스택의 시작 부분에서 공통 태그 모듈 정의
module "common_tags" {
  source = "../../modules/common-tags"

  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
}

# 모든 리소스에 적용
resource "aws_s3_bucket" "data" {
  tags = module.common_tags.tags
}

resource "aws_dynamodb_table" "users" {
  tags = module.common_tags.tags
}

resource "aws_lambda_function" "processor" {
  tags = module.common_tags.tags
}
```

### 2. 리소스별 고유 태그 추가

```hcl
# 공통 태그
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "storage"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}

# 리소스별 고유 태그 병합
resource "aws_s3_bucket" "logs" {
  bucket = "prod-application-logs"

  tags = merge(
    module.common_tags.tags,
    {
      Name           = "prod-application-logs"
      RetentionDays  = "90"
      LogType        = "application"
    }
  )
}
```

### 3. 데이터 민감도에 따른 분류

```hcl
# 기밀 데이터 (기본값)
module "pii_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "user-database"
  team        = "data-team"
  owner       = "data@example.com"
  cost_center = "engineering"
  data_class  = "confidential"  # PII 데이터
}

# 내부 데이터
module "internal_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "analytics"
  team        = "data-team"
  owner       = "data@example.com"
  cost_center = "data-science"
  data_class  = "internal"  # 내부 분석 데이터
}

# 공개 데이터
module "public_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "static-content"
  team        = "frontend-team"
  owner       = "frontend@example.com"
  cost_center = "marketing"
  data_class  = "public"  # 공개 정적 콘텐츠
}
```

### 4. 프로젝트별 리소스 그룹화

```hcl
# Project A 리소스
module "project_a_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-gateway"
  team        = "backend-team"
  owner       = "backend@example.com"
  cost_center = "engineering"
  project     = "customer-portal"
}

# Project B 리소스
module "project_b_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "analytics-pipeline"
  team        = "data-team"
  owner       = "data@example.com"
  cost_center = "data-science"
  project     = "business-intelligence"
}
```

## 거버넌스 준수

이 모듈은 다음 거버넌스 표준을 준수합니다:

1. **필수 태그 정책**: 모든 AWS 리소스는 8개 필수 태그를 가져야 함
2. **명명 규칙**: kebab-case 형식 강제
3. **환경 표준화**: dev, staging, prod만 허용
4. **데이터 분류**: confidential, internal, public 3단계 분류
5. **관리 추적**: 리소스 관리 방식 명시 (terraform, manual 등)

### CI/CD 검증

이 모듈로 생성된 태그는 다음 검증 단계를 통과합니다:

- **check-tags.sh**: 필수 태그 존재 여부 확인
- **check-naming.sh**: 명명 규칙 준수 확인
- **conftest**: OPA 정책 검증
- **terraform validate**: 입력 변수 validation rules 검증

## 비용 추적 활용

생성된 태그를 AWS Cost Explorer에서 활용:

```
비용 분석 차원:
- Service: 서비스별 비용
- Environment: 환경별 비용 (dev/staging/prod)
- CostCenter: 비용 센터별 배분
- Project: 프로젝트별 예산 추적
- Team: 팀별 리소스 사용량
```

## 보안 정책 적용

DataClass 태그를 활용한 보안 정책:

```hcl
# KMS 키 선택 로직 예시
locals {
  kms_key = var.data_class == "confidential" ? aws_kms_key.confidential.arn :
            var.data_class == "internal" ? aws_kms_key.internal.arn :
            null  # public data - no encryption required
}
```

## 문제 해결

### Validation 오류

**오류**: `Environment must be one of: dev, staging, prod`
```hcl
# 잘못된 코드
module "tags" {
  environment = "test"  # ❌ 허용되지 않는 값
}

# 올바른 코드
module "tags" {
  environment = "dev"   # ✅ 허용된 값
}
```

**오류**: `Service must use kebab-case`
```hcl
# 잘못된 코드
module "tags" {
  service = "API_Server"  # ❌ 언더스코어, 대문자 사용
}

# 올바른 코드
module "tags" {
  service = "api-server"  # ✅ kebab-case
}
```

**오류**: `Owner must be a valid email address or kebab-case identifier`
```hcl
# 잘못된 코드
module "tags" {
  owner = "Platform Team"  # ❌ 공백 포함
}

# 올바른 코드 (옵션 1)
module "tags" {
  owner = "platform@example.com"  # ✅ 이메일
}

# 올바른 코드 (옵션 2)
module "tags" {
  owner = "platform-team"  # ✅ kebab-case
}
```

### 태그가 리소스에 적용되지 않음

**문제**: 리소스에 태그가 보이지 않음

**해결**:
```hcl
# 모듈 출력을 직접 사용했는지 확인
resource "aws_instance" "app" {
  # ❌ 잘못된 방법
  tags = {
    Name = "app-server"
  }
}

# ✅ 올바른 방법 1: tags 출력 사용
resource "aws_instance" "app" {
  tags = module.common_tags.tags
}

# ✅ 올바른 방법 2: merge 사용
resource "aws_instance" "app" {
  tags = merge(
    module.common_tags.tags,
    {
      Name = "app-server"
    }
  )
}
```

## 버전 호환성

- **Terraform**: >= 1.0
- **AWS Provider**: 지정 없음 (모든 버전과 호환)

## 관련 문서

- [거버넌스 표준](/docs/governance/README.md)
- [태깅 정책](/docs/governance/tagging-policy.md)
- [명명 규칙](/docs/governance/naming-conventions.md)
- [INFRASTRUCTURE_RULES.md](/.claude/INFRASTRUCTURE_RULES.md)

## 변경 이력

자세한 변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## 라이선스

이 모듈은 내부 인프라 프로젝트의 일부로, 조직 내부 사용을 위해 제공됩니다.
