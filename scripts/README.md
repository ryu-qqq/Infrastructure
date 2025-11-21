# Scripts 디렉토리

Infrastructure 프로젝트의 자동화 스크립트 모음입니다.

## 📋 목차

- [빠른 시작](#빠른-시작)
- [핵심 스크립트](#핵심-스크립트)
- [Validators (거버넌스 검증)](#validators-거버넌스-검증)
- [Policy Validation (정책 검증)](#policy-validation-정책-검증)
- [Atlantis 운영](#atlantis-운영)
- [Git Hooks](#git-hooks)
- [기타 도구](#기타-도구)

---

## 빠른 시작

### 최초 설정 (한 번만 실행)

```bash
# Git hooks 설치
./scripts/setup-hooks.sh
```

### Atlantis 배포

```bash
# Docker 이미지 빌드 및 ECR 푸시
./scripts/build-and-push.sh
```

### Atlantis 모니터링

```bash
# 헬스체크
./scripts/atlantis/check-atlantis-health.sh prod

# 로그 모니터링
./scripts/atlantis/monitor-atlantis-logs.sh prod
```

---

## 핵심 스크립트

### `setup-hooks.sh` ⭐⭐⭐

**역할**: Git hooks 자동 설치 및 개발 환경 검증

**기능**:
- `hooks/` 디렉토리의 hook 파일을 `.git/hooks/`로 복사
- 필수 도구 검증 (terraform, git, bash)
- 선택적 도구 확인 (tfsec, checkov, conftest)

**사용법**:
```bash
./scripts/setup-hooks.sh
```

**설치되는 hooks**:
- `pre-commit`: 커밋 전 빠른 검증 (fmt, secrets scan, validate, OPA)
- `pre-push`: 푸시 전 거버넌스 검증 (tags, encryption, naming)

---

### `build-and-push.sh` ⭐⭐⭐

**역할**: Atlantis Docker 이미지 빌드 및 ECR 푸시

**기능**:
- Atlantis Docker 이미지 빌드 (Conftest 포함)
- ECR 로그인 및 이미지 푸시
- 3가지 태그 전략 적용

**사용법**:
```bash
# 기본 사용
./scripts/build-and-push.sh

# 커스텀 버전/태그
ATLANTIS_VERSION=v0.30.0 CUSTOM_TAG=prod ./scripts/build-and-push.sh
```

**환경 변수**:
- `AWS_REGION`: AWS 리전 (기본: ap-northeast-2)
- `AWS_ACCOUNT_ID`: AWS 계정 ID (자동 감지)
- `ATLANTIS_VERSION`: Atlantis 버전 (기본: v0.28.1)
- `CUSTOM_TAG`: 커스텀 태그 (기본: latest)

---

## Validators (거버넌스 검증)

### `validators/check-tags.sh` ⭐⭐⭐

**역할**: Terraform 리소스의 필수 태그 검증

**검증 항목**:
- 7개 필수 태그: `Environment`, `Service`, `Team`, `Owner`, `CostCenter`, `ManagedBy`, `Project`
- `merge(local.required_tags)` 패턴 사용 여부

**사용법**:
```bash
./scripts/validators/check-tags.sh [terraform_directory]

# 예시
./scripts/validators/check-tags.sh terraform/monitoring
```

**자동 실행**: `pre-push` hook에서 자동 실행

---

### `validators/check-encryption.sh` ⭐⭐⭐

**역할**: KMS 암호화 사용 검증 (AES256 사용 금지)

**검증 대상**:
- **ECR**: `encryption_type = "KMS"` + `kms_key`
- **S3**: `sse_algorithm = "aws:kms"`
- **RDS**: `storage_encrypted = true` + `kms_key_id`
- **EBS**: `encrypted = true` + `kms_key_id`

**사용법**:
```bash
./scripts/validators/check-encryption.sh [terraform_directory]

# 예시
./scripts/validators/check-encryption.sh terraform/atlantis
```

**자동 실행**: `pre-push` hook에서 자동 실행

---

### `validators/check-naming.sh` ⭐⭐⭐

**역할**: Terraform 네이밍 규약 검증

**규칙**:
- **Resources**: kebab-case (예: `my-resource-123`)
- **Variables/Outputs/Locals**: snake_case (예: `my_variable_123`)

**사용법**:
```bash
./scripts/validators/check-naming.sh [terraform_directory]

# 예시
./scripts/validators/check-naming.sh terraform/network
```

**자동 실행**: `pre-push` hook에서 자동 실행

---

### `validators/check-tfsec.sh` ⭐⭐

**역할**: tfsec 보안 스캔 실행

**사용법**:
```bash
./scripts/validators/check-tfsec.sh [terraform_directory]
```

**자동 실행**: GitHub Actions (`infra-checks.yml`)

---

### `validators/check-checkov.sh` ⭐⭐

**역할**: Checkov 컴플라이언스 스캔 실행

**사용법**:
```bash
./scripts/validators/check-checkov.sh [terraform_directory]
```

**자동 실행**: GitHub Actions (`infra-checks.yml`)

---

### `validators/validate-terraform-file.sh` ⭐

**역할**: 단일 Terraform 파일 검증 (Claude Code hook용)

**검증 내용**:
- Terraform fmt
- Terraform validate
- 민감 정보 스캔

**사용법**:
```bash
./scripts/validators/validate-terraform-file.sh <file.tf>

# 예시
./scripts/validators/validate-terraform-file.sh terraform/monitoring/main.tf
```

**자동 실행**: Claude Code `.claude/hooks.json`

---

### `validators/check-secrets-rotation.sh` ⚠️

**역할**: Secrets Manager 비밀 로테이션 검증

**상태**: 현재 미사용

---

### `validators/validate-modules.sh` ⚠️

**역할**: Terraform 모듈 검증

**상태**: 현재 미사용

---

## Policy Validation (정책 검증)

### `policy/run-conftest.sh` ⭐⭐

**역할**: OPA 정책 검증 (Conftest) 로컬 실행

**기능**:
- OPA 정책 단위 테스트 실행
- Terraform plan을 JSON으로 변환
- Conftest로 정책 검증
- 4개 정책 카테고리 검증:
  - `policies/naming`
  - `policies/tagging`
  - `policies/security_groups`
  - `policies/public_resources`

**사용법**:
```bash
./scripts/policy/run-conftest.sh [terraform_directory]

# 예시
./scripts/policy/run-conftest.sh terraform/
```

**참고**: CI/CD에서는 inline 방식으로 실행되므로, 이 스크립트는 주로 로컬 테스트용입니다.

---

## Atlantis 운영

### `atlantis/check-atlantis-health.sh` ⭐⭐

**역할**: Atlantis 서버 헬스체크

**확인 항목**:
- ECS Service 상태
- Running Tasks 상태
- ALB Target Health
- 최근 에러 로그 (최근 10분)
- 최근 활동 요약 (webhook, plan, apply 카운트)

**사용법**:
```bash
./scripts/atlantis/check-atlantis-health.sh [환경]

# 예시
./scripts/atlantis/check-atlantis-health.sh prod
```

---

### `atlantis/monitor-atlantis-logs.sh` ⭐⭐

**역할**: Atlantis 로그 실시간 모니터링

**기능**:
- CloudWatch Logs 실시간 tail
- 필터링 옵션 지원

**사용법**:
```bash
# 전체 로그
./scripts/atlantis/monitor-atlantis-logs.sh prod

# 에러 로그만
./scripts/atlantis/monitor-atlantis-logs.sh prod error

# 특정 프로젝트 관련
./scripts/atlantis/monitor-atlantis-logs.sh prod FileFlow
```

---

### `atlantis/restart-atlantis.sh` ⭐

**역할**: Atlantis ECS 서비스 재시작

**사용법**:
```bash
./scripts/atlantis/restart-atlantis.sh [환경]

# 예시
./scripts/atlantis/restart-atlantis.sh prod
```

---

### `atlantis/export-atlantis-logs.sh` ⚠️

**역할**: Atlantis 로그 내보내기 (로그 백업/분석용)

**상태**: 사용 빈도 낮음

---

### `atlantis/add-project.sh` ⚠️

**역할**: Atlantis에 새 프로젝트 추가

**상태**: 현재 미사용 (`atlantis.yaml` 직접 편집 선호)

---

### `atlantis/deploy-config.sh` ⚠️

**역할**: Atlantis 설정 배포

**상태**: 현재 미사용 (`build-and-push.sh` 사용)

---

### `atlantis/init-repo-atlantis.sh` ⚠️

**역할**: Atlantis 저장소 초기화

**상태**: 초기 설정 완료됨 (현재 미사용)

---

## Git Hooks

### `hooks/pre-commit` ⭐⭐⭐

**역할**: 커밋 전 빠른 검증 (1-2초)

**검증 항목**:
1. Terraform fmt (자동 수정)
2. 민감 정보 스캔 (패스워드, API 키 등)
3. Terraform validate
4. OPA 정책 검증 (Conftest)

**설치 방법**:
```bash
./scripts/setup-hooks.sh
```

**우회 방법** (긴급 상황에만):
```bash
git commit --no-verify -m "Emergency fix"
```

---

### `hooks/pre-push` ⭐⭐

**역할**: 푸시 전 거버넌스 검증 (30초-1분)

**검증 항목**:
1. `check-tags.sh` - 필수 태그 검증
2. `check-encryption.sh` - KMS 암호화 검증
3. `check-naming.sh` - 네이밍 규약 검증

**설치 방법**:
```bash
./scripts/setup-hooks.sh
```

**우회 방법** (긴급 상황에만):
```bash
git push --no-verify
```

---

## 기타 도구

### `modules/module-manager.sh` ⚠️

**역할**: Terraform 모듈 관리 도구

**상태**: 현재 미사용

---

### `shared/shared-infra-manager.sh` ⚠️

**역할**: 공유 인프라 관리 도구

**상태**: 현재 미사용

---

### `check-terraform-docs.sh` ⚠️

**역할**: Terraform 문서 검증

**상태**: 현재 미사용

---

### `generate-terraform-docs.sh` ⚠️

**역할**: Terraform 문서 자동 생성

**상태**: 현재 미사용

---

### `import-existing-resources.sh` ⚠️

**역할**: 기존 AWS 리소스를 Terraform으로 import

**상태**: 일회성 마이그레이션 도구 (현재 미사용)

---

## 📊 스크립트 사용 빈도

| 아이콘 | 의미 |
|--------|------|
| ⭐⭐⭐ | 매우 중요, 자주 사용 |
| ⭐⭐ | 중요, 가끔 사용 |
| ⭐ | 보조 도구 |
| ⚠️ | 미사용 또는 deprecated |

---

## 🔄 통합 워크플로우

### 로컬 개발

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

### Atlantis 배포

```bash
# 1. Docker 이미지 빌드 및 푸시
./scripts/build-and-push.sh

# 2. ECS 서비스 업데이트
cd terraform/atlantis
terraform apply

# 3. 헬스체크
./scripts/atlantis/check-atlantis-health.sh prod
```

### Atlantis 운영

```bash
# 실시간 로그 모니터링
./scripts/atlantis/monitor-atlantis-logs.sh prod

# 에러 로그만 확인
./scripts/atlantis/monitor-atlantis-logs.sh prod error

# 헬스체크
./scripts/atlantis/check-atlantis-health.sh prod
```

---

## 📚 관련 문서

- [OPA Policy Integration Guide](../docs/guides/opa-policy-integration-guide.md)
- [Atlantis Setup Guide](../docs/guides/atlantis-setup-guide.md)
- [Infrastructure Governance](../docs/governance/infrastructure_governance.md)
- [Detailed Scripts Analysis](../claudedocs/scripts-analysis.md) (Claude 분석 보고서)

---

## 🛠️ 트러블슈팅

### Git hooks가 실행되지 않음

```bash
# hooks 재설치
./scripts/setup-hooks.sh

# hook 파일 권한 확인
ls -la .git/hooks/pre-commit
ls -la .git/hooks/pre-push

# 실행 권한 부여
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push
```

### Conftest not found

```bash
# macOS
brew install conftest

# Linux
CONFTEST_VERSION=0.49.1
curl -L "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/conftest /usr/local/bin/
```

### Terraform not initialized

```bash
cd terraform/your-module
terraform init
```

---

**Last Updated**: 2025-11-21
