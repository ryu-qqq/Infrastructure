# OPA (Open Policy Agent) Policies

Terraform 인프라 코드의 보안, 규정 준수, 네이밍 규약을 검증하는 OPA/Conftest 정책입니다.

## 설치

### OPA (Open Policy Agent)

#### macOS (Homebrew)
```bash
brew install opa
```

#### Linux
```bash
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa
sudo mv opa /usr/local/bin/
```

#### Windows (Chocolatey)
```powershell
choco install opa
```

### Conftest

#### macOS (Homebrew)
```bash
brew install conftest
```

#### Linux
```bash
CONFTEST_VERSION=0.49.1
curl -L "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" | tar xz
sudo mv conftest /usr/local/bin/
```

#### Windows (Scoop)
```powershell
scoop install conftest
```

## 정책 구조

```
policies/
├── tagging/
│   ├── required_tags.rego            # 필수 태그 검증 정책
│   └── required_tags_test.rego       # 태그 정책 테스트
├── naming/
│   ├── resource_naming.rego          # 네이밍 규약 검증 정책
│   └── resource_naming_test.rego     # 네이밍 정책 테스트
├── security_groups/
│   ├── security_group_rules.rego     # 보안 그룹 규칙 검증 정책
│   └── security_group_rules_test.rego # 보안 그룹 정책 테스트
├── public_resources/
│   ├── public_access.rego            # 공개 리소스 접근 검증 정책
│   └── public_access_test.rego       # 공개 리소스 정책 테스트
└── README.md                          # 이 파일
```

## 사용 방법

### 빠른 시작 (Conftest 사용)

```bash
# 1. Terraform Plan 생성
cd terraform/your-module
terraform init
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# 2. Conftest로 정책 검증
cd ../../  # 프로젝트 루트로 이동
conftest test tfplan.json --config conftest.toml

# 또는 자동화 스크립트 사용
./scripts/policy/run-conftest.sh terraform
```

### 수동 검증 (OPA 사용)

#### 1. Terraform Plan 생성

```bash
cd terraform/kms  # 또는 다른 모듈
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
```

#### 2. OPA 정책 검증

```bash
# 모든 정책 평가
opa eval --data policies/ --input tfplan.json "data.terraform"

# 위반 사항만 확인
opa eval --data policies/ --input tfplan.json "data.terraform.tagging.required_tags.deny"
opa eval --data policies/ --input tfplan.json "data.terraform.naming.resource_naming.deny"
opa eval --data policies/ --input tfplan.json "data.terraform.security.security_groups.deny"
opa eval --data policies/ --input tfplan.json "data.terraform.security.public_resources.deny"

# JSON 출력
opa eval --format pretty --data policies/ --input tfplan.json "data.terraform" > opa-result.json
```

#### 3. 정책 테스트

```bash
# 모든 테스트 실행
opa test policies/

# 특정 패키지 테스트
opa test policies/tagging/
opa test policies/naming/
opa test policies/security_groups/
opa test policies/public_resources/

# 상세 출력
opa test -v policies/
```

## 정책 설명

### Tagging Policy (policies/tagging/required_tags.rego)

모든 AWS 리소스에 필수 태그가 포함되어 있는지 검증합니다.

**검증 항목**:
- ✅ 필수 태그 존재 여부: Environment, Service, Team, Owner, CostCenter, ManagedBy, Project
- ✅ Environment 태그 값: `dev`, `staging`, `prod` 중 하나
- ✅ ManagedBy 태그 값: `terraform`, `manual`, `cloudformation`, `cdk` 중 하나
- ✅ kebab-case 형식: Service, Team, CostCenter, Project
- ✅ Owner 형식: 이메일 주소 또는 kebab-case 식별자

**예시**:
```hcl
resource "aws_instance" "api" {
  # ...

  tags = {
    Environment = "prod"           # ✅ Valid value
    Service     = "api"            # ✅ kebab-case
    Team        = "platform-team"  # ✅ kebab-case
    Owner       = "team@company.com" # ✅ Email format
    CostCenter  = "infrastructure" # ✅ kebab-case
    ManagedBy   = "terraform"      # ✅ Valid value
    Project     = "infrastructure" # ✅ kebab-case
  }
}
```

### Naming Policy (policies/naming/resource_naming.rego)

AWS 리소스 이름이 kebab-case 네이밍 규약을 준수하는지 검증합니다.

**검증 항목**:
- ✅ kebab-case 형식: 소문자, 숫자, 하이픈만 사용
- ✅ camelCase 금지: `myApiServer` ❌
- ✅ snake_case 금지: `my_api_server` ❌
- ✅ 대문자 금지: `MY-API-SERVER` ❌
- ✅ 연속 하이픈 금지: `my--api--server` ❌
- ✅ 하이픈으로 시작/끝 금지: `-my-api-server-` ❌

**특수 규칙**:
- S3 버킷: 점(`.`) 허용, 계정 ID 포함 권장
- KMS Alias: `alias/` prefix 필수
- ECR Repository: 슬래시(`/`) 및 언더스코어(`_`) 허용

**예시**:
```hcl
# ✅ Valid
resource "aws_instance" "api" {
  tags = {
    Name = "prod-api-web-01"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "myorg-prod-logs-123456789012"
}

resource "aws_kms_alias" "rds" {
  name = "alias/rds-encryption"
}

# ❌ Invalid
resource "aws_instance" "api" {
  tags = {
    Name = "prodApiWeb"  # camelCase
  }
}
```

### Security Group Policy (policies/security_groups/security_group_rules.rego)

AWS Security Group이 보안 모범 사례를 준수하는지 검증합니다.

**검증 항목**:
- 🚫 **Critical**: 모든 트래픽 허용 (0.0.0.0/0, all ports) 금지
- 🚫 **Critical**: 위험한 포트(SSH, RDP, DB 등) 인터넷 노출 금지
- 🚫 **Critical**: IPv6 인터넷(::/0)에 위험한 포트 노출 금지
- ⚠️  **Warning**: Security Group 설명 누락
- ⚠️  **Warning**: 일반적인 설명 사용 (예: "Managed by Terraform")
- ⚠️  **Warning**: 무제한 Egress 트래픽

**위험한 포트 목록**:
- 22 (SSH)
- 3389 (RDP)
- 3306 (MySQL)
- 5432 (PostgreSQL)
- 6379 (Redis)
- 27017 (MongoDB)
- 9200 (Elasticsearch)
- 5601 (Kibana)

**예시**:
```hcl
# ✅ Valid - 제한된 접근
resource "aws_security_group" "api" {
  name        = "api-security-group"
  description = "Security group for API servers in the application tier"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # Private network only
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ❌ Invalid - SSH 인터넷 노출
resource "aws_security_group" "bad" {
  name        = "bad-sg"
  description = "Security group"  # Generic description

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Internet accessible
  }
}
```

### Public Resources Policy (policies/public_resources/public_access.rego)

AWS 리소스가 불필요하게 인터넷에 노출되지 않도록 검증합니다.

**검증 항목**:
- 🚫 **Critical**: RDS 인스턴스 publicly_accessible 금지
- 🚫 **Critical**: 프로덕션 RDS publicly_accessible 절대 금지
- 🚫 **Critical**: S3 버킷 public access 활성화 금지
- ⚠️  **Warning**: S3 버킷 public access block 설정 누락
- ⚠️  **Warning**: 프로덕션 EC2 인스턴스 public IP 할당
- ⚠️  **Warning**: 프로덕션 ALB/ELB internet-facing (justification 필요)
- ⚠️  **Warning**: Lambda Function URL 인증 없음

**예시**:
```hcl
# ✅ Valid - Private RDS with public access block
resource "aws_db_instance" "main" {
  identifier          = "prod-database"
  publicly_accessible = false

  tags = {
    Environment = "prod"
  }
}

resource "aws_s3_bucket_public_access_block" "secure" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ✅ Valid - Public ALB with justification
resource "aws_lb" "public" {
  name            = "public-alb"
  internal        = false
  load_balancer_type = "application"

  tags = {
    Environment  = "prod"
    PublicAccess = "Web application frontend - required for external users"
  }
}

# ❌ Invalid - Public RDS in production
resource "aws_db_instance" "bad" {
  identifier          = "prod-db"
  publicly_accessible = true

  tags = {
    Environment = "prod"
  }
}

# ❌ Invalid - S3 without public access block
resource "aws_s3_bucket" "bad" {
  bucket = "my-bucket"
  # Missing aws_s3_bucket_public_access_block
}
```

## 정책 검증 통합

이 정책들은 **다층 방어(Defense in Depth)** 전략으로 세 가지 레이어에서 자동 검증됩니다:

| 레이어 | 시점 | 피드백 속도 | 우회 가능 | 상태 |
|--------|------|------------|----------|------|
| **Pre-commit Hook** | 커밋 전 | 1-2초 | Yes (--no-verify) | ✅ 구현됨 |
| **Atlantis** | PR plan 실행 시 | 30초-1분 | No | ✅ 구현됨 |
| **GitHub Actions** | PR 생성/업데이트 시 | 1-2분 | No | ✅ 구현됨 |

### 1. 로컬 개발: Pre-commit Hook

**설치**:
```bash
# 자동 설치 (권장)
./scripts/setup-hooks.sh

# 수동 설치
cp scripts/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**동작**:
- ✅ Terraform fmt, validate 실행
- ✅ 민감 정보 스캔
- ✅ OPA 정책 검증 (conftest)
- ✅ 정책 실패 시 커밋 차단

**구현 파일**: [`scripts/hooks/pre-commit`](../scripts/hooks/pre-commit)

**사용 예시**:
```bash
$ git commit -m "Add monitoring resources"

🔍 Running pre-commit checks...
📜 Running OPA policy validation...
✓ OPA policies passed for terraform/monitoring
✓ All pre-commit checks passed!
```

---

### 2. PR 리뷰: Atlantis

**설정**: `atlantis.yaml` + `docker/Dockerfile`에 통합됨

**동작**:
- ✅ PR plan 실행 시 자동으로 정책 검증
- ✅ Plan JSON을 conftest로 검증
- ✅ 정책 실패 시 apply 차단

**구현 파일**:
- [`atlantis.yaml`](../atlantis.yaml) - Workflow 정의
- [`docker/Dockerfile`](../docker/Dockerfile) - Conftest 설치

**atlantis.yaml 설정**:
```yaml
workflows:
  default:
    plan:
      steps:
        - env:
            name: TF_PLUGIN_CACHE_DIR
            value: ""
        - init:
            extra_args:
              - "-upgrade"
        - plan
        # OPA Policy Validation
        - run: |
            echo "🔍 Running OPA policy validation..."
            terraform show -json $PLANFILE > tfplan.json
            if conftest test tfplan.json --config ../../conftest.toml; then
              echo "✅ OPA policy validation passed"
            else
              echo "❌ OPA policy validation failed"
              exit 1
            fi
```

**Atlantis 서버 재배포**:
```bash
# Docker 이미지에 conftest가 포함되어 있음
./scripts/build-and-push.sh
```

---

### 3. CI/CD: GitHub Actions

**설정**: `.github/workflows/terraform-plan.yml`에 통합됨

**동작**:
- ✅ PR 생성 시 자동 실행
- ✅ 모든 모듈 병렬 검증
- ✅ PR에 상세한 검증 결과 코멘트
- ✅ 최종 보안 게이트 (우회 불가능)

**구현 파일**: [`.github/workflows/terraform-plan.yml`](../.github/workflows/terraform-plan.yml)

**워크플로우 단계**:
1. Conftest 설치
2. Terraform plan 생성 (모듈별)
3. Plan을 JSON으로 변환
4. Conftest로 정책 검증
5. PR에 결과 코멘트

**PR 코멘트 예시**:
```markdown
📜 OPA Policy Validation (Conftest)

✅ Passed: 45
❌ Failed: 2

Module Breakdown:
- Monitoring: 23 passed, 1 failed
- Atlantis: 22 passed, 1 failed

⚠️ Action Required: OPA policy violations must be resolved.
```

---

### 통합 상세 가이드

세 가지 레이어의 설치, 설정, 트러블슈팅 등 상세한 내용은 다음 문서를 참조하세요:

📚 **[OPA Policy Integration Guide](../docs/guides/opa-policy-integration-guide.md)**

- 각 레이어 설치 방법
- 동작 원리 상세 설명
- 트러블슈팅 가이드
- 정책 추가/수정 방법
- 모범 사례

## 정책 개발

### 새 정책 추가

1. `policies/{category}/{policy_name}.rego` 파일 생성
2. 정책 로직 구현
3. `policies/{category}/{policy_name}_test.rego` 테스트 파일 생성
4. `opa test policies/` 실행하여 테스트 검증

### 정책 수정

1. 정책 파일 수정
2. 테스트 케이스 업데이트
3. `opa test policies/ -v` 실행하여 모든 테스트 통과 확인

### 정책 문법

```rego
package terraform.category.policy_name

import future.keywords.if
import future.keywords.in

# Rule definition
rule_name[result] if {
    # Logic here
    condition
    result := {
        "resource": value,
        "message": message,
    }
}

# Deny rule (used by validation)
deny[msg] if {
    violation := rule_name[_]
    msg := violation.message
}
```

## 트러블슈팅

### OPA 명령어가 실행되지 않음

```bash
# OPA 설치 확인
which opa
opa version

# PATH 확인
echo $PATH
```

### 정책이 적용되지 않음

```bash
# 정책 문법 검증
opa check policies/

# 정책 테스트 실행
opa test -v policies/
```

### Terraform JSON 형식 오류

```bash
# Plan 재생성
rm tfplan.binary tfplan.json
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# JSON 유효성 검증
jq . tfplan.json > /dev/null
```

## 참고 자료

- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Language Guide](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [Terraform JSON Output](https://www.terraform.io/docs/cli/commands/show.html#json-output)
- [AWS Tagging Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws_tagging.html)
