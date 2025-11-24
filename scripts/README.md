# Scripts 디렉토리

Infrastructure 프로젝트의 자동화 스크립트 모음입니다.

## 📋 목차

- [개요](#개요)
- [디렉토리 구조](#디렉토리-구조)
- [핵심 스크립트](#핵심-스크립트)
  - [Git Hooks 설치](#setup-hookssh)
  - [Docker 빌드 및 배포](#build-and-pushsh)
- [사용 가이드](#사용-가이드)
- [관련 문서](#관련-문서)

---

## 개요

이 디렉토리는 인프라 관리를 위한 운영 및 배포 자동화 스크립트를 포함합니다.

**중요**:
- 거버넌스 관련 스크립트(validators, policy, hooks)는 [`governance/`](../governance/) 패키지로 이동되었습니다.
- Atlantis 운영 스크립트는 [`terraform/environments/prod/atlantis/scripts/`](../terraform/environments/prod/atlantis/scripts/) 디렉토리로 이동되었습니다.

### 스크립트 분류

| 카테고리 | 위치 | 설명 |
|---------|------|------|
| **거버넌스** | `governance/scripts/` | 태그 검증, 암호화 검증, 네이밍 규약, 보안 스캔 |
| **Git Hooks** | `governance/hooks/` | Pre-commit, Pre-push 검증 훅 |
| **배포** | `scripts/` | Docker 이미지 빌드 및 ECR 푸시 |
| **Atlantis 운영** | `terraform/environments/prod/atlantis/scripts/` | 헬스체크, 로그 모니터링, 재시작 |

---

## 디렉토리 구조

```
scripts/
├── README.md                           # 📖 이 문서
├── setup-hooks.sh                      # 🔧 Git hooks 설치
└── build-and-push.sh                   # 🐳 Atlantis Docker 이미지 빌드 및 ECR 푸시
```

**참고**:
- 거버넌스 관련 스크립트는 `governance/` 패키지로 이동:
  - 검증 스크립트: `governance/scripts/validators/`
  - 정책 검증: `governance/scripts/policy/`
  - Git Hooks: `governance/hooks/`
- Atlantis 운영 스크립트는 `terraform/environments/prod/atlantis/scripts/` 디렉토리로 이동

---

## 핵심 스크립트

### `setup-hooks.sh` ⭐⭐⭐

**역할**: Git hooks 자동 설치 및 개발 환경 검증

**기능**:
- `governance/hooks/` 디렉토리의 hook 파일을 `.git/hooks/`로 복사
- 필수 도구 검증 (terraform, git, bash)
- 선택적 도구 확인 (tfsec, checkov, conftest)
- Validator 스크립트 실행 권한 확인

**사용법**:
```bash
# Git hooks 설치
./scripts/setup-hooks.sh
```

**설치되는 hooks**:
- `pre-commit`: 커밋 전 빠른 검증 (fmt, secrets scan, validate, OPA)
- `pre-push`: 푸시 전 거버넌스 검증 (tags, encryption, naming)

**참고**:
- 실제 hook 파일은 `governance/hooks/`에서 관리됩니다
- 검증 스크립트는 `governance/scripts/validators/`에 있습니다
- 자세한 내용은 [governance/README.md](../governance/README.md) 참고

**출력 예시**:
```
════════════════════════════════════════
🔧 Git Hooks Setup for Terraform
════════════════════════════════════════

📋 Checking dependencies...

✓ terraform 1.6.0
✓ git 2.42.0
✓ bash 5.2.15

📦 Optional tools (recommended):

✓ tfsec v1.28.4
✓ checkov 3.1.34

🔗 Installing Git hooks...

✓ Installed: pre-commit
✓ Installed: pre-push

✅ Verifying validators...

✓ check-tags.sh
✓ check-encryption.sh
✓ check-naming.sh

════════════════════════════════════════
📊 Installation Summary
════════════════════════════════════════

✓ Hooks installed: 2
✓ Validators ready: 3/3

✅ Git hooks successfully installed!

📖 What happens now:
  On commit: Fast checks (fmt, secrets, validate)
  On push: Full validation (tags, encryption, naming)

💡 Tips:
  • Bypass (emergency): git commit/push --no-verify
  • Test validators: ./governance/scripts/validators/check-*.sh
  • Documentation: governance/README.md

🎉 Ready to develop with governance!
```

---

### `build-and-push.sh` ⭐⭐

**역할**: Atlantis Docker 이미지 빌드 및 ECR 푸시

**기능**:
- Atlantis 공식 이미지 기반 커스텀 이미지 빌드
- Conftest와 Terraform 추가 설치
- Multi-architecture 지원 (amd64, arm64)
- ECR 로그인 및 이미지 푸시
- 3-tag 전략: `git-SHA`, `latest`, `YYYYMMDD-HHMMSS`

**사용법**:
```bash
# 기본 빌드 (latest Atlantis version)
./scripts/build-and-push.sh

# 특정 Atlantis 버전 지정
ATLANTIS_VERSION=v0.30.0 ./scripts/build-and-push.sh

# 커스텀 태그 지정
CUSTOM_TAG=prod ./scripts/build-and-push.sh

# 빌드만 수행 (푸시 건너뛰기)
SKIP_PUSH=true ./scripts/build-and-push.sh
```

**환경 변수**:
- `ATLANTIS_VERSION`: Atlantis 버전 (default: `v0.30.0`)
- `AWS_ACCOUNT_ID`: AWS 계정 ID (default: 자동 감지)
- `AWS_REGION`: AWS 리전 (default: `ap-northeast-2`)
- `ECR_REPOSITORY`: ECR 저장소 이름 (default: `ecr-atlantis`)
- `CUSTOM_TAG`: 추가 태그 (optional)
- `SKIP_PUSH`: 푸시 건너뛰기 (optional, `true`로 설정)

**사용 예시**:
```bash
# 1. 로컬 테스트 빌드
SKIP_PUSH=true ./scripts/build-and-push.sh

# 2. Production 배포
ATLANTIS_VERSION=v0.30.0 CUSTOM_TAG=prod ./scripts/build-and-push.sh

# 3. Staging 배포
CUSTOM_TAG=staging ./scripts/build-and-push.sh
```

**푸시되는 태그**:
```
{AWS_ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/ecr-atlantis:abc1234      # git commit SHA
{AWS_ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/ecr-atlantis:latest       # 최신 이미지
{AWS_ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/ecr-atlantis:20250124-143022  # 빌드 시각
{AWS_ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/ecr-atlantis:prod         # 커스텀 태그 (optional)
```

**출력 예시**:
```
════════════════════════════════════════
🐳 Atlantis Docker Build & Push
════════════════════════════════════════

📋 Configuration:
  Atlantis Version: v0.30.0
  AWS Account: 123456789012
  AWS Region: ap-northeast-2
  ECR Repository: ecr-atlantis
  Git SHA: abc1234
  Timestamp: 20250124-143022

🔨 Building Docker image...

[+] Building 45.2s (12/12) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 856B
 ...

✅ Build completed successfully!

🔐 Logging in to ECR...

Login Succeeded

📦 Tagging images...

✓ Tagged: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-atlantis:abc1234
✓ Tagged: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-atlantis:latest
✓ Tagged: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-atlantis:20250124-143022

🚀 Pushing images to ECR...

The push refers to repository [123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-atlantis]
abc1234: digest: sha256:... size: 2415

✅ All images pushed successfully!

📊 Summary:
  Repository: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/ecr-atlantis
  Tags pushed: 3
    - abc1234
    - latest
    - 20250124-143022

🎉 Deployment ready!
```

**Dockerfile 내용**:
```dockerfile
FROM ghcr.io/runatlantis/atlantis:${ATLANTIS_VERSION}

# Install conftest for OPA policy validation
RUN apk add --no-cache curl && \
    curl -L https://github.com/open-policy-agent/conftest/releases/download/v0.45.0/conftest_0.45.0_Linux_x86_64.tar.gz \
    | tar xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/conftest

# Install additional Terraform versions (optional)
# RUN terraform --version
```

**참고**:
- ECR 저장소가 없으면 자동으로 생성됩니다
- 이미지 스캔은 ECR 푸시 후 자동으로 실행됩니다 (취약점 검사)
- CI/CD에서 사용 시 AWS 인증이 필요합니다
- Multi-architecture 빌드는 Docker Buildx를 사용합니다

---

## 사용 가이드

### 로컬 개발 워크플로우

```bash
# 1. 저장소 클론 및 Git hooks 설치
git clone <repository>
cd infrastructure
./scripts/setup-hooks.sh

# 2. Terraform 작업
cd terraform/monitoring
terraform init
terraform plan

# 3. 커밋 (pre-commit hook 자동 실행)
git add .
git commit -m "feat: Add CloudWatch alarm"

# 4. 푸시 (pre-push hook 자동 실행)
git push origin feature/monitoring
```

### Atlantis 배포 워크플로우

```bash
# 1. Atlantis Docker 이미지 빌드
ATLANTIS_VERSION=v0.30.0 ./scripts/build-and-push.sh

# 2. Terraform apply (별도 작업)
cd terraform/environments/prod/atlantis
terraform apply

# 3. Atlantis 운영 스크립트는 다음 위치에서 사용:
cd terraform/environments/prod/atlantis/scripts
./check-atlantis-health.sh
./monitor-atlantis-logs.sh
```

### 거버넌스 검증 워크플로우

```bash
# 1. 개별 validator 수동 실행
./governance/scripts/validators/check-tags.sh terraform/monitoring
./governance/scripts/validators/check-encryption.sh terraform/monitoring
./governance/scripts/validators/check-naming.sh terraform/monitoring

# 2. 보안 스캔 수동 실행
./governance/scripts/validators/check-tfsec.sh terraform/monitoring
./governance/scripts/validators/check-checkov.sh terraform/monitoring

# 3. OPA 정책 검증
./governance/scripts/policy/run-conftest.sh terraform/monitoring
```

---

## 문제 해결

### Git Hooks 관련

**문제**: Hooks가 실행되지 않음
```bash
# 해결책: 실행 권한 확인
ls -la .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**문제**: Validator 스크립트 권한 오류
```bash
# 해결책: 검증 스크립트에 실행 권한 부여
chmod +x governance/scripts/validators/*.sh
```

**문제**: 긴급 상황에서 검증 우회 필요
```bash
# 해결책: --no-verify 플래그 사용 (신중하게 사용)
git commit --no-verify -m "emergency fix"
git push --no-verify
```

### Docker 빌드 관련

**문제**: ECR 로그인 실패
```bash
# 해결책: AWS 인증 확인
aws sts get-caller-identity
aws ecr get-login-password --region ap-northeast-2
```

**문제**: Multi-architecture 빌드 실패
```bash
# 해결책: Docker Buildx 설정
docker buildx create --use
docker buildx inspect --bootstrap
```

**문제**: 빌드 캐시 문제
```bash
# 해결책: 캐시 없이 빌드
docker build --no-cache -t atlantis .
```

---

## 거버넌스 빠른 참조

### 검증 계층

1. **Pre-commit (로컬)**: 커밋 전 빠른 검증
   - `terraform fmt`
   - Secrets 스캔
   - `terraform validate`
   - OPA 정책 검증

2. **Pre-push (로컬)**: 푸시 전 거버넌스 검증
   - 필수 태그 검증
   - KMS 암호화 검증
   - 네이밍 규약 검증

3. **Atlantis (서버)**: PR 생성 시 자동 검증
   - `terraform plan`
   - Conftest 정책 검증
   - 비용 분석 (Infracost)

4. **GitHub Actions (CI)**: PR 검증 및 머지 후 배포
   - tfsec 보안 스캔
   - Checkov 규정 준수 검증
   - Terraform apply 및 배포

### 거버넌스 규칙

**필수 태그** (모든 리소스):
- `Owner`: 소유자 이메일
- `CostCenter`: 비용 센터
- `Environment`: dev/staging/prod
- `Lifecycle`: 리소스 수명주기
- `DataClass`: 데이터 분류
- `Service`: 서비스 이름

**KMS 암호화** (필수):
- 모든 암호화는 고객 관리형 KMS 키 사용
- AES256 사용 금지 (AWS 관리형 키)

**네이밍 규약**:
- 리소스: `kebab-case` (예: `ecr-atlantis`)
- Variables/Locals: `snake_case` (예: `aws_region`)

**보안**:
- 하드코딩된 시크릿 금지
- Public 리소스는 명시적 승인 필요
- 보안 그룹은 최소 권한 원칙

자세한 내용은 [governance/README.md](../governance/README.md)를 참고하세요.

---

## 📚 관련 문서

- [Governance README](../governance/README.md) - 거버넌스 검증 상세 가이드
- [Atlantis Scripts](../terraform/environments/prod/atlantis/scripts/README.md) - Atlantis 운영 스크립트 상세 문서

---

**Last Updated**: 2025-11-24
**Version**: 3.0.0 (Atlantis 스크립트 이동 및 docs 패키지 제거)
