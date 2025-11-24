# Governance 시스템

**목적**: Terraform 인프라 코드의 품질, 보안, 컴플라이언스를 4단계 레이어에서 자동 검증

이 디렉토리는 Infrastructure 프로젝트의 모든 거버넌스 검증 설정과 정책을 중앙에서 관리합니다.

---

## 📋 목차

- [개요](#개요)
- [4단계 검증 레이어](#4단계-검증-레이어)
- [설정 파일](#설정-파일)
- [OPA 정책](#opa-정책)
- [Git Hooks](#git-hooks)
- [사용 가이드](#사용-가이드)
- [수동 검증](#수동-검증)
- [트러블슈팅](#트러블슈팅)

---

## 개요

### 다층 방어 전략 (Defense in Depth)

각 단계에서 정책 위반을 조기에 발견하여 인프라 코드의 품질과 보안을 보장합니다:

| 레이어 | 시점 | 피드백 속도 | 대상 | 우회 가능 |
|--------|------|------------|------|----------|
| **Pre-commit** | 커밋 전 | 1-2초 | 개발자 개인 | Yes (--no-verify) |
| **Pre-push** | 푸시 전 | 30초 | 개발자 개인 | Yes (--no-verify) |
| **Atlantis** | PR plan 실행 시 | 30초-1분 | 팀원 전체 | No |
| **GitHub Actions** | PR 생성/업데이트 시 | 1-2분 | 전체 파이프라인 | No |

### 디렉토리 구조

```
governance/
├── README.md                    # 📖 이 문서
├── configs/                     # ⚙️ 검증 도구 설정
│   ├── conftest.toml           # OPA 정책 설정
│   ├── checkov.yml             # Checkov 컴플라이언스 설정
│   ├── tfsec/                  # tfsec 보안 스캔 설정
│   │   └── config.yml
│   └── infracost.yml           # Infracost 비용 분석 설정
├── policies/                    # 📜 OPA 정책 (Rego)
│   ├── naming/                 # 네이밍 규약
│   ├── tagging/                # 필수 태그
│   ├── security_groups/        # 보안 그룹 규칙
│   └── public_resources/       # 공개 리소스 제한
├── hooks/                       # 🪝 Git hooks
│   ├── pre-commit              # 커밋 전 빠른 검증
│   └── pre-push                # 푸시 전 거버넌스 검증
└── scripts/                     # 🛠️ 거버넌스 검증 스크립트
    ├── validators/             # 검증 스크립트
    │   ├── check-tags.sh
    │   ├── check-encryption.sh
    │   ├── check-naming.sh
    │   ├── check-tfsec.sh
    │   ├── check-checkov.sh
    │   └── validate-terraform-file.sh
    └── policy/                 # 정책 검증 스크립트
        └── run-conftest.sh
```

**참고**:
- 프로젝트 루트의 `conftest.toml`, `.checkov.yml`, `.tfsec/`, `.infracost.yml`, `policies/`는 모두 이 디렉토리를 가리키는 심볼릭 링크입니다.
- 실제 검증 스크립트는 `governance/scripts/` 에서 관리됩니다.

---

## 4단계 검증 레이어

### Layer 1: Pre-commit Hook (1-2초) ⚡

**실행 시점**: `git commit` 직전

**검증 항목**:
1. ✅ Terraform fmt (자동 수정)
2. 🔒 민감 정보 스캔 (패스워드, API 키 등)
3. ✅ Terraform validate
4. 📜 OPA 정책 검증 (Conftest)

**설치 방법**:
```bash
./scripts/setup-hooks.sh
```

**우회 방법** (긴급 상황에만):
```bash
git commit --no-verify -m "Emergency fix"
```

---

### Layer 2: Pre-push Hook (30초) 🛡️

**실행 시점**: `git push` 직전

**검증 항목**:
1. 🏷️ 필수 태그 검증 (`check-tags.sh`)
2. 🔐 KMS 암호화 검증 (`check-encryption.sh`)
3. 📝 네이밍 규약 검증 (`check-naming.sh`)

**우회 방법** (긴급 상황에만):
```bash
git push --no-verify
```

---

### Layer 3: Atlantis (30초-1분) 🤝

**실행 시점**: PR에 Terraform 변경사항이 있을 때 자동 실행

**검증 프로세스**:
1. `terraform plan` 실행
2. Plan 결과를 JSON으로 변환
3. Conftest로 OPA 정책 검증
4. PR에 검증 결과 코멘트

**특징**:
- ✅ 팀원과 검증 결과 공유
- 🚫 정책 실패 시 `apply` 차단
- 📋 PR 코멘트로 상세 결과 제공

---

### Layer 4: GitHub Actions (1-2분) 🔒

**실행 시점**: PR 생성 또는 업데이트 시

**검증 항목**:
1. 📜 OPA 정책 (Conftest)
2. 🛡️ 보안 스캔 (tfsec)
3. 📋 컴플라이언스 (Checkov)
4. 💰 비용 분석 (Infracost)

**특징**:
- 🚫 모든 PR이 통과해야 함 (Admin도 우회 불가)
- 📊 상세한 리포트와 PR 코멘트
- 🔴 Critical/High 이슈는 자동 차단

---

## 설정 파일

### `configs/conftest.toml` - OPA 정책 설정 📜

**역할**: Conftest (OPA) 정책 엔진 설정

**주요 설정**:
```toml
# 정책 디렉토리
policy = ["governance/policies"]

# 네임스페이스
namespace = "main"

# 실패 시 동작
fail_on_warn = false
```

**사용 레이어**:
- ✅ Layer 1 (Pre-commit)
- ✅ Layer 3 (Atlantis)
- ✅ Layer 4 (GitHub Actions)

**위치**: `governance/configs/conftest.toml` (루트의 `conftest.toml`은 심볼릭 링크)

**수동 실행**:
```bash
# Plan 생성
cd terraform/monitoring
terraform plan -out=tfplan

# JSON 변환
terraform show -json tfplan > tfplan.json

# OPA 정책 검증
conftest test tfplan.json --config ../../conftest.toml
```

---

### `configs/checkov.yml` - Checkov 컴플라이언스 설정 🏛️

**역할**: 컴플라이언스 프레임워크 (CIS AWS, PCI-DSS, HIPAA) 검증

**주요 설정**:
```yaml
framework:
  - cis_aws        # CIS AWS Foundations Benchmark
  - pci_dss_v3.2.1 # PCI-DSS 준수
  - hipaa          # HIPAA 준수

check:
  - CKV_AWS_*      # AWS 관련 모든 체크

skip-check:
  - CKV_AWS_144    # 특정 체크 제외
```

**사용 레이어**:
- ✅ Layer 4 (GitHub Actions)

**위치**: `governance/configs/checkov.yml` (루트의 `.checkov.yml`은 심볼릭 링크)

**수동 실행**:
```bash
./governance/scripts/validators/check-checkov.sh terraform/monitoring
```

**참고**: Pre-commit hook에서는 실행 시간이 길어 제외됩니다.

---

### `configs/tfsec/config.yml` - tfsec 보안 스캔 설정 🛡️

**역할**: Terraform 코드의 AWS 보안 모범 사례 검증

**주요 검증**:
- 🔐 암호화 설정 (S3, RDS, EBS 등)
- 🔒 IAM 정책 및 권한
- 🌐 네트워크 보안 (Security Groups, NACLs)
- 📝 로깅 및 모니터링

**심각도 레벨**:
- 🔴 CRITICAL: 즉시 수정 필요
- 🟠 HIGH: PR 승인 전 수정 필요
- 🟡 MEDIUM: 권장 수정
- 🟢 LOW: 참고사항

**사용 레이어**:
- ✅ Layer 4 (GitHub Actions)

**위치**: `governance/configs/tfsec/config.yml` (루트의 `.tfsec/`는 심볼릭 링크)

**수동 실행**:
```bash
./governance/scripts/validators/check-tfsec.sh terraform/monitoring
```

---

### `configs/infracost.yml` - Infracost 비용 분석 설정 💰

**역할**: Terraform 변경사항의 비용 영향 분석

**주요 설정**:
```yaml
version: 0.1

projects:
  - path: terraform/monitoring
    name: monitoring
  - path: terraform/atlantis
    name: atlantis

currency: KRW
```

**임계값**:
- ⚠️ 10% 증가: 경고
- 🚨 30% 증가: 차단

**사용 레이어**:
- ✅ Layer 4 (GitHub Actions)

**위치**: `governance/configs/infracost.yml` (루트의 `.infracost.yml`은 심볼릭 링크)

**수동 실행**:
```bash
cd terraform/monitoring
infracost breakdown --path . --config-file ../../.infracost.yml
```

---

## OPA 정책

### `policies/tagging/` - 필수 태그 검증 🏷️

**정책 파일**:
- `tagging.rego` - 정책 정의
- `tagging_test.rego` - 단위 테스트

**검증 내용**:
모든 AWS 리소스에 7개 필수 태그가 있는지 확인:

```hcl
locals {
  required_tags = {
    Owner       = "platform@example.com"
    CostCenter  = "engineering"
    Environment = "prod"
    Service     = "api-server"
    Team        = "platform-team"
    ManagedBy   = "terraform"
    Project     = "infrastructure"
  }
}

resource "aws_ecr_repository" "example" {
  name = "example"

  tags = merge(
    local.required_tags,  # ✅ REQUIRED
    {
      Name = "ecr-example"
    }
  )
}
```

**위반 예시**:
```
❌ Resource aws_ecr_repository.example missing required tags: [Owner, CostCenter]
```

---

### `policies/naming/` - 네이밍 규약 검증 📝

**정책 파일**:
- `naming.rego` - 정책 정의
- `naming_test.rego` - 단위 테스트

**검증 내용**:
- Resources: `kebab-case` (예: `ecr-atlantis`, `prod-server-vpc`)
- Variables/Outputs/Locals: `snake_case` (예: `aws_region`, `required_tags`)

**올바른 예시**:
```hcl
# ✅ Resources - kebab-case
resource "aws_ecr_repository" "atlantis-prod" {
  name = "atlantis-prod"
}

# ✅ Variables - snake_case
variable "aws_region" {
  type = string
}
```

**위반 예시**:
```hcl
# ❌ Resource에 snake_case 사용
resource "aws_ecr_repository" "atlantis_prod" {
  name = "atlantis_prod"
}

# ❌ Variable에 kebab-case 사용
variable "aws-region" {
  type = string
}
```

---

### `policies/security_groups/` - 보안 그룹 규칙 검증 🔒

**정책 파일**:
- `security_groups.rego` - 정책 정의
- `security_groups_test.rego` - 단위 테스트

**검증 내용**:
SSH (22), RDP (3389) 포트를 인터넷 (0.0.0.0/0)에 노출하는 것을 차단

**위반 예시**:
```hcl
# ❌ SSH를 인터넷에 노출
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # ❌ 차단됨
  security_group_id = aws_security_group.example.id
}
```

**올바른 예시**:
```hcl
# ✅ SSH를 특정 IP로 제한
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]  # ✅ 내부망만 허용
  security_group_id = aws_security_group.example.id
}
```

---

### `policies/public_resources/` - 공개 리소스 제한 검증 🌐

**정책 파일**:
- `public_resources.rego` - 정책 정의
- `public_resources_test.rego` - 단위 테스트

**검증 내용**:
RDS, S3 등 민감한 리소스의 공개 접근 차단

**위반 예시**:
```hcl
# ❌ RDS를 공개 접근 가능하게 설정
resource "aws_db_instance" "example" {
  publicly_accessible = true  # ❌ 차단됨
}

# ❌ S3 버킷 ACL을 public-read로 설정
resource "aws_s3_bucket_acl" "example" {
  acl = "public-read"  # ❌ 차단됨
}
```

**올바른 예시**:
```hcl
# ✅ RDS를 프라이빗으로 설정
resource "aws_db_instance" "example" {
  publicly_accessible = false  # ✅ 정책 통과
}

# ✅ S3 버킷 ACL을 private로 설정
resource "aws_s3_bucket_acl" "example" {
  acl = "private"  # ✅ 정책 통과
}
```

---

## Git Hooks

### `hooks/pre-commit` - 커밋 전 빠른 검증 ⚡

**위치**: `governance/hooks/pre-commit`

**검증 항목**:
1. Terraform fmt (자동 수정)
2. 민감 정보 스캔
3. Terraform validate
4. OPA 정책 검증 (Conftest)

**실행 시간**: 1-2초

**설치 방법**:
```bash
./scripts/setup-hooks.sh
```

이 스크립트는 `governance/hooks/pre-commit` 파일을 `.git/hooks/pre-commit`으로 복사합니다.

---

### `hooks/pre-push` - 푸시 전 거버넌스 검증 🛡️

**위치**: `governance/hooks/pre-push`

**검증 항목**:
1. 필수 태그 검증 (`governance/scripts/validators/check-tags.sh`)
2. KMS 암호화 검증 (`governance/scripts/validators/check-encryption.sh`)
3. 네이밍 규약 검증 (`governance/scripts/validators/check-naming.sh`)

**실행 시간**: 30초

**설치 방법**:
```bash
./scripts/setup-hooks.sh
```

이 스크립트는 `governance/hooks/pre-push` 파일을 `.git/hooks/pre-push`로 복사합니다.

---

## 사용 가이드

### 최초 설정

```bash
# 1. Git hooks 설치
./scripts/setup-hooks.sh

# 2. Conftest 설치 (macOS)
brew install conftest

# 3. Conftest 설치 (Linux)
CONFTEST_VERSION=0.49.1
curl -L "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/conftest /usr/local/bin/
```

### 일반 개발 워크플로우

```bash
# 1. 코드 작성
cd terraform/monitoring
terraform init
terraform fmt
terraform validate

# 2. 커밋 (pre-commit hook 자동 실행)
git add main.tf
git commit -m "Add monitoring resources"
# → fmt, secrets scan, validate, OPA policy 자동 검증

# 3. 푸시 (pre-push hook 자동 실행)
git push origin feature/monitoring
# → tags, encryption, naming 자동 검증

# 4. PR 생성
# → Atlantis와 GitHub Actions가 자동으로 검증
```

### Atlantis 워크플로우

PR에서 Atlantis가 자동으로 실행되지만, 수동 명령어도 사용 가능:

```bash
# PR 코멘트에서 실행
atlantis plan      # Plan 실행 (OPA 정책 자동 검증)
atlantis apply     # Apply 실행 (정책 통과 시에만 가능)
```

---

## 수동 검증

자동화된 검증 외에 수동으로 각 도구를 실행할 수 있습니다:

### OPA 정책 검증

```bash
# 특정 모듈 검증
cd terraform/monitoring
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
conftest test tfplan.json --config ../../conftest.toml

# 스크립트로 검증
./governance/scripts/policy/run-conftest.sh terraform/monitoring
```

### 보안 스캔

```bash
# tfsec
./governance/scripts/validators/check-tfsec.sh terraform/monitoring

# Checkov
./governance/scripts/validators/check-checkov.sh terraform/monitoring
```

### 거버넌스 검증

```bash
# 필수 태그
./governance/scripts/validators/check-tags.sh terraform/monitoring

# KMS 암호화
./governance/scripts/validators/check-encryption.sh terraform/monitoring

# 네이밍 규약
./governance/scripts/validators/check-naming.sh terraform/monitoring

# 단일 파일 검증 (Claude Code hook용)
./governance/scripts/validators/validate-terraform-file.sh terraform/monitoring/main.tf
```

### 비용 분석

```bash
cd terraform/monitoring
infracost breakdown --path . --config-file ../../.infracost.yml
```

### OPA 정책 단위 테스트

```bash
# 전체 정책 테스트
opa test governance/policies/ -v

# 특정 정책 테스트
opa test governance/policies/tagging/ -v
opa test governance/policies/naming/ -v
opa test governance/policies/security_groups/ -v
opa test governance/policies/public_resources/ -v
```

---

## 트러블슈팅

### Git Hooks가 실행되지 않음

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

### Policy file not found

```bash
# conftest.toml이 올바른 경로를 가리키는지 확인
cat conftest.toml

# 심볼릭 링크 확인
ls -la conftest.toml
ls -la policies/

# 필요시 심볼릭 링크 재생성
rm conftest.toml policies
ln -s governance/configs/conftest.toml conftest.toml
ln -s governance/policies policies
```

### OPA 정책 테스트 실패

```bash
# OPA 설치 확인
opa version

# 정책 문법 검증
opa check governance/policies/

# 상세 로그로 테스트
opa test governance/policies/ -v --explain full
```

---

## 정책 추가 방법

새로운 OPA 정책을 추가하려면:

### 1. 정책 파일 작성

`governance/policies/my_policy/my_policy.rego`:
```rego
package main

deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not resource.values.versioning[0].enabled
    msg := sprintf("S3 bucket %s must have versioning enabled", [resource.name])
}
```

### 2. 테스트 작성

`governance/policies/my_policy/my_policy_test.rego`:
```rego
package main

test_s3_versioning_required {
    deny["S3 bucket test-bucket must have versioning enabled"] with input as {
        "planned_values": {
            "root_module": {
                "resources": [{
                    "type": "aws_s3_bucket",
                    "name": "test-bucket",
                    "values": {
                        "versioning": [{"enabled": false}]
                    }
                }]
            }
        }
    }
}
```

### 3. 테스트 실행

```bash
opa test governance/policies/my_policy/ -v
```

### 4. 정책 적용

정책은 자동으로 감지되므로 추가 설정 불필요. 다음 커밋부터 적용됩니다.

---

## 모범 사례

### 1. 점진적 롤아웃
- ⚠️ 처음에는 경고만: 정책을 `warn`으로 시작
- ✅ 팀 교육 후 강제: 팀이 익숙해진 후 `deny`로 변경

### 2. 정책 우선순위
- 🔴 Critical: 보안 취약점 (즉시 차단)
- 🟡 High: 필수 태그, 네이밍 (2주 유예)
- 🟢 Medium: 권장사항 (경고만)

### 3. 예외 처리
```rego
# 특정 리소스 예외 처리
deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    not startswith(resource.name, "legacy-")  # legacy- 접두사는 예외
    # ... 정책 로직
}
```

### 4. 팀 커뮤니케이션
- 📢 정책 변경 공지: 최소 1주 전 공지
- 📚 문서화: 각 정책의 이유와 해결 방법 문서화
- 🎓 교육: 정책 위반 시 가이드 제공

---

## 관련 문서

- [Scripts 디렉토리](../scripts/README.md) - 검증 스크립트 상세 가이드
- [Atlantis 인프라](../terraform/environments/prod/atlantis/README.md) - Atlantis 배포 및 운영

---

**Last Updated**: 2025-11-21
**Version**: 1.0.0
