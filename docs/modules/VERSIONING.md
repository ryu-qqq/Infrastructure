# Terraform Modules Versioning Guide

## 목적

Terraform 모듈의 버전 관리 전략과 Git 태그 규칙을 정의합니다.

## Semantic Versioning 2.0.0

모든 Terraform 모듈은 [Semantic Versioning 2.0.0](https://semver.org/)을 따릅니다.

### 버전 형식

```
{MAJOR}.{MINOR}.{PATCH}
```

예: `1.2.3`

### 버전 증가 규칙

#### MAJOR (1.0.0 → 2.0.0)
**Breaking Changes** - 기존 사용자가 수정 없이 업그레이드할 수 없는 변경

**예시:**
- 필수 변수 추가
- 기존 변수 제거
- 변수 타입 변경 (호환 불가)
- 출력 값 제거
- 리소스 이름 변경 (기존 리소스 재생성 필요)
- 기본값 변경으로 인한 리소스 재생성

**예:**
```hcl
# v1.0.0
variable "name" {
  type = string
}

# v2.0.0 - MAJOR 변경
variable "name" {
  type = object({
    prefix = string
    suffix = string
  })
}
```

#### MINOR (1.0.0 → 1.1.0)
**새로운 기능 추가** - 하위 호환성을 유지하면서 기능 추가

**예시:**
- 선택적 변수 추가 (기본값 포함)
- 새로운 출력 값 추가
- 새로운 선택적 리소스 추가
- 기존 기능 개선 (호환 가능)

**예:**
```hcl
# v1.0.0
variable "name" {
  type = string
}

# v1.1.0 - MINOR 변경
variable "name" {
  type = string
}

variable "tags" {  # 새로운 선택적 변수
  type    = map(string)
  default = {}
}
```

#### PATCH (1.0.0 → 1.0.1)
**버그 수정** - 기존 기능의 버그 수정

**예시:**
- 버그 수정
- 문서 수정
- 내부 리팩토링 (외부 인터페이스 불변)
- 보안 패치
- 성능 개선

**예:**
```hcl
# v1.0.0 - 버그: tags가 제대로 병합되지 않음
tags = var.tags

# v1.0.1 - PATCH: 버그 수정
tags = merge(var.common_tags, var.tags)
```

## Git 태그 규칙

### 개별 모듈 버전 태그

```
modules/{module-name}/v{MAJOR}.{MINOR}.{PATCH}
```

**예시:**
```bash
modules/ecs-service/v1.0.0
modules/ecs-service/v1.1.0
modules/ecs-service/v1.1.1
modules/rds-instance/v1.0.0
```

### 전체 모듈 릴리스 태그

여러 모듈을 동시에 릴리스하는 경우:

```
modules/v{MAJOR}.{MINOR}.{PATCH}
```

**예시:**
```bash
modules/v1.0.0  # 5개 모듈의 첫 릴리스
modules/v1.1.0  # 여러 모듈의 기능 추가
```

## 버전 태깅 워크플로우

### 1. 개발 및 테스트
```bash
# 브랜치에서 개발
git checkout -b feature/ecs-service-module

# 코드 작성 및 테스트
terraform fmt -recursive
terraform validate
terraform plan

# CHANGELOG.md 업데이트
# README.md 업데이트
```

### 2. PR 및 리뷰
```bash
# PR 생성 및 리뷰
git add .
git commit -m "feat(ecs-service): Add ECS service module"
git push origin feature/ecs-service-module

# GitHub에서 PR 생성
# 리뷰 및 승인
```

### 3. 메인 브랜치 병합
```bash
# PR 승인 후 메인으로 병합
git checkout main
git pull origin main
```

### 4. 버전 태그 생성
```bash
# 개별 모듈 태그
git tag -a modules/ecs-service/v1.0.0 -m "Release ECS service module v1.0.0

- Initial release
- ECS service creation
- Auto scaling support
- Load balancer integration
"

# 태그 푸시
git push origin modules/ecs-service/v1.0.0
```

### 5. GitHub Release 생성
```bash
# GitHub에서 Release 생성
# Tag: modules/ecs-service/v1.0.0
# Title: ECS Service Module v1.0.0
# Description: CHANGELOG 내용 복사
```

## 버전 참조 방법

### 로컬 개발
```hcl
module "ecs_service" {
  source = "../../modules/ecs-service"
  # ...
}
```

### Git 태그 참조 (프로덕션)
```hcl
module "ecs_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=modules/ecs-service/v1.0.0"
  # ...
}
```

### 버전 범위 지정 (Terraform 1.5+)
```hcl
module "ecs_service" {
  source  = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service"
  version = "~> 1.0"  # 1.0.x 버전 사용
  # ...
}
```

## 버전 호환성 가이드

### Major 버전 업그레이드
```hcl
# v1.x.x → v2.x.x 업그레이드
# 1. CHANGELOG 확인하여 Breaking Changes 파악
# 2. 마이그레이션 가이드 참조
# 3. 코드 수정 (필수 변수 추가, 타입 변경 등)
# 4. terraform plan으로 영향 범위 확인
# 5. 스테이징 환경에서 먼저 테스트
# 6. 프로덕션 적용
```

### Minor/Patch 버전 업그레이드
```hcl
# v1.0.x → v1.1.x 또는 v1.0.0 → v1.0.1
# 1. CHANGELOG 확인
# 2. 버전 업데이트
# 3. terraform plan으로 변경 사항 확인
# 4. 적용
```

## CHANGELOG 연동

모든 버전 릴리스는 CHANGELOG.md에 기록되어야 합니다.

### CHANGELOG 형식
```markdown
# Changelog

## [1.1.0] - 2025-10-14

### Added
- ECS 컨테이너 헬스체크 설정 추가
- Auto Scaling 정책 커스터마이징 지원

### Changed
- 기본 CPU 임계값 70%에서 80%로 변경 (호환)

### Fixed
- 태그 병합 버그 수정

## [1.0.0] - 2025-10-10

### Added
- Initial release
- ECS service 생성
- Auto scaling 지원
```

자세한 내용: [CHANGELOG_TEMPLATE.md](./CHANGELOG_TEMPLATE.md)

## Pre-release 버전

개발 중이거나 테스트 단계의 버전:

```
v1.0.0-alpha.1    # 알파 버전
v1.0.0-beta.1     # 베타 버전
v1.0.0-rc.1       # Release Candidate
```

**태그 예시:**
```bash
modules/ecs-service/v1.0.0-beta.1
```

## 버전 관리 모범 사례

### ✅ 권장사항

1. **명확한 CHANGELOG**: 모든 변경 사항을 명확히 기록
2. **Breaking Changes 명시**: Major 버전 업그레이드 시 마이그레이션 가이드 제공
3. **태그 메시지**: 간략한 릴리스 노트 포함
4. **하위 호환성 유지**: 가능한 한 하위 호환성 유지
5. **문서 동기화**: 버전과 문서를 동기화

### ❌ 피해야 할 사항

1. **태그 삭제**: 한번 푸시된 태그는 삭제하지 않음
2. **태그 재사용**: 동일한 태그명 재사용 금지
3. **Breaking Changes 숨기기**: Major 버전 아닌데 Breaking Changes 포함
4. **문서 누락**: CHANGELOG 업데이트 없이 버전 태그
5. **테스트 생략**: 충분한 테스트 없이 버전 릴리스

## 버전 확인 명령어

### 로컬 태그 확인
```bash
# 모든 모듈 태그 확인
git tag -l "modules/*"

# 특정 모듈 태그 확인
git tag -l "modules/ecs-service/*"

# 태그 상세 정보
git show modules/ecs-service/v1.0.0
```

### 원격 태그 확인
```bash
# 원격 태그 목록
git ls-remote --tags origin

# 특정 모듈의 최신 버전 확인
git ls-remote --tags origin | grep "modules/ecs-service"
```

## 버전 롤백

### 태그 기반 롤백
```hcl
# 이전 버전으로 롤백
module "ecs_service" {
  source = "git::https://github.com/ryuqqq/infrastructure.git//terraform/modules/ecs-service?ref=modules/ecs-service/v1.0.0"
  # ...
}
```

### 문제 발생 시
1. 문제가 있는 버전 사용 중단 (새 태그는 삭제하지 않음)
2. 버그 수정 버전 릴리스 (Patch 또는 Minor)
3. CHANGELOG에 문제 및 해결 방법 기록

## Epic 4 버전 계획

### Phase 1: Initial Modules (v1.0.0)
```
modules/common-tags/v1.0.0
modules/cloudwatch-log-group/v1.0.0
modules/ecs-service/v1.0.0
modules/rds-instance/v1.0.0
modules/alb/v1.0.0
modules/iam-role/v1.0.0
modules/security-group/v1.0.0
```

### Phase 2: First Bundle Release
```
modules/v1.0.0  # 모든 모듈의 첫 번째 공식 릴리스
```

## 관련 문서

- [모듈 디렉터리 구조](./MODULES_DIRECTORY_STRUCTURE.md)
- [CHANGELOG 템플릿](./CHANGELOG_TEMPLATE.md)
- [모듈 README 템플릿](./MODULE_TEMPLATE.md)
- [Semantic Versioning 2.0.0](https://semver.org/)

## 문의

- **문의**: Infrastructure Team
