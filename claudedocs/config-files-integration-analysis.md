# 설정 파일 및 통합 분석 보고서

Policies, Scripts, 설정 파일들 간의 연관성과 실제 사용 여부를 종합 분석한 문서입니다.

---

## 📝 업데이트 이력

### 2025-11-21: 설정 파일 정리 완료
- ✅ `.tflint.hcl` 삭제 완료 (kebab-case 충돌 해결)
- ✅ `.pre-commit-config.yaml` 삭제 완료 (혼란 제거)
- ✅ 문서 참조 업데이트 완료:
  - `docs/blog/04-automated-validation-pipeline.md` - scripts/hooks 사용 명시
  - `docs/governance/CHECKOV_POLICY_GUIDE.md` - Git Hooks 통합 설명 개선

**현재 상태**: 프로젝트는 `scripts/hooks/` 디렉토리의 Git hooks를 공식 방식으로 사용합니다.

---

## 📋 목차

- [개요](#개요)
- [설정 파일 목록](#설정-파일-목록)
- [Policies와 Scripts 연관성](#policies와-scripts-연관성)
- [3가지 검증 레이어 통합](#3가지-검증-레이어-통합)
- [각 설정 파일 상세 분석](#각-설정-파일-상세-분석)
- [통합 워크플로우](#통합-워크플로우)
- [문제점 및 개선사항](#문제점-및-개선사항)

---

## 개요

Infrastructure 프로젝트는 **다층 거버넌스 검증** 전략을 사용하여 인프라 코드의 품질과 보안을 보장합니다.

### 검증 도구 및 설정 파일

| 도구 | 설정 파일 | 역할 | 실제 사용 |
|------|----------|------|----------|
| **Conftest** | `conftest.toml` | OPA 정책 검증 | ✅ 3개 레이어 모두 |
| **Checkov** | `.checkov.yml` | 컴플라이언스 스캔 | ✅ GitHub Actions |
| **tfsec** | `.tfsec/config.yml` | 보안 스캔 | ✅ GitHub Actions |
| **TFLint** | ~~`.tflint.hcl`~~ | Terraform lint | 🗑️ **삭제됨** (kebab-case 충돌) |
| **pre-commit** | ~~`.pre-commit-config.yaml`~~ | Git hooks 관리 | 🗑️ **삭제됨** (scripts/hooks 사용) |
| **Infracost** | `.infracost.yml` | 비용 분석 | ✅ GitHub Actions |

---

## 설정 파일 목록

### 1. **conftest.toml** ⭐⭐⭐

**위치**: 프로젝트 루트

**역할**: OPA (Open Policy Agent) 정책 검증 설정

**설정 내용**:
```toml
policy = ["policies"]           # policies/ 디렉토리의 정책 로드
namespace = "terraform"         # Terraform 네임스페이스 사용
input = "json"                  # JSON 입력 (terraform show -json)
fail_on_warn = false            # 경고는 실패로 간주하지 않음
output = "stdout"               # 표준 출력
combine = true                  # 모든 정책 결과 통합
color = true                    # 색상 출력
```

**실제 사용**:
- ✅ **Pre-commit hook**: `scripts/hooks/pre-commit:143` - 커밋 전 검증
- ✅ **Atlantis**: `atlantis.yaml:163` - PR plan 검증
- ✅ **GitHub Actions**: `terraform-plan.yml:113,177` - CI/CD 검증
- ✅ **로컬 스크립트**: `scripts/policy/run-conftest.sh` - 수동 검증

**검증하는 정책**:
- `policies/tagging/` - 7개 필수 태그
- `policies/naming/` - kebab-case 네이밍 규약
- `policies/security_groups/` - SSH/RDP 공개 노출 방지
- `policies/public_resources/` - RDS/S3 공개 접근 차단

---

### 2. **.checkov.yml** ⭐⭐⭐

**위치**: 프로젝트 루트

**역할**: Checkov 컴플라이언스 및 보안 정책 검증

**설정 내용**:
- **Framework**: Terraform
- **Directory**: `terraform/atlantis`, `terraform/logging`, `terraform/monitoring` 등
- **Skip Checks**: 58개 (개발 환경 최적화 및 false positive)
  - **비용 최적화**: CloudWatch 1년 보존, Multi-AZ, Performance Insights 등
  - **개발 유연성**: Deletion protection, Versioning, 암호화 키 등
  - **False Positive**: ALB HTTPS 리다이렉션 (동적 블록 파싱 버그)

**실제 사용**:
- ✅ **GitHub Actions**: `infra-checks.yml:136-142` - CI/CD 검증
- ✅ **스크립트**: `scripts/validators/check-checkov.sh` 참조
- ❌ **Pre-commit hook**: 속도 이슈로 제외
- ❌ **Atlantis**: 속도 이슈로 제외

**검증 범위**:
- CIS AWS Foundations Benchmark
- PCI-DSS, HIPAA, ISO27001 프레임워크
- 보안, 암호화, IAM, 네트워크 설정

---

### 3. **.tfsec/config.yml** ⭐⭐⭐

**위치**: `.tfsec/config.yml`

**역할**: tfsec 보안 스캔 설정

**설정 내용**:
```yaml
minimum_severity: MEDIUM        # MEDIUM 이상 보고
severity_overrides:
  - aws-s3-encryption-customer-key: CRITICAL
  - aws-rds-encrypt-instance-storage-data: CRITICAL
  - aws-s3-block-public-acls: CRITICAL
include:
  - terraform/atlantis/**
  - terraform/logging/**
  - terraform/monitoring/**
  - terraform/modules/**
soft_fail: false                # 실패 시 CI/CD 실패
```

**실제 사용**:
- ✅ **GitHub Actions**: `infra-checks.yml:128-134` - CI/CD 검증
- ✅ **스크립트**: `scripts/validators/check-tfsec.sh` - `--config-file .tfsec/config.yml`
- ❌ **Pre-commit hook**: 속도 이슈로 제외
- ❌ **Atlantis**: 속도 이슈로 제외

**검증 범위**:
- AWS 리소스 보안 베스트 프랙티스
- 암호화, 공개 액세스, IAM 정책
- S3, RDS, ECR, EBS 등

---

### 4. **.tflint.hcl** ⚠️

**위치**: 프로젝트 루트

**역할**: Terraform 린트 및 코드 품질 검증

**설정 내용**:
```hcl
plugin "aws" {
  enabled = true
  version = "0.30.0"
}

# Terraform 네이밍 규약
rule "terraform_naming_convention" {
  enabled = true
  variable { format = "snake_case" }
  resource { format = "snake_case" }  # ⚠️ kebab-case와 충돌
}

# AWS 필수 태그
rule "aws_resource_missing_tags" {
  enabled = true
  tags = ["Environment", "Service", "Team", "Owner", "CostCenter", "ManagedBy", "Project"]
}
```

**실제 사용**:
- ⚠️ **Pre-commit hook**: `.pre-commit-config.yaml:24-28` 참조
  - `terraform_tflint` hook으로 설정되어 있음
  - 하지만 **실제 pre-commit hook 파일**(`scripts/hooks/pre-commit`)에는 **없음**
- ❌ **Atlantis**: 사용 안 함
- ❌ **GitHub Actions**: 사용 안 함

**문제점**:
1. **네이밍 충돌**: TFLint는 `snake_case`, 프로젝트 표준은 `kebab-case`
2. **중복 검증**: 태그 검증이 `scripts/validators/check-tags.sh`와 중복
3. **설치 누락**: `.pre-commit-config.yaml`에 정의되어 있으나 실제 hook에는 없음

---

### 5. **.pre-commit-config.yaml** ⚠️⚠️

**위치**: 프로젝트 루트

**역할**: Pre-commit 프레임워크 설정 (Git hooks 관리)

**설정 내용**:
```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    hooks:
      - terraform_fmt
      - terraform_validate
      - terraform_tflint        # ⚠️ 실제 hook에 없음
      - terraform_docs          # ⚠️ 실제 hook에 없음

  - repo: local
    hooks:
      - check-tags              # scripts/validators/check-tags.sh
      - check-encryption        # scripts/validators/check-encryption.sh
      - check-naming            # scripts/validators/check-naming.sh
      - validate-terraform-file # scripts/validators/validate-terraform-file.sh

  - repo: https://github.com/gitleaks/gitleaks
    hooks:
      - gitleaks                # 민감 정보 스캔
```

**실제 사용 상태**:
- ⚠️⚠️ **설치 필요**: `pre-commit install` 명령으로 수동 설치 필요
- ⚠️ **현재 프로젝트는 사용 안 함**: 대신 `scripts/hooks/pre-commit` 직접 사용
- 🔀 **두 가지 방식 혼재**:
  - **방식 1**: `.pre-commit-config.yaml` + `pre-commit install`
  - **방식 2**: `scripts/hooks/pre-commit` + `scripts/setup-hooks.sh` (현재 사용 중)

**문제점**:
1. **혼란**: 두 가지 hook 설정 방식이 공존
2. **불일치**: `.pre-commit-config.yaml`의 hook과 `scripts/hooks/pre-commit`의 hook이 다름
3. **문서 부족**: 어느 방식을 사용해야 하는지 명확하지 않음

---

### 6. **.infracost.yml** ⭐⭐

**위치**: 프로젝트 루트

**역할**: Infracost 비용 분석 설정

**실제 사용**:
- ✅ **GitHub Actions**: `infra-checks.yml` - 비용 영향 분석
- ⚠️ **임계값**: 10% 경고, 30% 차단

---

## Policies와 Scripts 연관성

### OPA Policies → Scripts 매핑

| Policy | 검증 스크립트 | 관계 |
|--------|-------------|------|
| `policies/tagging/` | `scripts/validators/check-tags.sh` | 🔀 **중복** (다른 방식) |
| `policies/naming/` | `scripts/validators/check-naming.sh` | 🔀 **중복** (다른 방식) |
| `policies/security_groups/` | - | ✅ OPA만 |
| `policies/public_resources/` | - | ✅ OPA만 |
| - | `scripts/validators/check-encryption.sh` | ✅ Scripts만 |

### 검증 방식 차이

#### 1. **태그 검증**

**OPA 방식** (`policies/tagging/required_tags.rego`):
```rego
# Terraform plan JSON 분석
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    missing := required_tags - {tag | resource.values.tags[tag]}
    count(missing) > 0
}
```

**Scripts 방식** (`scripts/validators/check-tags.sh`):
```bash
# Terraform 파일 직접 파싱
if echo "$resource_block" | grep -q "merge(local.required_tags)"; then
    echo "✓ uses required_tags pattern"
fi
```

**차이점**:
- **OPA**: Plan 결과 검증 (실제 적용될 값 확인)
- **Scripts**: 코드 패턴 검증 (`merge(local.required_tags)` 사용 여부)

---

#### 2. **네이밍 검증**

**OPA 방식** (`policies/naming/naming.rego`):
```rego
# Plan 결과의 실제 리소스 이름 검증
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    not regex.match(`^[a-z0-9][a-z0-9-]*[a-z0-9]$`, resource.name)
}
```

**Scripts 방식** (`scripts/validators/check-naming.sh`):
```bash
# Terraform 파일의 리소스 정의 검증
if [[ $resource_name =~ $KEBAB_CASE_PATTERN ]]; then
    echo "✓ kebab-case"
fi
```

**차이점**:
- **OPA**: Plan 결과 검증
- **Scripts**: Terraform 파일 검증

---

### 중복 vs 보완

| 항목 | OPA Policies | Scripts Validators | 관계 |
|------|-------------|-------------------|------|
| **타이밍** | Plan 생성 후 | 코드 작성 시점 | ⏱️ 보완 |
| **검증 대상** | Plan JSON | Terraform 코드 | 🎯 보완 |
| **속도** | 느림 (plan 필요) | 빠름 | ⚡ 보완 |
| **정확도** | 높음 (실제 값) | 낮음 (패턴 매칭) | 📊 보완 |
| **사용 위치** | 3개 레이어 | Pre-push hook | 🔀 중복/보완 |

**결론**: **중복이지만 보완적** - 각각 장점이 있어 함께 사용하는 것이 합리적

---

## 3가지 검증 레이어 통합

### Layer 1: Pre-commit Hook (1-2초)

**파일**: `scripts/hooks/pre-commit`

**실행 내용**:
```bash
1. Terraform fmt (자동 수정)
2. 민감 정보 스캔 (패턴 매칭)
3. Terraform validate
4. OPA 정책 검증 (Conftest) ✅
```

**사용 설정**:
- ✅ `conftest.toml` - OPA 정책 검증

**미사용 설정**:
- ❌ `.checkov.yml` - 속도 이슈
- ❌ `.tfsec/config.yml` - 속도 이슈
- ❌ `.tflint.hcl` - 설정되어 있으나 미사용

---

### Layer 2: Pre-push Hook (30초-1분)

**파일**: `scripts/hooks/pre-push`

**실행 내용**:
```bash
1. scripts/validators/check-tags.sh        # 필수 태그
2. scripts/validators/check-encryption.sh  # KMS 암호화
3. scripts/validators/check-naming.sh      # kebab-case
```

**사용 설정**:
- ❌ 어떤 설정 파일도 직접 참조하지 않음
- ✅ 스크립트 내부 로직으로 검증

---

### Layer 3: Atlantis (PR plan - 30초)

**파일**: `atlantis.yaml`

**실행 내용**:
```yaml
plan:
  steps:
    - init
    - plan
    - run: |
        terraform show -json $PLANFILE > tfplan.json
        conftest test tfplan.json --config ../../conftest.toml  # ✅
```

**사용 설정**:
- ✅ `conftest.toml` - OPA 정책 검증

**미사용 설정**:
- ❌ `.checkov.yml` - 속도 이슈
- ❌ `.tfsec/config.yml` - 속도 이슈
- ❌ `.tflint.hcl` - 미통합

---

### Layer 4: GitHub Actions (PR 생성 - 1-2분)

**파일**: `.github/workflows/terraform-plan.yml`, `infra-checks.yml`

**실행 내용**:
```yaml
1. Conftest 설치 및 실행         # ✅ conftest.toml
2. tfsec 보안 스캔               # ✅ .tfsec/config.yml
3. Checkov 컴플라이언스 스캔      # ✅ .checkov.yml
4. Infracost 비용 분석           # ✅ .infracost.yml
```

**사용 설정**:
- ✅ `conftest.toml` - OPA 정책 검증
- ✅ `.tfsec/config.yml` - 보안 스캔
- ✅ `.checkov.yml` - 컴플라이언스 스캔
- ✅ `.infracost.yml` - 비용 분석

**미사용 설정**:
- ❌ `.tflint.hcl` - 미통합
- ❌ `.pre-commit-config.yaml` - 로컬 전용

---

## 각 설정 파일 상세 분석

### 실제 사용 여부 요약

| 설정 파일 | Pre-commit | Pre-push | Atlantis | GitHub Actions | 실제 사용 |
|----------|-----------|---------|----------|---------------|----------|
| **conftest.toml** | ✅ | - | ✅ | ✅ | ⭐⭐⭐ 모든 레이어 |
| **.checkov.yml** | ❌ | ❌ | ❌ | ✅ | ⭐⭐ GitHub Actions만 |
| **.tfsec/config.yml** | ❌ | ❌ | ❌ | ✅ | ⭐⭐ GitHub Actions만 |
| **.tflint.hcl** | ⚠️ | ❌ | ❌ | ❌ | ⚠️ 설정만 존재 |
| **.pre-commit-config.yaml** | ⚠️ | ⚠️ | ❌ | ❌ | ⚠️ 사용 안 함 |
| **.infracost.yml** | ❌ | ❌ | ❌ | ✅ | ⭐⭐ GitHub Actions만 |

---

### conftest.toml ⭐⭐⭐ (가장 많이 사용)

**사용 위치**:
1. `scripts/hooks/pre-commit:143`
2. `atlantis.yaml:163`
3. `.github/workflows/terraform-plan.yml:113,177`
4. `scripts/policy/run-conftest.sh:113`

**검증 정책**:
- `policies/tagging/required_tags.rego` - 7개 필수 태그
- `policies/naming/naming.rego` - kebab-case 네이밍
- `policies/security_groups/security_groups.rego` - SSH/RDP 공개 노출
- `policies/public_resources/public_resources.rego` - RDS/S3 공개 접근

**특징**:
- ✅ **3개 레이어 모두 사용** (Pre-commit, Atlantis, GitHub Actions)
- ✅ **plan 기반 검증** (실제 적용될 값 확인)
- ✅ **빠른 피드백** (pre-commit: 1-2초)

---

### .checkov.yml ⭐⭐ (GitHub Actions만)

**사용 위치**:
1. `.github/workflows/infra-checks.yml:141` - `check-checkov.sh` 호출
2. `scripts/validators/check-checkov.sh:41` - `--config-file .checkov.yml`

**검증 범위**:
- 58개 skip-check (개발 환경 최적화)
- CIS, PCI-DSS, HIPAA, ISO27001 프레임워크
- 보안, 암호화, IAM, 네트워크, 컨테이너 레지스트리

**특징**:
- ❌ **Pre-commit/Atlantis 제외** (속도 이슈: ~1-2분 소요)
- ✅ **GitHub Actions만** (CI/CD에서 충분한 시간 확보)
- ⚠️ **Many skip-checks** (개발 환경 비용/유연성 우선)

---

### .tfsec/config.yml ⭐⭐ (GitHub Actions만)

**사용 위치**:
1. `.github/workflows/infra-checks.yml:134` - `check-tfsec.sh` 호출
2. `scripts/validators/check-tfsec.sh:37,172` - `--config-file .tfsec/config.yml`

**검증 범위**:
- MEDIUM 이상 보안 이슈
- 암호화, 공개 액세스, IAM 정책
- S3, RDS, ECR, EBS, ALB 보안

**특징**:
- ❌ **Pre-commit/Atlantis 제외** (속도 이슈)
- ✅ **GitHub Actions만**
- ✅ **심각도 기반 필터링** (CRITICAL > HIGH > MEDIUM)

---

### .tflint.hcl ⚠️ (설정만 존재, 미사용)

**문제점**:
1. **`.pre-commit-config.yaml`에 정의**되어 있음
2. **실제 `scripts/hooks/pre-commit`에 없음**
3. **GitHub Actions에도 없음**
4. **Atlantis에도 없음**

**네이밍 충돌**:
```hcl
resource { format = "snake_case" }  # TFLint 설정
```
vs
```bash
# 프로젝트 표준 (scripts/validators/check-naming.sh)
KEBAB_CASE_PATTERN='^[a-z0-9][a-z0-9-]*[a-z0-9]$'
```

**권장 조치**:
- ❌ **삭제 또는 수정** 필요
- 🔧 **네이밍 규약 통일**: `resource { format = "none" }` (검증 비활성화)
- 📝 **문서화**: 사용하지 않는다면 명시적으로 표시

---

### .pre-commit-config.yaml ⚠️⚠️ (혼란)

**현재 상태**:
- 📁 **파일 존재**: `.pre-commit-config.yaml`
- ❌ **설치 안 됨**: `pre-commit install` 실행 필요
- 🔀 **대체 방식 사용**: `scripts/hooks/pre-commit` + `setup-hooks.sh`

**두 가지 방식 비교**:

| 항목 | `.pre-commit-config.yaml` | `scripts/hooks/` |
|------|---------------------------|------------------|
| **관리 방식** | Pre-commit 프레임워크 | 직접 Bash 스크립트 |
| **설치** | `pre-commit install` | `./scripts/setup-hooks.sh` |
| **의존성** | pre-commit Python 패키지 | Bash, Terraform, Conftest |
| **유연성** | 제한적 (YAML 설정) | 높음 (Bash 로직) |
| **현재 사용** | ❌ 미사용 | ✅ 사용 중 |

**권장 조치**:
1. **방식 통일**: 둘 중 하나 선택
   - **Option A**: `.pre-commit-config.yaml` + `pre-commit install` (표준 방식)
   - **Option B**: `scripts/hooks/` 직접 관리 (현재 방식, 유연함)
2. **문서화**: README에 명확히 표시
3. **불필요한 파일 삭제**: 사용하지 않는 방식의 파일 제거

---

## 통합 워크플로우

### 전체 검증 흐름

```
1. 로컬 개발 (개발자)
   │
   ├─► Pre-commit (1-2초)
   │   ├─ Terraform fmt
   │   ├─ 민감 정보 스캔
   │   ├─ Terraform validate
   │   └─ OPA 정책 검증 (conftest.toml)
   │
   ├─► Pre-push (30초-1분)
   │   ├─ check-tags.sh
   │   ├─ check-encryption.sh
   │   └─ check-naming.sh
   │
   └─► git push
       │
       ▼
2. Atlantis (PR plan - 30초)
   │
   ├─ terraform init
   ├─ terraform plan
   └─ OPA 정책 검증 (conftest.toml)
   │
   └─► PR 코멘트
       │
       ▼
3. GitHub Actions (PR 생성 - 1-2분)
   │
   ├─ OPA 정책 검증 (conftest.toml)
   ├─ tfsec 보안 스캔 (.tfsec/config.yml)
   ├─ Checkov 컴플라이언스 (.checkov.yml)
   └─ Infracost 비용 분석 (.infracost.yml)
   │
   └─► PR 코멘트
       │
       ▼
4. Merge & Apply
```

---

### 각 레이어별 사용 설정

```yaml
Pre-commit Hook:
  사용:
    - conftest.toml (OPA)
  미사용:
    - .checkov.yml (속도)
    - .tfsec/config.yml (속도)
    - .tflint.hcl (미통합)

Pre-push Hook:
  사용:
    - 없음 (스크립트 내부 로직)
  미사용:
    - 모든 설정 파일

Atlantis:
  사용:
    - conftest.toml (OPA)
  미사용:
    - .checkov.yml (속도)
    - .tfsec/config.yml (속도)
    - .tflint.hcl (미통합)

GitHub Actions:
  사용:
    - conftest.toml (OPA)
    - .tfsec/config.yml (보안)
    - .checkov.yml (컴플라이언스)
    - .infracost.yml (비용)
  미사용:
    - .tflint.hcl (미통합)
    - .pre-commit-config.yaml (로컬 전용)
```

---

## 문제점 및 개선사항

### ✅ 해결된 Critical Issues (2025-11-21)

#### 1. ~~**.tflint.hcl 네이밍 충돌**~~ ✅ **해결됨**

**문제**:
```hcl
# .tflint.hcl
resource { format = "snake_case" }  # 프로젝트 kebab-case 표준과 충돌
```

**해결**: `.tflint.hcl` 파일 삭제 완료
- 프로젝트는 kebab-case를 표준으로 사용
- OPA 정책 (`policies/naming/`)과 Scripts (`check-naming.sh`)로 네이밍 검증
- TFLint의 kebab-case 미지원으로 삭제 결정

---

#### 2. ~~**Pre-commit 설정 혼란**~~ ✅ **해결됨**

**문제**: 두 가지 hook 방식 공존으로 혼란
- `.pre-commit-config.yaml` (파일 존재, 미사용)
- `scripts/hooks/pre-commit` (실제 사용 중)

**해결**: `.pre-commit-config.yaml` 파일 삭제 완료
- **공식 방식**: `scripts/hooks/` 디렉토리의 Git hooks 사용
- **설치 방법**: `./scripts/setup-hooks.sh` 실행
- **문서 업데이트**: 모든 가이드에서 scripts/hooks 사용 명시

---

### 🟡 Medium Issues

#### 3. **중복 검증 (OPA vs Scripts)**

**문제**: 태그/네이밍 검증이 중복
- `policies/tagging/` + `scripts/validators/check-tags.sh`
- `policies/naming/` + `scripts/validators/check-naming.sh`

**차이점**:
| | OPA | Scripts |
|---|-----|---------|
| **타이밍** | Plan 후 | 코드 작성 시 |
| **정확도** | 높음 (실제 값) | 낮음 (패턴) |
| **속도** | 느림 | 빠름 |

**권장 조치**: **유지** (보완적 관계, 각각 장점 있음)

---

#### 4. **TFLint 미통합** ⚠️

**문제**: `.tflint.hcl`이 어디서도 사용되지 않음

**해결 방법**:

**Option A**: 통합
```yaml
# .pre-commit-config.yaml
- id: terraform_tflint
```
또는
```bash
# scripts/hooks/pre-commit
tflint --config .tflint.hcl
```

**Option B**: 삭제
```bash
rm .tflint.hcl
```

**권장 조치**: **Option B** (삭제) - 네이밍 충돌 및 중복 검증 문제

---

### 🟢 Low Priority

#### 5. **문서화 부족**

**문제**: 각 설정 파일의 사용 여부가 명확하지 않음

**해결 방법**:
- ✅ `scripts/README.md` 작성 완료
- 📝 `policies/README.md` 업데이트 필요
- 📝 루트 README에 설정 파일 섹션 추가

---

## 권장 조치 우선순위

### 🔴 High Priority (즉시 조치)

1. **네이밍 충돌 해결**
   - [ ] `.tflint.hcl` 삭제 또는 네이밍 검증 비활성화
   - [ ] 문서화: "TFLint 사용 안 함" 명시

2. **Pre-commit 설정 정리**
   - [ ] `.pre-commit-config.yaml` 삭제 (Option B)
   - [ ] README에 "pre-commit 프레임워크 미사용" 명시
   - [ ] `scripts/setup-hooks.sh`가 공식 설치 방법임을 문서화

### 🟡 Medium Priority (1주 내)

3. **설정 파일 문서화**
   - [ ] 루트 README에 설정 파일 섹션 추가
   - [ ] 각 설정 파일 상단에 사용 여부 명시
   - [ ] `claudedocs/config-files-integration-analysis.md` (본 문서) 참조 추가

4. **OPA vs Scripts 중복 검증 명확화**
   - [ ] `policies/README.md`에 Scripts와의 차이점 설명
   - [ ] 언제 OPA를, 언제 Scripts를 사용하는지 가이드

### 🟢 Low Priority (개선 제안)

5. **통합 최적화**
   - [ ] Checkov/tfsec를 Atlantis에도 통합 고려 (성능 허용 시)
   - [ ] Pre-push hook을 OPA로 통합 고려

---

## 요약

### ✅ 잘 작동하는 것

1. **conftest.toml** - 3개 레이어 모두 완벽 통합 ⭐⭐⭐
2. **scripts/hooks/pre-commit** - 빠른 피드백, 잘 작동 ⭐⭐⭐
3. **GitHub Actions 통합** - 4개 도구 모두 통합 ⭐⭐⭐

### ⚠️ 문제가 있는 것

1. **.tflint.hcl** - 네이밍 충돌, 미사용 ⚠️⚠️
2. **.pre-commit-config.yaml** - 두 가지 방식 혼재 ⚠️⚠️
3. **OPA vs Scripts** - 중복 검증 (보완적이지만 혼란) ⚠️

### 🎯 핵심 Action Items

1. `.tflint.hcl` 삭제 또는 비활성화
2. `.pre-commit-config.yaml` 삭제 (또는 명확한 방식 선택)
3. 설정 파일 사용 여부 문서화
4. OPA policies와 Scripts validators의 차이점 명확화

---

**Last Updated**: 2025-11-21
