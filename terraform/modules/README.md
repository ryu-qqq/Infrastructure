# Terraform Modules Catalog

재사용 가능한 Terraform 모듈 카탈로그입니다. 각 모듈은 표준화된 구조와 문서를 따르며, Semantic Versioning으로 버전 관리됩니다.

## 📋 모듈 목록

### Infrastructure Core Modules

| 모듈 | 버전 | 설명 | 상태 |
|------|------|------|------|
| [common-tags](./common-tags/) | - | 표준 태그 생성 모듈 | ✅ Active |
| [cloudwatch-log-group](./cloudwatch-log-group/) | - | CloudWatch Log Group 생성 및 관리 | ✅ Active |

### Planned Modules (Epic 4)

| 모듈 | Epic Task | 설명 | 상태 |
|------|-----------|------|------|
| ecs-service | IN-122 | ECS Service 표준 모듈 | 📝 Planned |
| rds-instance | IN-123 | RDS Instance 표준 모듈 | 📝 Planned |
| alb | IN-124 | Application Load Balancer 모듈 | 📝 Planned |
| iam-role | IN-125 | IAM Role/Policy 표준 모듈 | 📝 Planned |
| security-group | IN-126 | Security Group 표준 모듈 | 📝 Planned |

## 🚀 빠른 시작

### 모듈 사용 방법

```hcl
# 로컬 모듈 참조
module "example" {
  source = "../../modules/module-name"

  # 필수 변수
  name = "my-resource"

  # 공통 태그 (권장)
  common_tags = module.common_tags.tags
}

# 공통 태그 모듈 (대부분의 모듈에서 필요)
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "api-server"
  team        = "platform-team"
  owner       = "platform@example.com"
  cost_center = "engineering"
}
```

### Git 태그 기반 버전 참조 (향후)

```hcl
module "example" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/module-name?ref=modules/module-name/v1.0.0"
  # ...
}
```

## 📚 모듈 개발 가이드

### 표준 디렉터리 구조

```
terraform/modules/{module-name}/
├── README.md           # 모듈 문서 (필수)
├── main.tf             # 주요 리소스 정의 (필수)
├── variables.tf        # 입력 변수 (필수)
├── outputs.tf          # 출력 값 (필수)
├── versions.tf         # Provider 버전 제약 (권장)
├── locals.tf           # Local 값 (선택)
├── CHANGELOG.md        # 변경 이력 (필수)
├── examples/           # 사용 예제 (권장)
│   ├── basic/
│   ├── advanced/
│   └── complete/
└── tests/              # 테스트 (선택)
```

### 필수 문서

각 모듈은 다음 섹션을 포함하는 README.md를 가져야 합니다:
- 모듈 설명 및 Features
- Usage 예제 (최소 1개)
- Inputs 테이블
- Outputs 테이블
- Requirements
- 관련 문서 링크

템플릿: [MODULE_TEMPLATE.md](../../docs/MODULE_TEMPLATE.md) 참조

### 개발 워크플로우

1. **구조 생성**: 표준 디렉터리 구조 생성
2. **코드 작성**: main.tf, variables.tf, outputs.tf
3. **문서화**: README.md 작성
4. **예제 작성**: 최소 basic 예제 포함
5. **검증**: terraform fmt, validate, plan
6. **CHANGELOG**: 변경 이력 기록
7. **버전 태깅**: Git 태그 생성

## 🏷️ 버전 관리

### Semantic Versioning

모든 모듈은 [Semantic Versioning 2.0.0](https://semver.org/)을 따릅니다.

- **MAJOR (v1.0.0 → v2.0.0)**: Breaking changes
- **MINOR (v1.0.0 → v1.1.0)**: 새로운 기능 추가 (호환 가능)
- **PATCH (v1.0.0 → v1.0.1)**: 버그 수정 (호환 가능)

### Git 태그 규칙

```bash
# 개별 모듈 버전
modules/{module-name}/v{major}.{minor}.{patch}
# 예: modules/ecs-service/v1.0.0

# 전체 모듈 릴리스 (여러 모듈 동시 릴리스)
modules/v{major}.{minor}.{patch}
# 예: modules/v1.0.0
```

자세한 내용: [VERSIONING.md](../../docs/VERSIONING.md)

## ✅ 모듈 품질 기준

### 검증 체크리스트

모듈이 다음 기준을 충족해야 합니다:

- [ ] README.md 완성 (템플릿 준수)
- [ ] Variables에 validation 블록 포함
- [ ] 최소 1개 사용 예제 제공
- [ ] CHANGELOG.md 유지
- [ ] 표준 태그 적용 (common-tags 모듈)
- [ ] terraform fmt 적용
- [ ] terraform validate 통과
- [ ] terraform plan 정상 실행

### 코딩 표준

- **변수 정렬**: 알파벳 순서
- **변수 우선순위**: 필수 → 선택적
- **출력 정렬**: 알파벳 순서
- **네이밍**: snake_case
- **들여쓰기**: 2 spaces
- **주석**: 복잡한 로직에만 필요 시

## 🏗️ 아키텍처 원칙

### 단일 책임 원칙
각 모듈은 하나의 명확한 목적을 가져야 합니다.
- ✅ Good: `ecs-service`, `rds-instance`
- ❌ Bad: `application-stack` (너무 포괄적)

### 조합 가능성
모듈은 다른 모듈과 쉽게 조합될 수 있어야 합니다.
```hcl
module "logs" {
  source = "../../modules/cloudwatch-log-group"
  # ...
}

module "ecs" {
  source = "../../modules/ecs-service"
  log_configuration = {
    log_group_name = module.logs.log_group_name
  }
}
```

### 최소 의존성
외부 리소스에 대한 의존성을 최소화합니다.
- Data Source보다는 변수로 전달받기
- 필수 의존성은 명확히 문서화

## 🔗 관련 문서

- [모듈 디렉터리 구조 가이드](../../docs/MODULES_DIRECTORY_STRUCTURE.md)
- [모듈 README 템플릿](../../docs/MODULE_TEMPLATE.md)
- [Semantic Versioning 가이드](../../docs/VERSIONING.md)
- [CHANGELOG 템플릿](../../docs/CHANGELOG_TEMPLATE.md)
- [태그 표준](../../docs/TAGGING_STANDARDS.md)

## 📞 문의 및 기여

- **Epic**: [IN-100 - 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)
- **문의**: Platform Team
- **기여 가이드**: [CONTRIBUTING.md](../../CONTRIBUTING.md)

## 📊 모듈 현황

### 통계
- **활성 모듈**: 2개
- **개발 예정**: 5개
- **총 목표**: 7개 (Epic 4)

### 로드맵
- ✅ Phase 1: 공통 모듈 (common-tags, cloudwatch-log-group)
- 🔄 Phase 2: 컴퓨팅 모듈 (ecs-service)
- 📝 Phase 3: 데이터베이스 모듈 (rds-instance)
- 📝 Phase 4: 네트워킹 모듈 (alb, security-group)
- 📝 Phase 5: IAM 모듈 (iam-role)
- 📝 Phase 6: v1.0.0 릴리스

---

**Last Updated**: 2025-10-14
**Maintained By**: Infrastructure Team
