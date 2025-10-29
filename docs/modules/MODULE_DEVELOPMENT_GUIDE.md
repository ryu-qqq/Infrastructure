# Terraform Module Development Guide

새로운 Terraform 모듈을 개발할 때 따라야 할 표준과 베스트 프랙티스를 정의합니다. 이 가이드는 모듈의 품질, 일관성, 거버넌스 준수를 보장하기 위한 체크리스트와 템플릿을 제공합니다.

## 목차

- [모듈 디렉토리 구조](#모듈-디렉토리-구조)
- [필수 파일](#필수-파일)
- [네이밍 규칙](#네이밍-규칙)
- [거버넌스 준수](#거버넌스-준수)
- [보안 스캔](#보안-스캔)
- [버전 관리](#버전-관리)
- [Examples 작성](#examples-작성)
- [테스트](#테스트)
- [문서화](#문서화)
- [개발 체크리스트](#개발-체크리스트)

---

## 모듈 디렉토리 구조

표준 모듈 디렉토리 구조:

```
terraform/modules/{module-name}/
├── README.md              # 모듈 문서 (필수)
├── CHANGELOG.md           # 변경 이력 (필수)
├── main.tf                # 리소스 정의 (필수)
├── variables.tf           # 입력 변수 (필수)
├── outputs.tf             # 출력 값 (필수)
├── versions.tf            # Provider 버전 제약 (필수)
├── .terraform.lock.hcl    # Provider 의존성 잠금 파일 (자동 생성)
└── examples/              # 사용 예제 디렉토리 (필수)
    ├── basic/             # 기본 사용 예제
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── advanced/          # 고급 사용 예제 (선택)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### 디렉토리 구조 원칙

1. **단일 책임**: 각 모듈은 하나의 AWS 리소스 또는 밀접하게 연관된 리소스 그룹을 관리
2. **독립성**: 모듈은 다른 모듈에 의존하지 않고 독립적으로 사용 가능해야 함
3. **재사용성**: 다양한 환경과 프로젝트에서 재사용할 수 있도록 설계

---

## 필수 파일

### 1. main.tf

**목적**: AWS 리소스 정의 및 구성

**구조**:
```hcl
# Local variables (if needed)
locals {
  tags = merge(
    {
      Name        = var.name
      Environment = var.environment
      Service     = var.service
      Team        = var.team
      Owner       = var.owner
      CostCenter  = var.cost_center
    },
    var.additional_tags
  )
}

# Primary resource
resource "aws_service_resource" "this" {
  # Resource configuration
  name = var.name

  # Required governance
  tags = local.tags
}

# Related resources (if needed)
resource "aws_service_related" "this" {
  # Configuration
}
```

**베스트 프랙티스**:
- 리소스는 논리적 순서대로 정의 (주요 리소스 → 관련 리소스 → 보조 리소스)
- 각 리소스 블록 앞에 주석으로 목적 설명
- 조건부 리소스는 `count` 또는 `for_each` 사용
- 복잡한 표현식은 `locals` 블록에 분리

### 2. variables.tf

**목적**: 모듈 입력 변수 정의

**구조**:
```hcl
# Required variables (no default value)
variable "name" {
  description = "The name of the resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must be lowercase alphanumeric with hyphens (kebab-case)"
  }
}

# Required governance tags
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "service" {
  description = "Service name"
  type        = string
}

variable "team" {
  description = "Team responsible for the resource"
  type        = string
}

variable "owner" {
  description = "Owner email address"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.owner))
    error_message = "Owner must be a valid email address"
  }
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = ""
}

# Optional variables (with default)
variable "enabled" {
  description = "Whether to create the resource"
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

**베스트 프랙티스**:
- 변수는 범주별로 그룹화 (Required → Governance → Optional → Advanced)
- 모든 변수에 `description` 필수 작성
- `type` 명시 (string, number, bool, list, map, object 등)
- 가능한 경우 `validation` 블록 추가
- 민감한 값은 `sensitive = true` 설정

### 3. outputs.tf

**목적**: 모듈 출력 값 정의

**구조**:
```hcl
# Primary resource outputs
output "id" {
  description = "The ID of the resource"
  value       = aws_service_resource.this.id
}

output "arn" {
  description = "The ARN of the resource"
  value       = aws_service_resource.this.arn
}

output "name" {
  description = "The name of the resource"
  value       = aws_service_resource.this.name
}

# Additional useful outputs
output "endpoint" {
  description = "The endpoint URL of the resource"
  value       = aws_service_resource.this.endpoint
}

# Sensitive outputs
output "secret_value" {
  description = "The secret value (sensitive)"
  value       = aws_service_resource.this.secret
  sensitive   = true
}
```

**베스트 프랙티스**:
- 주요 식별자는 항상 출력 (id, arn, name 등)
- 다른 리소스에서 참조할 가능성이 있는 값 출력
- 민감한 값은 `sensitive = true` 설정
- 모든 출력에 `description` 필수 작성

### 4. versions.tf

**목적**: Terraform 및 Provider 버전 제약 정의

**구조**:
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

**베스트 프랙티스**:
- Terraform 최소 버전 명시
- 사용하는 모든 Provider 명시
- 버전 제약은 `>=` 사용 (호환성 유지)
- Breaking change가 있는 경우 상한 버전 설정 (`>= 5.0.0, < 6.0.0`)

### 5. README.md

**목적**: 모듈 사용 가이드 및 문서

**템플릿**: [README 템플릿](#readme-템플릿) 참조

### 6. CHANGELOG.md

**목적**: 모듈 변경 이력 추적

**템플릿**: [CHANGELOG 템플릿](#changelog-템플릿) 참조

---

## 네이밍 규칙

### 리소스 네이밍

**규칙**: `kebab-case` (소문자 + 하이픈)

```hcl
# Good
resource "aws_s3_bucket" "data_storage" {
  bucket = "prod-data-storage-bucket"
}

resource "aws_lambda_function" "api_handler" {
  function_name = "prod-user-api-handler"
}

# Bad
resource "aws_s3_bucket" "data_storage" {
  bucket = "ProdDataStorageBucket"  # PascalCase
}

resource "aws_lambda_function" "api_handler" {
  function_name = "prod_user_api_handler"  # snake_case
}
```

**네이밍 패턴**:
```
{environment}-{service}-{resource-type}-{optional-descriptor}

예시:
- prod-user-api-lambda
- staging-analytics-data-bucket
- dev-app-postgres-rds
```

### 변수 및 로컬 네이밍

**규칙**: `snake_case` (소문자 + 언더스코어)

```hcl
# Good
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

locals {
  common_tags = {
    Environment = var.environment
  }

  log_group_name = "/aws/lambda/${var.function_name}"
}

# Bad
variable "vpcId" {  # camelCase
  type = string
}

variable "subnet-ids" {  # kebab-case
  type = list(string)
}
```

### 출력 네이밍

**규칙**: `snake_case` (소문자 + 언더스코어)

```hcl
# Good
output "bucket_id" {
  value = aws_s3_bucket.this.id
}

output "lambda_arn" {
  value = aws_lambda_function.this.arn
}

# Bad
output "bucket-id" {  # kebab-case
  value = aws_s3_bucket.this.id
}

output "lambdaArn" {  # camelCase
  value = aws_lambda_function.this.arn
}
```

---

## 거버넌스 준수

### 필수 태그

모든 AWS 리소스는 다음 태그를 **반드시** 포함해야 합니다:

```hcl
tags = merge(
  {
    Name        = var.name
    Environment = var.environment
    Service     = var.service
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    Lifecycle   = "managed"
    DataClass   = var.data_class
  },
  var.additional_tags
)
```

**필수 태그 목록**:
- `Owner`: 리소스 소유자 이메일
- `CostCenter`: 비용 센터 코드
- `Environment`: 환경 (dev, staging, prod)
- `Lifecycle`: 라이프사이클 (managed, temporary)
- `DataClass`: 데이터 분류 (public, internal, confidential, restricted)
- `Service`: 서비스 이름
- `Team`: 담당 팀

### KMS 암호화

**규칙**: 모든 암호화는 Customer-Managed KMS 키 사용 (AES256 금지)

```hcl
# Good - Customer-managed KMS key
resource "aws_s3_bucket" "data" {
  bucket = "prod-data-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id  # Customer-managed key
    }
  }
}

# Bad - AES256 (AWS-managed key)
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # Not allowed
    }
  }
}
```

### 보안 기본값

**원칙**: Secure by Default

```hcl
# S3 버킷 - Public access 차단
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# RDS - 공개 접근 차단
resource "aws_db_instance" "this" {
  publicly_accessible = false
  storage_encrypted   = true
  kms_key_id         = var.kms_key_id
}

# Security Group - 최소 권한
resource "aws_security_group" "this" {
  # Ingress rules should be explicit
  # No 0.0.0.0/0 for production
}
```

---

## 보안 스캔

### tfsec (AWS Best Practices)

모듈은 tfsec 스캔을 통과해야 합니다:

```bash
# 로컬 테스트
tfsec terraform/modules/{module-name}

# CI/CD 자동 실행
./scripts/validators/check-tfsec.sh
```

**주요 체크 항목**:
- KMS 암호화 사용
- Public access 차단
- 전송 중 암호화 (TLS/HTTPS)
- 로깅 활성화
- 최소 권한 IAM 정책

### checkov (Compliance)

Compliance 프레임워크 검증:

```bash
# 로컬 테스트
checkov -d terraform/modules/{module-name}

# CI/CD 자동 실행
./scripts/validators/check-checkov.sh
```

**검증 프레임워크**:
- CIS AWS Foundations Benchmark
- PCI-DSS
- HIPAA
- SOC 2

### 심각도 레벨

| 레벨 | 설명 | 조치 |
|------|------|------|
| CRITICAL | 즉시 수정 필요 | 배포 차단 |
| HIGH | PR 승인 전 수정 | 배포 차단 |
| MEDIUM | PR 승인 전 수정 권장 | 경고 |
| LOW | 개선 권장 | 정보 |

### 예외 처리

정당한 사유가 있는 경우 주석으로 예외 처리:

```hcl
# tfsec:ignore:aws-s3-enable-bucket-logging - Static website hosting bucket
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
}
```

**예외 처리 원칙**:
- 반드시 주석으로 사유 명시
- PR 리뷰에서 예외 사유 검토
- 예외는 최소한으로 제한

---

## 버전 관리

### Semantic Versioning

모듈 버전은 [Semantic Versioning 2.0.0](https://semver.org/)을 따릅니다:

```
MAJOR.MINOR.PATCH

예: 1.0.0, 1.1.0, 2.0.0
```

**버전 증가 규칙**:
- **MAJOR**: Breaking changes (호환성 깨짐)
  - 필수 변수 추가
  - 변수 이름 변경
  - 출력 제거
  - 리소스 재생성 필요

- **MINOR**: 새로운 기능 추가 (하위 호환)
  - 선택적 변수 추가
  - 새로운 출력 추가
  - 새로운 리소스 추가

- **PATCH**: 버그 수정 (하위 호환)
  - 문서 수정
  - 버그 수정
  - 보안 패치

### 릴리즈 프로세스

1. **개발 완료**
   - 모든 테스트 통과
   - 보안 스캔 통과
   - 문서 업데이트

2. **CHANGELOG 업데이트**
   ```markdown
   ## [1.1.0] - 2024-10-19

   ### Added
   - New feature X
   - Support for Y

   ### Changed
   - Improved Z

   ### Fixed
   - Bug fix for W
   ```

3. **Git 태그 생성**
   ```bash
   git tag -a v1.1.0 -m "Release version 1.1.0"
   git push origin v1.1.0
   ```

4. **GitHub Release 생성**
   - Release notes 작성
   - CHANGELOG 내용 포함

### 버전 참조

모듈 사용 시 버전 지정:

```hcl
module "example" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/s3-bucket?ref=v1.1.0"

  # Variables
}
```

---

## Examples 작성

### 디렉토리 구조

```
examples/
├── basic/              # 기본 사용 예제 (필수)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── advanced/           # 고급 사용 예제 (권장)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
└── {use-case}/         # Use case별 예제 (선택)
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── README.md
```

### Basic Example

**목적**: 최소한의 설정으로 모듈 사용 방법 시연

```hcl
# examples/basic/main.tf
module "example" {
  source = "../../"

  # Required variables only
  name        = "example-resource"
  environment = "dev"
  service     = "example-service"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
  project     = "infrastructure"

  # Minimal configuration
  kms_key_id = aws_kms_key.example.arn
}
```

### Advanced Example

**목적**: 고급 기능 및 옵션 활용 시연

```hcl
# examples/advanced/main.tf
module "example" {
  source = "../../"

  # Required variables
  name        = "advanced-example"
  environment = "prod"
  service     = "api-service"
  team        = "backend-team"
  owner       = "backend@example.com"
  cost_center = "engineering"
  project     = "api-platform"

  # Advanced configuration
  kms_key_id = aws_kms_key.example.arn

  # Optional features
  enable_monitoring = true
  enable_logging    = true

  # Custom configuration
  custom_settings = {
    setting1 = "value1"
    setting2 = "value2"
  }

  additional_tags = {
    Component = "api"
    Criticality = "high"
  }
}
```

### Example README

각 예제 디렉토리에 README.md 포함:

```markdown
# Basic Example

This example demonstrates the minimal configuration required to use the module.

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Outputs

- `resource_id`: The ID of the created resource
- `resource_arn`: The ARN of the created resource
```

---

## 테스트

### 로컬 검증

모듈 개발 중 로컬에서 수행할 검증:

```bash
# 1. Terraform 포맷팅
terraform fmt -recursive

# 2. Terraform 검증
cd terraform/modules/{module-name}
terraform init
terraform validate

# 3. tfsec 스캔
tfsec .

# 4. checkov 스캔
checkov -d .

# 5. Example 테스트
cd examples/basic
terraform init
terraform plan
```

### 통합 검증

CI/CD 파이프라인에서 자동 실행:

```bash
# 통합 검증 스크립트
./scripts/validators/validate-terraform-file.sh terraform/modules/{module-name}/main.tf
```

**검증 항목**:
- ✅ Required tags 존재
- ✅ KMS 암호화 사용
- ✅ Naming convention 준수
- ✅ tfsec 통과
- ✅ checkov 통과

### Terraform Plan 테스트

```bash
# Example 디렉토리에서 Plan 테스트
cd examples/basic
terraform init
terraform plan -out=tfplan

# Plan 결과 확인
terraform show tfplan
```

**확인 사항**:
- 생성될 리소스 개수
- 리소스 구성 정확성
- 태그 적용 확인
- 보안 설정 확인

---

## 문서화

### README 템플릿

```markdown
# {Module Name}

{Brief description of the module}

## Features

- Feature 1
- Feature 2
- Feature 3

## Usage

### Basic Example

```hcl
module "example" {
  source = "../../modules/{module-name}"

  # Configuration
}
```

### Advanced Example

```hcl
module "example" {
  source = "../../modules/{module-name}"

  # Advanced configuration
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0.0 |

## Resources

| Name | Type |
|------|------|
| aws_service_resource.this | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Resource name | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| id | Resource ID |
| arn | Resource ARN |

## Examples

- [Basic Example](./examples/basic)
- [Advanced Example](./examples/advanced)

## Security

- KMS encryption enabled by default
- Public access blocked
- Logging enabled

## License

This module is licensed under the MIT License.
```

### CHANGELOG 템플릿

```markdown
# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release of {module-name} module
- Feature X
- Feature Y

### Features
- **Security**: KMS encryption support
- **Compliance**: Governance tag enforcement
- **Flexibility**: Configurable options

### Security
- Default secure configuration
- KMS encryption by default

[1.0.0]: https://github.com/ryu-qqq/Infrastructure/releases/tag/{module-name}-v1.0.0
```

### 문서 자동 생성

terraform-docs를 사용한 자동 문서 생성:

```bash
# terraform-docs 설치
brew install terraform-docs

# README 생성
terraform-docs markdown table . > README.md

# 특정 섹션만 업데이트
terraform-docs markdown table . --output-file README.md --output-mode inject
```

---

## 개발 체크리스트

### 초기 설정

- [ ] 모듈 디렉토리 생성 (`terraform/modules/{module-name}`)
- [ ] Git 브랜치 생성 (`feature/{JIRA-KEY}-{module-name}`)
- [ ] 필수 파일 생성 (main.tf, variables.tf, outputs.tf, versions.tf)
- [ ] README.md 작성 (템플릿 기반)
- [ ] CHANGELOG.md 초기화

### 코드 작성

- [ ] 리소스 정의 (main.tf)
- [ ] 입력 변수 정의 (variables.tf)
  - [ ] Required tags 변수 포함
  - [ ] Validation 블록 추가
- [ ] 출력 값 정의 (outputs.tf)
- [ ] Provider 버전 제약 (versions.tf)

### 거버넌스 준수

- [ ] 필수 태그 적용 (`merge(local.required_tags, ...)`)
- [ ] KMS 암호화 사용 (Customer-managed key)
- [ ] Naming convention 준수 (kebab-case for resources)
- [ ] 보안 기본값 설정 (Secure by Default)

### 예제 작성

- [ ] `examples/basic/` 디렉토리 생성
- [ ] Basic example 작성 (main.tf, variables.tf, outputs.tf)
- [ ] Basic example README 작성
- [ ] Advanced example 작성 (선택)
- [ ] Use case별 예제 작성 (선택)

### 테스트 및 검증

- [ ] `terraform fmt` 실행
- [ ] `terraform init` 성공
- [ ] `terraform validate` 성공
- [ ] tfsec 스캔 통과 (CRITICAL/HIGH 없음)
- [ ] checkov 스캔 통과 (주요 규칙 준수)
- [ ] Example `terraform plan` 성공

### 문서화

- [ ] README.md 완성
  - [ ] Features 섹션
  - [ ] Usage 예제
  - [ ] Inputs 테이블
  - [ ] Outputs 테이블
- [ ] CHANGELOG.md 업데이트
- [ ] 인라인 주석 작성
- [ ] Example README 작성

### 버전 관리

- [ ] 초기 버전 결정 (1.0.0)
- [ ] CHANGELOG에 릴리즈 노트 작성
- [ ] Git 태그 생성 (`v1.0.0`)
- [ ] GitHub Release 생성

### PR 및 배포

- [ ] PR 생성
- [ ] PR 템플릿 작성
- [ ] CI/CD 파이프라인 통과
- [ ] 코드 리뷰 완료
- [ ] PR 머지
- [ ] 배포 확인

---

## 참고 자료

### 내부 문서
- [CLAUDE.md](../../CLAUDE.md) - 프로젝트 개요 및 명령어
- [Governance Standards](../governance/GOVERNANCE_STANDARDS.md) - 거버넌스 표준 (예정)

### 기존 모듈
- [common-tags](../../terraform/modules/common-tags/) - 기본 태그 모듈
- [s3-bucket](../../terraform/modules/s3-bucket/) - S3 버킷 모듈
- [lambda](../../terraform/modules/lambda/) - Lambda 함수 모듈
- [cloudwatch-log-group](../../terraform/modules/cloudwatch-log-group/) - CloudWatch Logs 모듈

### 외부 리소스
- [HashiCorp Module Standards](https://www.terraform.io/docs/modules/index.html)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Terraform Modules](https://github.com/terraform-aws-modules)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)

---

## 문의 및 피드백

모듈 개발 중 문제가 발생하거나 개선 사항이 있다면:

- **GitHub Issues**: Infrastructure 저장소에 이슈 등록
- **팀 채널**: Platform Team Slack 채널

---

**Last Updated**: 2024-10-19
**Version**: 1.0.0
