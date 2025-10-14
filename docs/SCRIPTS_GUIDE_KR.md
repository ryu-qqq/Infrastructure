# 스크립트 사용 가이드

## 📋 목차

1. [개요](#개요)
2. [검증 스크립트](#검증-스크립트)
3. [빌드 및 배포 스크립트](#빌드-및-배포-스크립트)
4. [Git Hooks](#git-hooks)
5. [문제 해결](#문제-해결)

## 개요

`scripts/` 디렉토리에는 인프라 관리 및 거버넌스 검증을 위한 자동화 스크립트가 위치합니다.

### 디렉토리 구조

```
scripts/
├── validators/                  # 거버넌스 검증 스크립트
│   ├── check-tags.sh                 # 필수 태그 검증
│   ├── check-encryption.sh           # KMS 암호화 검증
│   ├── check-naming.sh               # 네이밍 규칙 검증
│   └── validate-terraform-file.sh    # 단일 파일 검증 (Claude hooks용)
│
├── hooks/                       # Git hooks 템플릿
│   ├── pre-commit                    # 커밋 전 검증
│   └── pre-push                      # 푸시 전 검증
│
├── build-and-push.sh            # ECR 이미지 빌드/푸시 스크립트
└── setup-hooks.sh               # Git hooks 설치 스크립트
```

## 검증 스크립트

검증 스크립트는 Terraform 코드가 조직의 거버넌스 정책을 준수하는지 자동으로 확인합니다.

### 1. check-tags.sh - 필수 태그 검증

**목적**: 모든 AWS 리소스에 필수 태그가 포함되어 있는지 검증합니다.

#### 필수 태그 목록
- `Environment`: dev, staging, prod
- `Service`: 서비스 이름
- `Team`: 담당 팀
- `Owner`: 소유자 이메일
- `CostCenter`: 비용 센터
- `ManagedBy`: terraform, manual, cloudformation
- `Project`: 프로젝트 이름

#### 사용법

```bash
# 기본 사용 (terraform/ 디렉토리 검증)
./scripts/validators/check-tags.sh

# 특정 디렉토리 검증
./scripts/validators/check-tags.sh terraform/atlantis

# 특정 모듈 검증
./scripts/validators/check-tags.sh terraform/modules/cloudwatch-log-group
```

#### 검증 로직

1. **required_tags 로컬 변수 확인**
   - `local.required_tags`가 정의되어 있는지 확인
   - 모든 필수 태그가 포함되어 있는지 검증

2. **리소스별 태그 검증**
   - 각 리소스에 `tags` 블록이 있는지 확인
   - `merge(local.required_tags, {...})` 패턴 사용 권장
   - 또는 모든 필수 태그가 직접 정의되어 있는지 확인

3. **예외 리소스**
   - 태그를 지원하지 않는 리소스 자동 제외 (예: `aws_kms_alias`, `aws_iam_role_policy_attachment` 등)
   - S3 버킷 서브리소스 제외 (태그는 버킷 자체만 지원)
   - Random provider 리소스 제외

#### 출력 예시

```bash
$ ./scripts/validators/check-tags.sh

🏷️  Checking required tags in Terraform resources...

📋 Checking for required_tags local definition...
✓ Found required_tags in: terraform/atlantis/variables.tf

🔍 Scanning resources for tags...

✓ aws_ecr_repository.atlantis uses required_tags pattern
✓ aws_kms_key.ecr uses required_tags pattern
✗ Error: No tags found
  Resource: aws_ecs_cluster.main
  File: terraform/atlantis/ecs.tf:15
  💡 Add: tags = merge(local.required_tags, {...})

════════════════════════════════════════
📊 Tag Validation Summary
════════════════════════════════════════
✗ Errors: 1
⚠ Warnings: 0
💡 See: docs/infrastructure_governance.md
```

#### 권장 패턴

**올바른 예시:**
```hcl
# 1. variables.tf에 required_tags 정의
locals {
  required_tags = {
    Environment = var.environment
    Service     = var.service
    Team        = var.team
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }
}

# 2. 리소스에서 required_tags 사용
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"

  # 필수 태그 + 추가 태그 병합
  tags = merge(
    local.required_tags,
    {
      Component = "container-registry"
      DataClass = "confidential"
    }
  )
}
```

**잘못된 예시:**
```hcl
# ❌ 태그 없음
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"
  # tags 블록이 없음!
}

# ❌ 일부 태그만 포함
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"

  tags = {
    Environment = "prod"
    Service     = "atlantis"
    # 나머지 필수 태그 누락!
  }
}
```

### 2. check-encryption.sh - KMS 암호화 검증

**목적**: AWS 리소스가 KMS 암호화를 사용하는지 검증합니다.

#### 검증 항목
- ✅ KMS 키 사용 (`kms_key_id`, `kms_master_key_id` 등)
- ❌ AES256 암호화 금지 (customer-managed KMS 키 필수)

#### 사용법

```bash
# 기본 사용
./scripts/validators/check-encryption.sh

# 특정 디렉토리 검증
./scripts/validators/check-encryption.sh terraform/atlantis
```

#### 검증 리소스
- S3 버킷 (`aws_s3_bucket_server_side_encryption_configuration`)
- RDS 인스턴스 (`storage_encrypted`, `kms_key_id`)
- EBS 볼륨 (`encrypted`, `kms_key_id`)
- ECR 저장소 (`encryption_configuration`)
- CloudWatch Log Group (`kms_key_id`)
- EFS 파일 시스템 (`encrypted`, `kms_key_id`)
- Secrets Manager (`kms_key_id`)
- SNS 토픽 (`kms_master_key_id`)
- SQS 큐 (`kms_master_key_id`)

#### 올바른 예시

```hcl
# KMS 키 정의
resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = local.required_tags
}

# ECR에서 KMS 키 사용
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn  # ✅ KMS 키 사용
  }

  tags = local.required_tags
}
```

#### 잘못된 예시

```hcl
# ❌ AES256 사용
resource "aws_ecr_repository" "atlantis" {
  name = "atlantis"

  encryption_configuration {
    encryption_type = "AES256"  # ❌ 금지됨!
  }
}

# ❌ 암호화 미설정
resource "aws_s3_bucket" "logs" {
  bucket = "my-logs-bucket"
  # encryption_configuration 블록 없음!
}
```

### 3. check-naming.sh - 네이밍 규칙 검증

**목적**: AWS 리소스 이름이 kebab-case 규칙을 따르는지 검증합니다.

#### 네이밍 규칙
- **리소스 이름**: kebab-case (소문자 + 하이픈)
  - 예: `prod-api-server-vpc`, `staging-db-subnet`
- **변수/출력**: snake_case (소문자 + 언더스코어)
  - 예: `vpc_id`, `subnet_ids`

#### 사용법

```bash
# 기본 사용
./scripts/validators/check-naming.sh

# 특정 디렉토리 검증
./scripts/validators/check-naming.sh terraform/atlantis
```

#### 검증 리소스
- VPC (`aws_vpc`)
- Subnet (`aws_subnet`)
- Security Group (`aws_security_group`)
- ECS Cluster (`aws_ecs_cluster`)
- ECS Service (`aws_ecs_service`)
- Load Balancer (`aws_lb`, `aws_alb`)
- Target Group (`aws_lb_target_group`)
- IAM Role (`aws_iam_role`)
- S3 Bucket (`aws_s3_bucket`)
- RDS Instance (`aws_db_instance`)

#### 올바른 예시

```hcl
# ✅ kebab-case
resource "aws_ecs_cluster" "main" {
  name = "prod-api-server-cluster"  # ✅
}

resource "aws_security_group" "alb" {
  name        = "prod-api-server-alb-sg"  # ✅
  description = "Security group for API server ALB"
  vpc_id      = aws_vpc.main.id
}
```

#### 잘못된 예시

```hcl
# ❌ camelCase
resource "aws_ecs_cluster" "main" {
  name = "prodApiServerCluster"  # ❌
}

# ❌ snake_case
resource "aws_security_group" "alb" {
  name = "prod_api_server_alb_sg"  # ❌
}

# ❌ 대문자 포함
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "PROD-VPC"  # ❌
  }
}
```

### 4. validate-terraform-file.sh - 단일 파일 검증

**목적**: Claude Code hooks에서 사용하는 단일 Terraform 파일 검증 스크립트입니다.

#### 사용법

```bash
# 단일 파일 검증
./scripts/validators/validate-terraform-file.sh terraform/atlantis/main.tf
```

#### 검증 항목
- 필수 태그 패턴 (`merge(local.required_tags)`)
- KMS 암호화 (AES256 금지)
- 네이밍 규칙 (kebab-case)
- 하드코딩된 시크릿 검증

#### Claude Code 통합

`.claude/hooks.json`에 정의되어 자동 실행:
```json
{
  "afterWrite": "scripts/validators/validate-terraform-file.sh ${file}",
  "afterEdit": "scripts/validators/validate-terraform-file.sh ${file}"
}
```

## 빌드 및 배포 스크립트

### build-and-push.sh - ECR 이미지 빌드/푸시

**목적**: Atlantis Docker 이미지를 빌드하고 AWS ECR에 푸시합니다.

#### 주요 기능
- Docker 이미지 빌드
- ECR 로그인
- 다중 태그 생성 (버전, Git SHA, 커스텀)
- ECR 푸시
- 이미지 다이제스트 출력

#### 사용법

```bash
# 기본 사용 (latest 태그)
./scripts/build-and-push.sh

# Atlantis 버전 지정
ATLANTIS_VERSION=v0.28.1 ./scripts/build-and-push.sh

# 커스텀 태그 지정
CUSTOM_TAG=prod ./scripts/build-and-push.sh

# AWS 리전 지정
AWS_REGION=us-east-1 ./scripts/build-and-push.sh

# 모든 옵션 조합
ATLANTIS_VERSION=v0.28.1 CUSTOM_TAG=prod AWS_REGION=us-east-1 ./scripts/build-and-push.sh
```

#### 환경 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `AWS_REGION` | AWS 리전 | `ap-northeast-2` |
| `AWS_ACCOUNT_ID` | AWS 계정 ID | 자동 감지 |
| `ATLANTIS_VERSION` | Atlantis 버전 | `v0.28.1` |
| `CUSTOM_TAG` | 커스텀 태그 | `latest` |

#### 이미지 태그 전략

스크립트는 3가지 태그를 자동 생성합니다:

1. **버전 + 타임스탬프**: `v0.28.1-20250114-143022`
   - 고유한 시간 기반 버전
   - 감사 추적 및 롤백에 유용

2. **버전 + Git SHA**: `v0.28.1-abc123`
   - Git 커밋과 연결
   - 소스 코드 추적 가능

3. **커스텀 태그**: `latest`, `prod`, `staging` 등
   - 환경별 배포에 사용
   - 가변적인 태그

#### 실행 예시

```bash
$ ./scripts/build-and-push.sh

[INFO] Fetching AWS Account ID...
[INFO] AWS Account ID: 123456789012
[INFO] Building Atlantis Docker image...
[INFO] Base Atlantis version: v0.28.1
[INFO] Tags to be created:
[INFO]   - 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:v0.28.1-20250114-143022
[INFO]   - 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:v0.28.1-abc123
[INFO]   - 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:latest
[INFO] Docker image built successfully
[INFO] Logging in to ECR...
Login Succeeded
[INFO] Checking if ECR repository exists...
[INFO] Tagging images for ECR...
[INFO] Pushing images to ECR...
[INFO] Successfully pushed images to ECR:
[INFO]   - 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:v0.28.1-20250114-143022
[INFO]   - 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:v0.28.1-abc123
[INFO]   - 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:latest
[INFO] Fetching image digest...
[INFO] Image digest: sha256:abc123def456...
[INFO] Done!
```

#### 프로덕션 사용

```bash
# 1. 특정 버전 빌드
ATLANTIS_VERSION=v0.28.1 CUSTOM_TAG=prod ./scripts/build-and-push.sh

# 2. ECS 태스크 정의에서 Git SHA 태그 사용 (불변)
{
  "image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:v0.28.1-abc123",
  ...
}

# 3. 또는 버전 태그 사용 (불변)
{
  "image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:v0.28.1-20250114-143022",
  ...
}
```

## Git Hooks

Git hooks는 Git 작업 시점에 자동으로 실행되는 스크립트입니다.

### setup-hooks.sh - Git Hooks 설치

**목적**: Pre-commit 및 pre-push hooks를 자동으로 설치합니다.

#### 사용법

```bash
# 프로젝트 루트에서 실행
./scripts/setup-hooks.sh
```

#### 설치되는 Hooks

1. **pre-commit** (커밋 전 실행)
   - Terraform 포맷팅 검증 (`terraform fmt -check`)
   - Terraform 검증 (`terraform validate`)
   - 시크릿 검사 (하드코딩된 자격증명 등)
   - 빠른 검증 (수 초 이내)

2. **pre-push** (푸시 전 실행)
   - 모든 거버넌스 검증 실행
     - `check-tags.sh`
     - `check-encryption.sh`
     - `check-naming.sh`
   - 포괄적인 검증 (수십 초 소요 가능)

#### Hook 우회

긴급 상황에서만 사용하세요:

```bash
# Pre-commit hook 우회
git commit --no-verify -m "emergency fix"

# Pre-push hook 우회
git push --no-verify origin main
```

⚠️ **경고**: Hook 우회는 CI/CD에서 여전히 검증되므로, PR이 실패할 수 있습니다!

### hooks/ 디렉토리

`scripts/hooks/` 디렉토리에는 Git hook 템플릿이 저장되어 있습니다.

```
scripts/hooks/
├── pre-commit       # 커밋 전 검증 템플릿
└── pre-push         # 푸시 전 검증 템플릿
```

#### pre-commit Hook

```bash
#!/bin/bash
# Pre-commit hook: 빠른 검증

set -e

echo "🔍 Running pre-commit validation..."

# Terraform 포맷팅 검증
for dir in $(find terraform -name "*.tf" -type f -exec dirname {} \; | sort -u); do
    if ! terraform fmt -check "$dir" > /dev/null 2>&1; then
        echo "❌ Terraform format check failed in $dir"
        echo "💡 Run: terraform fmt -recursive"
        exit 1
    fi
done

# 시크릿 검사 (간단한 패턴)
if git diff --cached --name-only | xargs grep -E "(aws_secret_access_key|password\s*=|api_key\s*=)" 2>/dev/null; then
    echo "❌ Possible secrets detected!"
    echo "💡 Remove secrets before committing"
    exit 1
fi

echo "✅ Pre-commit validation passed"
```

#### pre-push Hook

```bash
#!/bin/bash
# Pre-push hook: 포괄적인 검증

set -e

echo "🔍 Running pre-push validation..."

# 거버넌스 검증 실행
./scripts/validators/check-tags.sh || exit 1
./scripts/validators/check-encryption.sh || exit 1
./scripts/validators/check-naming.sh || exit 1

echo "✅ Pre-push validation passed"
```

## 문제 해결

### 일반적인 문제

#### 1. 스크립트 실행 권한 오류

```bash
$ ./scripts/validators/check-tags.sh
-bash: ./scripts/validators/check-tags.sh: Permission denied
```

**해결 방법:**
```bash
# 실행 권한 부여
chmod +x scripts/validators/check-tags.sh

# 또는 전체 스크립트에 권한 부여
chmod +x scripts/**/*.sh
```

#### 2. Git Hooks가 실행되지 않음

**원인**: Hooks가 설치되지 않았거나 실행 권한이 없음

**해결 방법:**
```bash
# Hooks 재설치
./scripts/setup-hooks.sh

# 또는 수동 설치
cp scripts/hooks/pre-commit .git/hooks/
cp scripts/hooks/pre-push .git/hooks/
chmod +x .git/hooks/pre-commit .git/hooks/pre-push
```

#### 3. ECR 로그인 실패

```bash
$ ./scripts/build-and-push.sh
[ERROR] Login to ECR failed
```

**해결 방법:**
```bash
# AWS 자격증명 확인
aws sts get-caller-identity

# AWS CLI 버전 확인 (v2 필요)
aws --version

# ECR 권한 확인
aws ecr describe-repositories --region ap-northeast-2
```

#### 4. 검증 스크립트가 너무 많은 오류 출력

**원인**: 기존 코드가 거버넌스 표준을 준수하지 않음

**해결 방법:**
```bash
# 1. 한 번에 하나씩 수정
./scripts/validators/check-tags.sh terraform/atlantis/main.tf

# 2. 또는 전체 리팩토링 계획 수립
# - 우선순위: 프로덕션 리소스 > 개발 리소스
# - 점진적으로 수정

# 3. 긴급 시 특정 검증 비활성화 (권장하지 않음)
# Git hooks에서 해당 검증 스크립트 주석 처리
```

### 스크립트 커스터마이징

#### 검증 규칙 수정

검증 규칙을 조직에 맞게 커스터마이징할 수 있습니다:

```bash
# scripts/validators/check-tags.sh 수정
# 필수 태그 추가/제거
REQUIRED_TAGS=("Environment" "Service" "Team" "Owner" "CostCenter" "ManagedBy" "Project" "YourCustomTag")

# scripts/validators/check-naming.sh 수정
# 네이밍 패턴 변경
# 예: snake_case 허용
if [[ ! "$name" =~ ^[a-z0-9_-]+$ ]]; then
    # 오류 처리
fi
```

#### 새로운 검증 스크립트 추가

```bash
# 1. 새 스크립트 생성
cat > scripts/validators/check-custom.sh << 'EOF'
#!/bin/bash
# 커스텀 검증 로직
set -e

echo "Running custom validation..."
# 검증 로직 구현
EOF

# 2. 실행 권한 부여
chmod +x scripts/validators/check-custom.sh

# 3. Git hooks에 추가
# .git/hooks/pre-push 또는 pre-commit에 추가
./scripts/validators/check-custom.sh || exit 1
```

## 모범 사례

### 1. 개발 워크플로우

```bash
# 1. 개발 시작
git checkout -b feature/my-feature

# 2. 코드 작성
# ... Terraform 코드 작성 ...

# 3. 로컬 검증 (커밋 전)
./scripts/validators/check-tags.sh terraform/my-feature
./scripts/validators/check-encryption.sh terraform/my-feature
./scripts/validators/check-naming.sh terraform/my-feature

# 4. 수정 후 커밋
git add .
git commit -m "feat: add my feature"
# → pre-commit hook 자동 실행

# 5. 푸시
git push origin feature/my-feature
# → pre-push hook 자동 실행
```

### 2. CI/CD 통합

GitHub Actions에서 동일한 스크립트 사용:

```yaml
# .github/workflows/terraform-plan.yml
- name: Validate Governance
  run: |
    ./scripts/validators/check-tags.sh
    ./scripts/validators/check-encryption.sh
    ./scripts/validators/check-naming.sh
```

### 3. 팀 가이드라인

- ✅ 모든 팀원이 Git hooks 설치: `./scripts/setup-hooks.sh`
- ✅ 커밋 전 로컬 검증 실행
- ✅ Hook 우회는 긴급 상황에만 사용
- ✅ CI/CD에서 최종 검증 (hooks 우회 방지)
- ✅ 정기적으로 스크립트 업데이트 확인

## 참고 문서

### 거버넌스 관련
- [Infrastructure Governance](./infrastructure_governance.md) - 거버넌스 정책
- [Tagging Standards](./TAGGING_STANDARDS.md) - 태깅 표준
- [Naming Convention](./NAMING_CONVENTION.md) - 네이밍 규칙

### 개발 관련
- [GitHub Actions Setup Guide](./github_actions_setup.md) - CI/CD 설정
- [Infrastructure PR Workflow](./infrastructure_pr.md) - PR 프로세스
- [Project Overview (한글)](./PROJECT_OVERVIEW_KR.md) - 프로젝트 전체 개요

### 외부 문서
- [Git Hooks Documentation](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [Bash Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Docker CLI Reference](https://docs.docker.com/engine/reference/commandline/cli/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)

## 문의

- **팀**: Infrastructure Team
- **문서**: [docs/](../docs/) 디렉토리 참조
- **이슈**: [Jira - Infrastructure Project](https://ryuqqq.atlassian.net/)
