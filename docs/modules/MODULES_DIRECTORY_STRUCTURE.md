# Terraform Modules Directory Structure

## 목적

재사용 가능한 Terraform 모듈의 표준 디렉터리 구조와 파일 규칙을 정의합니다.

## 디렉터리 구조

```
terraform/modules/
├── README.md                           # 모듈 카탈로그 및 사용 가이드
├── VERSIONING.md                       # Semantic Versioning 가이드
├── CHANGELOG.md                        # 전체 모듈 변경 이력
├── MODULE_TEMPLATE.md                  # 표준 모듈 README 템플릿
│
├── {module-name}/                      # 개별 모듈 디렉터리
│   ├── README.md                       # 모듈 문서 (필수)
│   ├── main.tf                         # 주요 리소스 정의 (필수)
│   ├── variables.tf                    # 입력 변수 정의 (필수)
│   ├── outputs.tf                      # 출력 값 정의 (필수)
│   ├── versions.tf                     # Provider 버전 제약 (권장)
│   ├── locals.tf                       # Local 값 정의 (선택)
│   ├── data.tf                         # Data Source 정의 (선택)
│   ├── {resource-type}.tf              # 리소스별 분리 파일 (선택)
│   ├── CHANGELOG.md                    # 모듈별 변경 이력 (필수)
│   ├── examples/                       # 사용 예제 (권장)
│   │   ├── basic/                      # 기본 사용 예제
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── README.md
│   │   ├── advanced/                   # 고급 사용 예제
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── README.md
│   │   └── complete/                   # 전체 기능 예제
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── README.md
│   └── tests/                          # 테스트 파일 (선택)
│       └── {module-name}_test.go
```

## 필수 파일

### 1. README.md
모듈 문서화의 핵심으로, 다음 섹션을 포함해야 합니다:
- 모듈 설명 및 목적
- Features 목록
- Usage 예제 (최소 1개)
- Inputs 테이블
- Outputs 테이블
- Requirements (Terraform/Provider 버전)
- 관련 문서 링크

템플릿: [MODULE_TEMPLATE.md](./MODULE_TEMPLATE.md) 참조

### 2. main.tf
- 주요 리소스 정의
- 모듈의 핵심 로직
- 복잡한 모듈의 경우 리소스 타입별로 파일 분리 가능

### 3. variables.tf
```hcl
# 변수 정의 형식
variable "name" {
  description = "명확한 설명"
  type        = string
  default     = null  # 선택적 변수인 경우

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "구체적인 에러 메시지"
  }
}
```

**변수 정의 규칙:**
- 알파벳 순서로 정렬
- 필수 변수 먼저, 선택적 변수는 나중에
- validation 블록 적극 활용
- 명확하고 구체적인 description 작성

### 4. outputs.tf
```hcl
# 출력 정의 형식
output "resource_id" {
  description = "리소스의 고유 식별자"
  value       = aws_resource.this.id
  sensitive   = false  # 민감한 정보인 경우 true
}
```

**출력 정의 규칙:**
- 알파벳 순서로 정렬
- 주요 속성 (ID, ARN, Name) 우선
- 민감한 정보는 sensitive = true 설정

### 5. versions.tf (권장)
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

### 6. CHANGELOG.md
각 모듈의 변경 이력을 Semantic Versioning에 따라 기록합니다.

형식: [CHANGELOG_TEMPLATE.md](./CHANGELOG_TEMPLATE.md) 참조

## 선택적 파일

### locals.tf
복잡한 로컬 값이나 태그 병합 로직이 있는 경우 분리

### data.tf
Data Source가 많거나 복잡한 경우 분리

### {resource-type}.tf
모듈이 여러 타입의 리소스를 생성하는 경우 타입별로 분리
- 예: `ecs.tf`, `iam.tf`, `monitoring.tf`

## 모듈 네이밍 규칙

### 모듈 디렉터리명
- 소문자와 하이픈 사용: `module-name`
- AWS 리소스 타입 기반: `{service}-{resource}`
  - 예: `ecs-service`, `rds-instance`, `alb-target-group`
- 범용 모듈: `{purpose}-{function}`
  - 예: `common-tags`, `naming-convention`

### 파일명
- 소문자와 하이픈 사용
- 명확한 목적 표현
- 표준 파일명 우선 사용 (`main.tf`, `variables.tf`, `outputs.tf`)

## 모듈 예제 디렉터리 구조

### examples/ 구조
```
examples/
├── basic/              # 최소 설정 예제
│   ├── main.tf
│   ├── variables.tf
│   └── README.md
│
├── advanced/           # 고급 기능 예제
│   ├── main.tf
│   ├── variables.tf
│   └── README.md
│
└── complete/           # 모든 기능 활용 예제
    ├── main.tf
    ├── variables.tf
    └── README.md
```

### 예제 작성 가이드
1. **basic**: 최소한의 필수 변수만 사용
2. **advanced**: 주요 선택적 변수 활용
3. **complete**: 모든 기능과 변수를 활용한 실제 운영 시나리오

각 예제는 독립적으로 `terraform init`, `terraform plan` 실행 가능해야 합니다.

## 모듈 개발 워크플로우

1. **계획**: Epic/Task 기반 요구사항 정의
2. **구조 생성**: 표준 디렉터리 구조 생성
3. **코드 작성**: main.tf, variables.tf, outputs.tf
4. **문서화**: README.md 작성 (템플릿 활용)
5. **예제 작성**: 최소 basic 예제 포함
6. **테스트**: 로컬에서 terraform plan 검증
7. **CHANGELOG**: 변경 이력 기록
8. **버전 태깅**: Semantic Versioning 기반 태그 생성

## 모듈 버전 관리

### Git 태그 규칙
- 개별 모듈 버전: `modules/{module-name}/v{major}.{minor}.{patch}`
  - 예: `modules/ecs-service/v1.0.0`
- 전체 모듈 릴리스: `modules/v{major}.{minor}.{patch}`
  - 예: `modules/v1.0.0` (여러 모듈의 첫 릴리스)

### 버전 관리 상세 가이드
자세한 내용은 [VERSIONING.md](./VERSIONING.md) 참조

## 모듈 사용 예시

### Source 경로 지정
```hcl
# 로컬 모듈 사용
module "example" {
  source = "../../modules/module-name"
  # ...
}

# Git 태그 기반 버전 지정 (향후)
module "example" {
  source = "git::https://github.com/org/infrastructure.git//terraform/modules/module-name?ref=modules/module-name/v1.0.0"
  # ...
}
```

## 태그 표준화

모든 모듈은 `common-tags` 모듈과 통합하여 표준 태그를 적용해야 합니다.

### 표준 태그
```hcl
module "common_tags" {
  source = "../../modules/common-tags"

  environment = var.environment
  service     = var.service
  team        = var.team
  owner       = var.owner
  cost_center = var.cost_center
}

resource "aws_resource" "this" {
  # ...

  tags = merge(
    module.common_tags.tags,
    {
      Name = var.name
      # 리소스별 추가 태그
    }
  )
}
```

자세한 내용은 [TAGGING_STANDARDS.md](../governance/TAGGING_STANDARDS.md) 참조

## 검증 체크리스트

모듈 개발 완료 전 다음 항목을 확인합니다:

- [ ] README.md 작성 완료 (템플릿 준수)
- [ ] main.tf, variables.tf, outputs.tf 작성
- [ ] versions.tf에 Provider 버전 제약 정의
- [ ] 변수에 validation 블록 추가
- [ ] 최소 1개 이상의 사용 예제 작성
- [ ] CHANGELOG.md 업데이트
- [ ] 표준 태그 적용 (common-tags 모듈 활용)
- [ ] terraform fmt 적용
- [ ] terraform validate 통과
- [ ] terraform plan 정상 실행 확인

## 관련 문서

- [MODULE_TEMPLATE.md](./MODULE_TEMPLATE.md) - 표준 README 템플릿
- [VERSIONING.md](./VERSIONING.md) - Semantic Versioning 가이드
- [CHANGELOG_TEMPLATE.md](./CHANGELOG_TEMPLATE.md) - CHANGELOG 작성 가이드
- [TAGGING_STANDARDS.md](../governance/TAGGING_STANDARDS.md) - 태그 표준
- [LOGGING_NAMING_CONVENTION.md](./LOGGING_NAMING_CONVENTION.md) - 로깅 네이밍 규칙

## Epic 및 Task 참조

- Epic: [IN-100 - EPIC 4: 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)
- Task: [IN-121 - TASK 4-1: 모듈 디렉터리 구조 설계](https://ryuqqq.atlassian.net/browse/IN-121)
