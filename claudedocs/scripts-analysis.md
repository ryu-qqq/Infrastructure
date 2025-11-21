# Scripts 디렉토리 분석 보고서

Infrastructure 프로젝트의 scripts 디렉토리에 있는 모든 스크립트의 역할과 실제 사용 여부를 분석한 문서입니다.

## 📋 디렉토리 구조

```
scripts/
├── atlantis/              # Atlantis 서버 운영 스크립트
├── validators/            # Terraform 거버넌스 검증 도구
├── policy/                # OPA 정책 검증 도구
├── modules/               # 모듈 관리 도구
├── shared/                # 공유 인프라 관리
├── hooks/                 # Git hooks
├── build-and-push.sh      # Docker 빌드/배포
├── setup-hooks.sh         # Git hooks 설치
├── check-terraform-docs.sh
├── generate-terraform-docs.sh
└── import-existing-resources.sh
```

---

## 🔧 핵심 스크립트 (실제 사용 중)

### 1. **setup-hooks.sh** ⭐
**역할**: Git hooks 자동 설치 및 환경 검증

**주요 기능**:
- `scripts/hooks/` 디렉토리의 hook 파일을 `.git/hooks/`로 복사
- 필수 도구 검증 (terraform, git, bash)
- 선택적 도구 확인 (tfsec, checkov, conftest)
- 기존 hook 자동 백업

**실제 사용**:
- ✅ **사용 중**: 프로젝트 초기 설정 시 필수
- ✅ **문서화**: README_NEW.md에 언급됨

**실행 예시**:
```bash
./scripts/setup-hooks.sh

# 출력:
# ✓ terraform 1.5.0
# ✓ git 2.40.0
# ✓ bash 5.2.0
# ✓ tfsec v1.28.0
# ✓ Installed: pre-commit
# ✓ Installed: pre-push
```

---

### 2. **build-and-push.sh** ⭐
**역할**: Atlantis Docker 이미지 빌드 및 ECR 푸시

**주요 기능**:
- Atlantis Docker 이미지 빌드 (Conftest 포함)
- ECR 로그인 및 이미지 푸시
- 3가지 태그 전략:
  - `v0.28.1-20240110-123456` (버전+타임스탬프)
  - `v0.28.1-abc123` (버전+git commit)
  - `latest` (커스텀 태그)

**환경 변수**:
```bash
AWS_REGION=ap-northeast-2
ATLANTIS_VERSION=v0.28.1
CUSTOM_TAG=latest
```

**실제 사용**:
- ✅ **사용 중**: Atlantis 배포 시 필수
- ✅ **문서화**: OPA integration guide에 언급
- ⚠️ **수동 실행**: CI/CD에 통합되지 않음

**실행 예시**:
```bash
./scripts/build-and-push.sh

# 또는 커스텀 버전/태그:
ATLANTIS_VERSION=v0.30.0 CUSTOM_TAG=prod ./scripts/build-and-push.sh
```

---

## 🛡️ Validators (거버넌스 검증 도구)

### 3. **validators/check-tags.sh** ⭐⭐⭐
**역할**: Terraform 리소스의 필수 태그 검증

**검증 항목**:
- 7개 필수 태그: `Environment`, `Service`, `Team`, `Owner`, `CostCenter`, `ManagedBy`, `Project`
- `merge(local.required_tags)` 패턴 검증
- Skip 타입: `aws_kms_alias`, `random_*`, `aws_s3_bucket_*` (서브 리소스)

**실제 사용**:
- ✅ **Pre-push hook**: `scripts/hooks/pre-push`에서 호출
- ✅ **GitHub Actions**: `.github/workflows/infra-checks.yml`에서 호출 (간접적)
- ✅ **문서화**: policies/README.md에 설명

**실행 예시**:
```bash
./scripts/validators/check-tags.sh terraform/monitoring

# 출력:
# ✓ aws_ecr_repository.monitoring uses required_tags pattern
# ✗ Error: Missing required tags
#   Resource: aws_cloudwatch_log_group.app
#   Missing: CostCenter, Owner
```

---

### 4. **validators/check-encryption.sh** ⭐⭐⭐
**역할**: KMS 암호화 검증 (AES256 사용 금지)

**검증 대상**:
- **ECR**: `encryption_type = "KMS"` + `kms_key` 설정
- **S3**: `sse_algorithm = "aws:kms"`
- **RDS**: `storage_encrypted = true` + `kms_key_id`
- **EBS**: `encrypted = true` + `kms_key_id`

**실제 사용**:
- ✅ **Pre-push hook**: `scripts/hooks/pre-push`에서 호출
- ✅ **GitHub Actions**: `.github/workflows/infra-checks.yml`에서 호출 (간접적)
- ✅ **문서화**: governance 문서에 설명

**실행 예시**:
```bash
./scripts/validators/check-encryption.sh terraform/atlantis

# 출력:
# ✓ aws_ecr_repository.atlantis uses KMS encryption
# ✗ Error: ECR using AES256 instead of KMS
```

---

### 5. **validators/check-naming.sh** ⭐⭐⭐
**역할**: Terraform 네이밍 규약 검증

**규칙**:
- **Resources**: kebab-case (예: `my-resource-123`)
- **Variables/Outputs/Locals**: snake_case (예: `my_variable_123`)

**Skip 타입**:
- `null_resource`, `terraform_data`, `time_sleep`, `random_*`, `data`

**실제 사용**:
- ✅ **Pre-push hook**: `scripts/hooks/pre-push`에서 호출
- ✅ **GitHub Actions**: `.github/workflows/infra-checks.yml`에서 호출 (간접적)
- ✅ **문서화**: governance 문서에 설명

**실행 예시**:
```bash
./scripts/validators/check-naming.sh terraform/network

# 출력:
# ✓ aws_vpc.prod-server-vpc (kebab-case)
# ✗ Error: Invalid resource name
#   Resource: aws_subnet.ProdSubnet1
#   Expected: kebab-case
```

---

### 6. **validators/check-tfsec.sh** ⭐⭐
**역할**: tfsec 보안 스캔 실행

**실제 사용**:
- ✅ **GitHub Actions**: `.github/workflows/infra-checks.yml`에서 직접 호출
- ⚠️ **Pre-push hook 미사용**: 속도 이슈로 제외
- ✅ **문서화**: 보안 가이드에 언급

---

### 7. **validators/check-checkov.sh** ⭐⭐
**역할**: Checkov 컴플라이언스 스캔 실행

**실제 사용**:
- ✅ **GitHub Actions**: `.github/workflows/infra-checks.yml`에서 직접 호출
- ⚠️ **Pre-push hook 미사용**: 속도 이슈로 제외
- ✅ **문서화**: 보안 가이드에 언급

---

### 8. **validators/validate-terraform-file.sh** ⭐
**역할**: 단일 파일 검증 (Claude Code hook용)

**검증 내용**:
- Terraform fmt
- Terraform validate (파일이 속한 디렉토리 전체)
- 민감 정보 스캔
- 기본적인 문법 검증

**실제 사용**:
- ✅ **Claude Code hooks**: `.claude/hooks.json`에서 참조
- ✅ **Write/Edit 후 자동 실행**

**실행 예시**:
```bash
./scripts/validators/validate-terraform-file.sh terraform/monitoring/main.tf

# 출력:
# ✓ Terraform format: OK
# ✓ Terraform validate: OK
# ✓ No sensitive data found
```

---

### 9. **validators/check-secrets-rotation.sh** ⚠️
**역할**: Secrets Manager 비밀 로테이션 검증

**실제 사용**:
- ❌ **미사용**: 현재 workflow/hook에서 호출되지 않음
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

### 10. **validators/validate-modules.sh** ⚠️
**역할**: Terraform 모듈 검증

**실제 사용**:
- ❌ **미사용**: 현재 workflow/hook에서 호출되지 않음
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

## 📜 Policy Validation

### 11. **policy/run-conftest.sh** ⭐⭐
**역할**: OPA 정책 검증 (Conftest) 실행

**주요 기능**:
- OPA 정책 단위 테스트 실행
- Terraform plan을 JSON으로 변환
- Conftest로 정책 검증
- 4개 정책 카테고리:
  - `policies/naming`
  - `policies/tagging`
  - `policies/security_groups`
  - `policies/public_resources`

**실제 사용**:
- ⚠️ **수동 실행**: CI/CD에 통합되지 않음 (GitHub Actions는 inline conftest 사용)
- ✅ **로컬 테스트용**: 개발자가 로컬에서 정책 테스트 시 사용
- ✅ **문서화**: OPA policy guide에 설명

**실행 예시**:
```bash
./scripts/policy/run-conftest.sh terraform/

# 출력:
# Testing policies/naming...
# ✅ policies/naming tests passed
# Testing policies/tagging...
# ✅ policies/tagging tests passed
#
# 📦 Module: terraform/monitoring
# ✅ Policy validation passed
```

---

## 🚀 Atlantis 운영 스크립트

### 12. **atlantis/check-atlantis-health.sh** ⭐⭐
**역할**: Atlantis 서버 헬스체크

**기능**:
- ECS Service 상태 확인
- Running Tasks 상태 확인
- ALB Target Health 확인
- 최근 에러 로그 조회 (최근 10분)
- 최근 활동 요약 (webhook, plan, apply 카운트)

**실제 사용**:
- ✅ **운영 도구**: Atlantis 서버 모니터링 시 사용
- ✅ **문서화**: atlantis-setup-guide.md에 언급

**실행 예시**:
```bash
./scripts/atlantis/check-atlantis-health.sh prod

# 출력:
# 📋 ECS Service Status
# atlantis-prod | ACTIVE | 1 | 1 | PRIMARY
#
# 📦 Running Tasks
# RUNNING | HEALTHY
#
# 🎯 Target Health Status
# healthy
#
# ✅ 에러 로그가 없습니다.
```

---

### 13. **atlantis/monitor-atlantis-logs.sh** ⭐⭐
**역할**: Atlantis 로그 실시간 모니터링

**기능**:
- CloudWatch Logs 실시간 tail
- 필터링 옵션:
  - `error`: 에러 로그만
  - `FileFlow`: 특정 프로젝트 관련
  - 전체 로그

**실제 사용**:
- ✅ **운영 도구**: 디버깅 및 모니터링
- ✅ **문서화**: atlantis-setup-guide.md에 언급

**실행 예시**:
```bash
# 전체 로그
./scripts/atlantis/monitor-atlantis-logs.sh prod

# 에러만
./scripts/atlantis/monitor-atlantis-logs.sh prod error

# 특정 프로젝트
./scripts/atlantis/monitor-atlantis-logs.sh prod FileFlow
```

---

### 14. **atlantis/restart-atlantis.sh** ⭐
**역할**: Atlantis 서비스 재시작

**실제 사용**:
- ✅ **운영 도구**: 서비스 재시작 시 사용
- ⚠️ **문서 부족**: 사용법 문서화 필요

---

### 15. **atlantis/export-atlantis-logs.sh** ⚠️
**역할**: Atlantis 로그 내보내기

**실제 사용**:
- ⚠️ **사용 빈도 낮음**: 로그 백업/분석용
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

### 16. **atlantis/add-project.sh** ⚠️
**역할**: Atlantis에 새 프로젝트 추가

**실제 사용**:
- ❌ **미사용 추정**: `atlantis.yaml`을 직접 편집하는 방식 선호
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

### 17. **atlantis/deploy-config.sh** ⚠️
**역할**: Atlantis 설정 배포

**실제 사용**:
- ❌ **미사용 추정**: `build-and-push.sh` 사용
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

### 18. **atlantis/init-repo-atlantis.sh** ⚠️
**역할**: Atlantis 저장소 초기화

**실제 사용**:
- ❌ **미사용 추정**: 초기 설정 완료됨
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

## 🔧 모듈 및 공유 인프라 관리

### 19. **modules/module-manager.sh** ⚠️
**역할**: Terraform 모듈 관리 도구

**실제 사용**:
- ❌ **미사용**: 현재 workflow에서 호출 없음
- ⚠️ **문서 없음**: 사용법 문서화 필요
- 💡 **잠재적 가치**: 모듈 버전 관리, 업데이트 자동화 가능

---

### 20. **shared/shared-infra-manager.sh** ⚠️
**역할**: 공유 인프라 관리 도구

**실제 사용**:
- ❌ **미사용**: 현재 workflow에서 호출 없음
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

## 📚 문서화 도구

### 21. **check-terraform-docs.sh** ⚠️
**역할**: Terraform 문서 검증

**실제 사용**:
- ❌ **미사용**: workflow에서 호출 없음
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

### 22. **generate-terraform-docs.sh** ⚠️
**역할**: Terraform 문서 자동 생성

**실제 사용**:
- ❌ **미사용**: workflow에서 호출 없음
- ⚠️ **문서 없음**: terraform-docs 사용 여부 불명

---

### 23. **import-existing-resources.sh** ⚠️
**역할**: 기존 AWS 리소스를 Terraform으로 import

**실제 사용**:
- ❌ **미사용**: 일회성 마이그레이션 도구로 추정
- ⚠️ **문서 없음**: 사용법 문서화 필요

---

## 📊 Git Hooks

### 24. **hooks/pre-commit** ⭐⭐⭐
**역할**: 커밋 전 빠른 검증

**검증 항목**:
1. Terraform fmt (자동 수정)
2. 민감 정보 스캔 (패스워드, API 키 등)
3. Terraform validate
4. **OPA 정책 검증** (Conftest)

**실제 사용**:
- ✅ **사용 중**: `setup-hooks.sh`로 설치
- ✅ **문서화**: OPA integration guide에 설명
- ✅ **속도**: 1-2초 (매우 빠름)

**실행 시점**: `git commit` 실행 시 자동

---

### 25. **hooks/pre-push** ⭐⭐
**역할**: 푸시 전 종합 검증

**검증 항목**:
1. `check-tags.sh`
2. `check-encryption.sh`
3. `check-naming.sh`

**실제 사용**:
- ✅ **사용 중**: `setup-hooks.sh`로 설치
- ✅ **문서화**: governance 문서에 언급
- ⚠️ **속도**: 30초-1분 (상대적으로 느림)

**우회 방법**: `git push --no-verify` (긴급 상황에만 사용)

---

## 🎯 실제 사용 통합 워크플로우

### 로컬 개발 환경

```bash
# 1. 최초 설정
./scripts/setup-hooks.sh

# 2. 코드 작성
cd terraform/monitoring
terraform init
terraform fmt
terraform validate

# 3. 커밋 (pre-commit hook 자동 실행)
git add main.tf
git commit -m "Add monitoring resources"
# → fmt, secrets scan, validate, OPA policy 자동 검증

# 4. 푸시 (pre-push hook 자동 실행)
git push origin feature/monitoring
# → tags, encryption, naming 자동 검증
```

---

### CI/CD 파이프라인

**`.github/workflows/terraform-plan.yml`**:
```yaml
# 1. Conftest 설치
- name: Install Security Scanners
  run: |
    CONFTEST_VERSION=0.49.1
    curl -L "..." | tar xz
    sudo mv /tmp/conftest /usr/local/bin/

# 2. OPA 정책 검증 (각 모듈별)
- name: OPA Policy Validation - Monitoring
  run: conftest test tfplan-monitoring.json --config ../../conftest.toml
```

**`.github/workflows/infra-checks.yml`** (재사용 가능 워크플로우):
```yaml
# tfsec, checkov 등의 보안 스캔 실행
# validators 스크립트를 간접적으로 실행 (inline 방식)
```

---

### Atlantis 배포

```bash
# 1. Docker 이미지 빌드 및 푸시
./scripts/build-and-push.sh

# 2. ECS 서비스 업데이트 (자동 또는 수동)
cd terraform/atlantis
terraform apply

# 3. 헬스체크
./scripts/atlantis/check-atlantis-health.sh prod
```

---

### Atlantis 운영

```bash
# 실시간 로그 모니터링
./scripts/atlantis/monitor-atlantis-logs.sh prod

# 에러 로그만 확인
./scripts/atlantis/monitor-atlantis-logs.sh prod error

# 헬스체크
./scripts/atlantis/check-atlantis-health.sh prod

# 서비스 재시작 (필요 시)
./scripts/atlantis/restart-atlantis.sh prod
```

---

## 📈 사용 빈도 및 중요도

| 스크립트 | 사용 빈도 | 중요도 | 통합 상태 |
|---------|---------|--------|----------|
| `setup-hooks.sh` | 초기 1회 | ⭐⭐⭐ | ✅ 문서화 |
| `build-and-push.sh` | 배포 시 | ⭐⭐⭐ | ✅ 문서화 |
| `hooks/pre-commit` | 매 커밋 | ⭐⭐⭐ | ✅ Git hook |
| `hooks/pre-push` | 매 푸시 | ⭐⭐ | ✅ Git hook |
| `validators/check-tags.sh` | pre-push | ⭐⭐⭐ | ✅ Hook + Docs |
| `validators/check-encryption.sh` | pre-push | ⭐⭐⭐ | ✅ Hook + Docs |
| `validators/check-naming.sh` | pre-push | ⭐⭐⭐ | ✅ Hook + Docs |
| `validators/check-tfsec.sh` | CI/CD | ⭐⭐ | ✅ GitHub Actions |
| `validators/check-checkov.sh` | CI/CD | ⭐⭐ | ✅ GitHub Actions |
| `policy/run-conftest.sh` | 로컬 테스트 | ⭐⭐ | ✅ 문서화 |
| `atlantis/check-atlantis-health.sh` | 운영 | ⭐⭐ | ✅ 문서화 |
| `atlantis/monitor-atlantis-logs.sh` | 디버깅 | ⭐⭐ | ✅ 문서화 |
| `atlantis/restart-atlantis.sh` | 긴급 | ⭐ | ⚠️ 문서 부족 |
| `validators/validate-terraform-file.sh` | Claude hook | ⭐ | ✅ Claude hooks |
| 기타 validators | 미사용 | ⚠️ | ❌ 미통합 |
| 기타 atlantis | 미사용 | ⚠️ | ❌ 미통합 |
| modules/shared | 미사용 | ⚠️ | ❌ 미통합 |
| docs 관련 | 미사용 | ⚠️ | ❌ 미통합 |

---

## 🔍 개선 권장사항

### 1. 문서화 개선
- ❌ **미문서화 스크립트**: 9개
- 📝 **필요 작업**:
  - `atlantis/restart-atlantis.sh` 사용법 추가
  - `validators/check-secrets-rotation.sh` 용도 및 사용법
  - `validators/validate-modules.sh` 통합 방안
  - `modules/module-manager.sh` 활용 전략
  - `shared/shared-infra-manager.sh` 사용 시나리오

### 2. 미사용 스크립트 정리
- ⚠️ **검토 필요**:
  - `atlantis/add-project.sh`
  - `atlantis/deploy-config.sh`
  - `atlantis/init-repo-atlantis.sh`
  - `check-terraform-docs.sh`
  - `generate-terraform-docs.sh`
  - `import-existing-resources.sh`

**옵션**:
- 삭제 (사용하지 않는다면)
- 문서화 후 활용 (유용하다면)
- `scripts/deprecated/`로 이동

### 3. CI/CD 통합 개선
- ✅ **현재**: GitHub Actions inline으로 대부분 처리
- 💡 **제안**:
  - `scripts/ci/` 디렉토리 생성
  - CI/CD 전용 래퍼 스크립트 작성
  - 재사용 가능한 모듈화

### 4. 로컬 개발 편의성
- 💡 **제안**: `scripts/dev/` 디렉토리
  - `run-all-validators.sh`: 모든 검증 한번에
  - `quick-check.sh`: 빠른 검증만 (fmt, validate)
  - `full-check.sh`: 전체 검증 (validators + policies)

---

## 📝 요약

### ✅ 핵심 활용 스크립트 (반드시 이해 필요)
1. **setup-hooks.sh**: Git hooks 설치
2. **build-and-push.sh**: Atlantis 배포
3. **pre-commit**: 커밋 전 검증
4. **check-tags.sh**: 태그 검증
5. **check-encryption.sh**: KMS 암호화 검증
6. **check-naming.sh**: 네이밍 규약 검증
7. **run-conftest.sh**: OPA 정책 검증
8. **check-atlantis-health.sh**: Atlantis 모니터링
9. **monitor-atlantis-logs.sh**: 로그 모니터링

### ⚠️ 정리 필요
- 9개 스크립트 문서화 부족
- 6개 스크립트 사용 여부 불명확
- 일부 스크립트 deprecated 처리 권장

### 🎯 개선 우선순위
1. **High**: 미문서화 스크립트 문서 작성
2. **Medium**: 미사용 스크립트 정리 (삭제 또는 deprecated)
3. **Low**: CI/CD 통합 개선, 로컬 개발 도구 추가
