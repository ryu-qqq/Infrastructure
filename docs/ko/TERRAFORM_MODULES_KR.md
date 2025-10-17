# Terraform 모듈 사용 가이드

## 📋 목차

1. [모듈이란?](#모듈이란)
2. [사용 가능한 모듈](#사용-가능한-모듈)
3. [모듈 사용 방법](#모듈-사용-방법)
4. [모듈 개발 가이드](#모듈-개발-가이드)
5. [버전 관리](#버전-관리)
6. [문제 해결](#문제-해결)

## 모듈이란?

Terraform 모듈은 **재사용 가능한 인프라 구성 요소**입니다. 모듈을 사용하면:
- ✅ 코드 중복을 제거하고 일관성 있는 인프라 구성
- ✅ 조직의 표준과 모범 사례를 자동으로 적용
- ✅ 복잡한 인프라를 간단한 인터페이스로 제공
- ✅ 테스트되고 검증된 구성을 안전하게 재사용

### 모듈의 구조

```
terraform/modules/cloudwatch-log-group/
├── README.md              # 모듈 설명 및 사용법
├── main.tf                # 주요 리소스 정의
├── variables.tf           # 입력 변수 정의
├── outputs.tf             # 출력 값 정의
├── versions.tf            # Terraform 버전 및 provider 요구사항
├── CHANGELOG.md           # 버전별 변경 이력
└── examples/              # 사용 예제
    ├── basic/             # 기본 사용 예제
    ├── advanced/          # 고급 기능 예제
    └── complete/          # 전체 기능 예제
```

## 사용 가능한 모듈

### 1. Common Tags 모듈 ✅ 활성

**목적**: 모든 AWS 리소스에 표준 태그를 일관되게 적용

**위치**: `terraform/modules/common-tags/`

**사용 예시:**
```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform-team@company.com"
  cost_center = "engineering"
}

resource "aws_instance" "api" {
  ami           = "ami-xxxxx"
  instance_type = "t3.medium"

  tags = module.common_tags.tags
}
```

**제공하는 태그:**
- `Environment`: 환경 (dev, staging, prod)
- `Service`: 서비스 이름
- `Team`: 담당 팀
- `Owner`: 소유자 이메일
- `CostCenter`: 비용 센터
- `ManagedBy`: 관리 방법 (terraform)
- `Project`: 프로젝트 이름

### 2. CloudWatch Log Group 모듈 ✅ 활성

**목적**: KMS 암호화가 적용된 CloudWatch 로그 그룹 생성

**위치**: `terraform/modules/cloudwatch-log-group/`

**사용 예시:**
```hcl
module "app_logs" {
  source = "../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/api-server/application"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
  log_type          = "application"
  common_tags       = module.common_tags.tags
}
```

**주요 기능:**
- ✅ KMS 암호화 필수 적용
- ✅ 보존 기간 설정 (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653일)
- ✅ 로그 타입별 분류 (application, audit, access, system)
- ✅ 표준 태그 자동 적용

### 3. 계획 중인 모듈 📋

다음 모듈들이 개발 예정입니다:

#### ECS Service 모듈
- Fargate 기반 ECS 서비스 배포
- Auto Scaling 설정
- Load Balancer 통합
- Service Discovery 지원

#### RDS Instance 모듈
- Multi-AZ 배포
- 자동 백업 및 스냅샷
- 암호화 및 보안 그룹 설정
- Parameter Group 커스터마이징

#### ALB 모듈
- Application Load Balancer 생성
- Target Group 관리
- SSL/TLS 인증서 통합
- 접근 로그 설정

#### IAM Role 모듈
- 표준화된 IAM 역할 생성
- 정책 연결 및 관리
- 최소 권한 원칙 적용

#### Security Group 모듈
- 보안 그룹 생성 및 규칙 관리
- 인바운드/아웃바운드 규칙 설정
- 설명 및 태그 자동 추가

## 모듈 사용 방법

### 1. 기본 사용 패턴

```hcl
# 1. Common tags 모듈 먼저 정의
module "common_tags" {
  source = "../../modules/common-tags"

  environment = var.environment
  service     = var.service_name
  team        = "platform-team"
  owner       = "platform-team@company.com"
  cost_center = "engineering"
}

# 2. 다른 모듈에서 common tags 사용
module "log_group" {
  source = "../../modules/cloudwatch-log-group"

  name              = "/aws/ecs/${var.service_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
  common_tags       = module.common_tags.tags
}

# 3. 직접 생성하는 리소스에도 tags 적용
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.service_name}-cluster"

  tags = module.common_tags.tags
}
```

### 2. 모듈 입력 변수 (Variables)

모듈의 `variables.tf` 파일에서 입력 변수를 확인할 수 있습니다:

```hcl
# terraform/modules/cloudwatch-log-group/variables.tf
variable "name" {
  description = "Log group name (must start with /)"
  type        = string

  validation {
    condition     = can(regex("^/", var.name))
    error_message = "Log group name must start with /"
  }
}

variable "retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.retention_in_days)
    error_message = "retention_in_days must be a valid CloudWatch Logs retention period"
  }
}
```

### 3. 모듈 출력 값 (Outputs)

모듈의 `outputs.tf` 파일에서 출력 값을 확인할 수 있습니다:

```hcl
# 모듈 출력 값 사용
output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = module.app_logs.log_group_name
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group"
  value       = module.app_logs.log_group_arn
}
```

### 4. 로컬 모듈 vs Git 참조

#### 로컬 개발 (현재 방식)
```hcl
module "log_group" {
  source = "../../modules/cloudwatch-log-group"
  # ...
}
```

**장점:**
- 빠른 개발 및 테스트
- 로컬 변경사항 즉시 반영

**단점:**
- 버전 관리 어려움
- 환경 간 일관성 부족

#### Git 태그 참조 (프로덕션 권장)
```hcl
module "log_group" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/cloudwatch-log-group?ref=modules/cloudwatch-log-group/v1.0.0"
  # ...
}
```

**장점:**
- 명확한 버전 관리
- 환경 간 일관성 보장
- 안전한 롤백 가능

**단점:**
- 로컬 변경사항 테스트 복잡
- 버전 업데이트 관리 필요

## 모듈 개발 가이드

### 1. 새 모듈 생성

```bash
# 모듈 디렉토리 생성
cd terraform/modules
mkdir my-new-module
cd my-new-module

# 필수 파일 생성
touch README.md main.tf variables.tf outputs.tf versions.tf CHANGELOG.md

# 예제 디렉토리 생성
mkdir -p examples/{basic,advanced,complete}
```

### 2. 필수 파일 구성

#### README.md
모듈의 설명, 사용법, 입력/출력 변수를 문서화합니다.
- 템플릿: [docs/MODULE_TEMPLATE.md](./MODULE_TEMPLATE.md)

#### main.tf
모듈의 핵심 리소스를 정의합니다.

```hcl
# terraform/modules/my-module/main.tf
resource "aws_example_resource" "this" {
  name = var.name

  # common_tags는 항상 병합하여 적용
  tags = merge(
    var.common_tags,
    var.additional_tags,
    {
      Module = "my-module"
    }
  )
}
```

#### variables.tf
입력 변수를 정의하고 검증 규칙을 추가합니다.

```hcl
# terraform/modules/my-module/variables.tf
variable "name" {
  description = "Resource name (kebab-case)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must use kebab-case"
  }
}

variable "common_tags" {
  description = "Common tags from common-tags module"
  type        = map(string)
  default     = {}
}
```

#### outputs.tf
모듈이 제공하는 출력 값을 정의합니다.

```hcl
# terraform/modules/my-module/outputs.tf
output "id" {
  description = "The ID of the created resource"
  value       = aws_example_resource.this.id
}

output "arn" {
  description = "The ARN of the created resource"
  value       = aws_example_resource.this.arn
}
```

#### versions.tf
Terraform 버전 및 Provider 요구사항을 명시합니다.

```hcl
# terraform/modules/my-module/versions.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
```

### 3. 예제 작성

각 모듈은 3가지 예제를 제공해야 합니다:

#### Basic Example (필수)
최소한의 설정으로 모듈을 사용하는 예제
- 필수 변수만 사용
- 기본값에 의존
- 초보자가 이해하기 쉬운 구성

#### Advanced Example (권장)
주요 선택적 기능을 활용하는 예제
- 실제 운영에 가까운 구성
- Auto scaling, 모니터링 등 고급 기능
- 중급 사용자 대상

#### Complete Example (권장)
모든 기능을 활용한 실제 운영 시나리오
- 모든 주요 변수 활용
- 다중 모듈 통합
- 프로덕션 환경 반영

자세한 가이드: [docs/MODULE_EXAMPLES_GUIDE.md](./MODULE_EXAMPLES_GUIDE.md)

### 4. 코딩 표준

#### 네이밍 규칙
- **변수/출력**: `snake_case` (예: `log_group_name`, `retention_in_days`)
- **리소스**: `.this` 패턴 사용 (예: `aws_cloudwatch_log_group.this`)
- **로컬 변수**: `snake_case` (예: `local.log_group_config`)

#### 파일 구조
```hcl
# 1. Terraform 설정 (versions.tf)
# 2. 데이터 소스 (data.tf 또는 main.tf 상단)
# 3. 로컬 변수 (locals.tf 또는 main.tf)
# 4. 리소스 정의 (main.tf)
# 5. 변수 정의 (variables.tf)
# 6. 출력 정의 (outputs.tf)
```

#### 주석 작성
```hcl
# 복잡한 로직에는 설명 추가
locals {
  # 로그 그룹 이름에서 슬래시를 하이픈으로 치환
  # CloudWatch 리소스 이름 제약 때문에 필요
  sanitized_name = replace(var.name, "/", "-")
}
```

자세한 가이드: [docs/MODULE_STANDARDS_GUIDE.md](./MODULE_STANDARDS_GUIDE.md)

### 5. 검증 및 테스트

```bash
# 1. Terraform 포맷팅
terraform fmt -recursive

# 2. Terraform 검증
cd examples/basic
terraform init
terraform validate
terraform plan

# 3. 거버넌스 검증
./scripts/validators/check-tags.sh
./scripts/validators/check-encryption.sh
./scripts/validators/check-naming.sh

# 4. OPA 정책 검증
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
opa eval --data policies/ --input tfplan.json "data.terraform.deny"
```

## 버전 관리

### Semantic Versioning

모든 모듈은 [Semantic Versioning 2.0.0](https://semver.org/)을 따릅니다.

**버전 형식:** `MAJOR.MINOR.PATCH`

#### MAJOR (1.0.0 → 2.0.0)
**Breaking Changes** - 기존 사용자가 수정 없이 업그레이드할 수 없는 변경

**예시:**
- 필수 변수 추가
- 기존 변수 제거 또는 타입 변경
- 출력 값 제거
- 리소스 이름 변경 (재생성 필요)

#### MINOR (1.0.0 → 1.1.0)
**새로운 기능 추가** - 하위 호환성 유지하며 기능 추가

**예시:**
- 선택적 변수 추가 (기본값 포함)
- 새로운 출력 값 추가
- 새로운 선택적 리소스 추가

#### PATCH (1.0.0 → 1.0.1)
**버그 수정** - 기존 기능의 버그 수정

**예시:**
- 버그 수정
- 문서 수정
- 내부 리팩토링 (외부 인터페이스 불변)

### Git 태그

**개별 모듈 태그:**
```
modules/{module-name}/v{major}.{minor}.{patch}
```

**예시:**
```bash
# 태그 생성
git tag -a modules/cloudwatch-log-group/v1.0.0 -m "Release CloudWatch Log Group module v1.0.0

- Initial release
- KMS encryption support
- Standard tagging integration
"

# 태그 푸시
git push origin modules/cloudwatch-log-group/v1.0.0
```

### CHANGELOG.md

모든 버전 변경사항은 `CHANGELOG.md`에 기록합니다.

**예시:**
```markdown
# Changelog

## [1.1.0] - 2025-10-20

### Added
- Variable `enable_insights` for Container Insights
- Output `log_stream_prefix` for stream identification

### Changed
- Default `retention_in_days` from 7 to 30 days

### Fixed
- Tag merging issue with complex tag maps

## [1.0.0] - 2025-10-10

### Added
- Initial release
- KMS encryption support
- Standard tagging integration
```

자세한 가이드:
- [docs/VERSIONING.md](./VERSIONING.md) - 버전 관리 규칙
- [docs/CHANGELOG_TEMPLATE.md](./CHANGELOG_TEMPLATE.md) - CHANGELOG 작성 가이드

## 문제 해결

### 일반적인 문제

#### 1. 모듈을 찾을 수 없음
```
Error: Module not found
```

**해결 방법:**
```bash
# 모듈 경로 확인
ls -la ../../modules/cloudwatch-log-group

# Terraform 재초기화
terraform init -upgrade
```

#### 2. 변수 검증 실패
```
Error: Invalid value for variable
```

**해결 방법:**
- 모듈의 `variables.tf`에서 validation 규칙 확인
- 올바른 형식으로 변수 값 제공
- 필수 변수가 누락되지 않았는지 확인

#### 3. 태그 검증 실패
```
Error: Required tags missing
```

**해결 방법:**
```hcl
# common-tags 모듈 사용
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "my-service"
  team        = "my-team"
  owner       = "team@company.com"
  cost_center = "engineering"
}

# 모든 리소스에 적용
resource "aws_instance" "app" {
  # ...
  tags = module.common_tags.tags
}
```

#### 4. KMS 암호화 검증 실패
```
Error: KMS encryption required
```

**해결 방법:**
```hcl
# KMS 키 생성
resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = module.common_tags.tags
}

# 모듈에서 사용
module "log_group" {
  source = "../../modules/cloudwatch-log-group"

  kms_key_id = aws_kms_key.logs.arn  # 반드시 제공
  # ...
}
```

### 모듈 개발 체크리스트

새 모듈을 개발할 때 다음 항목을 확인하세요:

- [ ] `README.md` 작성 완료 (템플릿 준수)
- [ ] 필수 파일 존재 (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`)
- [ ] `CHANGELOG.md` 작성 완료
- [ ] 3가지 예제 제공 (basic, advanced, complete)
- [ ] 변수에 validation 규칙 추가
- [ ] 변수/출력에 명확한 description 추가
- [ ] `common_tags` 변수 포함
- [ ] 네이밍 규칙 준수 (snake_case for variables, kebab-case for resources)
- [ ] `terraform fmt` 실행
- [ ] `terraform validate` 통과
- [ ] 거버넌스 검증 통과 (`check-*.sh`)
- [ ] OPA 정책 검증 통과
- [ ] 예제가 독립적으로 실행 가능
- [ ] Git 태그 생성
- [ ] GitHub Release 생성

## 참고 문서

### 모듈 관련
- [모듈 카탈로그](../terraform/modules/README.md) - 사용 가능한 모듈 목록
- [모듈 디렉터리 구조](./MODULES_DIRECTORY_STRUCTURE.md) - 표준 구조
- [모듈 코딩 표준](./MODULE_STANDARDS_GUIDE.md) - 코딩 규칙
- [모듈 예제 가이드](./MODULE_EXAMPLES_GUIDE.md) - 예제 작성법
- [버전 관리 가이드](./VERSIONING.md) - 버전 관리 규칙

### 거버넌스 관련
- [Infrastructure Governance](../governance/infrastructure_governance.md) - 거버넌스 정책
- [Tagging Standards](../governance/TAGGING_STANDARDS.md) - 태깅 표준
- [Naming Convention](./NAMING_CONVENTION.md) - 네이밍 규칙

### Terraform 공식 문서
- [Terraform Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Module Sources](https://developer.hashicorp.com/terraform/language/modules/sources)
- [Publishing Modules](https://developer.hashicorp.com/terraform/registry/modules/publish)

## 관련 Jira 이슈

- **Epic**: [IN-100 - EPIC 4: 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)
- **Task**: [IN-121 - 모듈 디렉터리 구조 설계](https://ryuqqq.atlassian.net/browse/IN-121)
