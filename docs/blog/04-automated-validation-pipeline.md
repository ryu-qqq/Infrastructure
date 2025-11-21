# PR 기반 자동화 파이프라인 구축 – Terraform (4)

## 🚨 문제: 수동 검증의 한계

PR을 열면 리뷰어가 다음을 모두 확인해야 합니다:

```markdown
✅ Terraform 문법 검증
✅ 보안 취약점 확인
✅ 정책 준수 여부
✅ 비용 영향 분석
✅ 필수 태그 존재 확인
✅ 네이밍 규칙 준수
✅ 암호화 설정 확인
```

**문제점:**
- 🔴 리뷰어가 매번 수동으로 확인해야 함
- 🔴 사람이 실수할 수 있음 (놓치는 항목)
- 🔴 리뷰 시간이 오래 걸림
- 🔴 일관성 없는 검증 (리뷰어마다 다름)
- 🔴 문제를 배포 후에 발견

## ✅ 해결: 4단계 자동 검증 파이프라인

```
PR 생성 → GitHub Actions 트리거
          │
          ├─ 1단계: Terraform 검증 (fmt, validate)
          ├─ 2단계: 보안 스캔 (tfsec)
          ├─ 3단계: 정책 검증 (checkov, OPA)
          └─ 4단계: 비용 분석 (Infracost)
          │
          ├─ 모든 검증 통과 ✅
          └─ PR에 자동 코멘트 생성
```

## 🏗️ GitHub Actions 워크플로우 아키텍처

### 전체 파이프라인 구조

```yaml
# .github/workflows/terraform-plan.yml
name: Terraform Plan
on:
  pull_request:
    paths:
      - 'terraform/**/*.tf'
      - '.github/workflows/terraform-plan.yml'

jobs:
  # 1단계: Terraform 검증
  terraform-validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.8

      - name: Terraform Format Check
        run: terraform fmt -check -recursive terraform/

      - name: Terraform Init & Validate
        run: |
          cd terraform/network
          terraform init -backend=false
          terraform validate

  # 2단계: 보안 스캔
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1
        with:
          soft_fail: false
          working_directory: terraform/

      - name: Run checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: terraform/
          framework: terraform
          soft_fail: false

  # 3단계: 정책 검증
  policy-validation:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup OPA
        uses: open-policy-agent/setup-opa@v2

      - name: Run OPA Policy Tests
        run: |
          # 필수 태그 검증
          opa test policies/tagging/

          # 네이밍 규칙 검증
          opa test policies/naming/

          # 암호화 검증
          opa test policies/encryption/

  # 4단계: 비용 분석
  cost-analysis:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Infracost
        uses: infracost/actions/setup@v3
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      - name: Generate Infracost diff
        run: |
          infracost breakdown --path=terraform/ \
            --format=json \
            --out-file=/tmp/infracost.json

      - name: Post Infracost comment
        uses: infracost/actions/comment@v1
        with:
          path: /tmp/infracost.json
          behavior: update
```

## 🔍 1단계: Terraform 검증

### Terraform Format 검증

```bash
# 로컬에서 실행
terraform fmt -check -recursive terraform/

# ❌ 포맷이 맞지 않으면 에러
Error: terraform/network/vpc.tf
  - resource "aws_vpc" "main" {
  -     cidr_block = "10.0.0.0/16"
  - }
  + resource "aws_vpc" "main" {
  +   cidr_block = "10.0.0.0/16"
  + }

# ✅ 자동 포맷 적용
terraform fmt -recursive terraform/
```

### Terraform Validate

```bash
# 로컬에서 실행
cd terraform/network
terraform init -backend=false
terraform validate

# ❌ 문법 오류 예시
Error: Unsupported argument

  on vpc.tf line 5, in resource "aws_vpc" "main":
   5:   cidr_blocks = "10.0.0.0/16"

An argument named "cidr_blocks" is not expected here. Did you mean "cidr_block"?

# ✅ 검증 성공
Success! The configuration is valid.
```

## 🛡️ 2단계: 보안 스캔

### tfsec (AWS 보안 Best Practices)

```bash
# 로컬에서 실행
tfsec terraform/

# ❌ 보안 이슈 발견 예시
Result #1 CRITICAL Security group rule allows egress to multiple public internet addresses.
─────────────────────────────────────────────────────────────────────
  terraform/network/security-groups.tf:15-20
─────────────────────────────────────────────────────────────────────
   15 ┆ resource "aws_security_group_rule" "egress" {
   16 ┆   type              = "egress"
   17 ┆   from_port         = 0
   18 ┆   to_port           = 0
   19 ┆   protocol          = "-1"
   20 ┆   cidr_blocks       = ["0.0.0.0/0"]  # ← 위험!
   21 ┆ }
─────────────────────────────────────────────────────────────────────
          ID aws-ec2-no-public-egress-sgr
      Impact: Your port is egressing data to the internet
  Resolution: Set a more restrictive cidr range

  More Info:
  - https://aquasecurity.github.io/tfsec/v1.28.1/checks/aws/ec2/no-public-egress-sgr/
```

### 실제 프로젝트의 tfsec 설정

```yaml
# .tfsec/config.yml
severity_overrides:
  # CRITICAL: 즉시 수정 필요
  aws-s3-enable-bucket-encryption: CRITICAL
  aws-rds-encrypt-instance-storage-data: CRITICAL
  aws-ec2-enforce-http-token-imds: CRITICAL

  # HIGH: PR 승인 전 수정
  aws-iam-no-policy-wildcards: HIGH
  aws-s3-enable-bucket-logging: HIGH

  # MEDIUM: 권장사항
  aws-ec2-enable-at-rest-encryption: MEDIUM

exclude:
  # 알려진 false positive
  - aws-s3-enable-versioning  # 일부 버킷은 versioning 불필요
```

### checkov (정책 준수 검증)

```bash
# 로컬에서 실행
checkov -d terraform/ --framework terraform

# ❌ 정책 위반 예시
Check: CKV_AWS_158: "Ensure that CloudWatch Log Group is encrypted by KMS"
	FAILED for resource: aws_cloudwatch_log_group.api_logs
	File: /terraform/services/api-server/logs.tf:1-5
	Guide: https://docs.bridgecrew.io/docs/bc_aws_logging_2

		1  | resource "aws_cloudwatch_log_group" "api_logs" {
		2  |   name              = "/aws/api/logs"
		3  |   retention_in_days = 30
		4  |   # kms_key_id 누락 ← 문제!
		5  | }

# ✅ 수정 후
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/api/logs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn  # 추가
}
```

### 실제 프로젝트의 checkov 설정

```yaml
# .checkov.yml
framework:
  - terraform

soft-fail: false  # 이슈 발견 시 실패

skip-check:
  # 특정 체크 건너뛰기 (사유와 함께)
  - CKV_AWS_18  # S3 bucket access logging (일부 버킷은 로깅 불필요)
  - CKV_AWS_144  # S3 bucket replication (단일 리전 전략)

check:
  # 활성화할 정책 프레임워크
  - CIS_AWS_1_2_0
  - PCI_DSS_V321
  - HIPAA
```

## 📋 3단계: OPA 정책 검증

### OPA (Open Policy Agent)로 조직 정책 강제

```rego
# policies/tagging/required_tags.rego
package terraform.tagging

# 필수 태그 목록
required_tags := [
    "Environment",
    "Service",
    "Team",
    "Owner",
    "CostCenter",
    "ManagedBy",
    "Project",
]

# 모든 리소스에 필수 태그가 있는지 확인
deny[msg] {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"

    # 태그를 가질 수 있는 리소스만 확인
    taggable_resource(resource.type)

    # 누락된 태그 찾기
    missing_tags := required_tags - {tag | resource.change.after.tags[tag]}
    count(missing_tags) > 0

    msg := sprintf(
        "❌ Resource '%s' is missing required tags: %v",
        [resource.address, missing_tags]
    )
}

taggable_resource(type) {
    taggable_types := {
        "aws_instance",
        "aws_vpc",
        "aws_subnet",
        "aws_security_group",
        "aws_s3_bucket",
        "aws_db_instance",
        "aws_ecs_cluster",
        # ... 더 많은 리소스 타입
    }
    taggable_types[type]
}

# 환경 태그 값 검증
deny[msg] {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"

    env := resource.change.after.tags.Environment
    not valid_environment(env)

    msg := sprintf(
        "❌ Resource '%s' has invalid Environment tag: '%s' (must be dev, staging, or prod)",
        [resource.address, env]
    )
}

valid_environment(env) {
    env == "dev"
}
valid_environment(env) {
    env == "staging"
}
valid_environment(env) {
    env == "prod"
}
```

### OPA 정책 테스트

```bash
# 1. Terraform plan을 JSON으로 생성
cd terraform/network
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# 2. OPA로 정책 검증
opa eval \
  --data policies/tagging/required_tags.rego \
  --input tfplan.json \
  --format pretty \
  "data.terraform.tagging.deny"

# ❌ 정책 위반 예시
[
  "❌ Resource 'aws_vpc.main' is missing required tags: [\"CostCenter\", \"Owner\"]",
  "❌ Resource 'aws_subnet.public[0]' has invalid Environment tag: 'production' (must be dev, staging, or prod)"
]

# ✅ 모든 정책 통과
[]
```

### 네이밍 규칙 정책

```rego
# policies/naming/naming_conventions.rego
package terraform.naming

# 리소스 네이밍 규칙: kebab-case
deny[msg] {
    resource := input.resource_changes[_]
    resource.change.actions[_] == "create"

    name := resource.change.after.name
    not valid_kebab_case(name)

    msg := sprintf(
        "❌ Resource '%s' name '%s' must use kebab-case (lowercase letters, numbers, hyphens only)",
        [resource.address, name]
    )
}

valid_kebab_case(name) {
    regex.match("^[a-z][a-z0-9-]*$", name)
}

# 변수/로컬 네이밍 규칙: snake_case
deny[msg] {
    variable := input.configuration.root_module.variables[var_name]
    not valid_snake_case(var_name)

    msg := sprintf(
        "❌ Variable '%s' must use snake_case (lowercase letters, numbers, underscores only)",
        [var_name]
    )
}

valid_snake_case(name) {
    regex.match("^[a-z][a-z0-9_]*$", name)
}
```

### 암호화 정책

```rego
# policies/encryption/kms_encryption.rego
package terraform.encryption

# S3 버킷은 반드시 KMS 암호화 사용
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    resource.change.actions[_] == "create"

    not has_kms_encryption(resource)

    msg := sprintf(
        "❌ S3 bucket '%s' must use KMS encryption (not AES256)",
        [resource.address]
    )
}

has_kms_encryption(resource) {
    resource.change.after.server_side_encryption_configuration[_].rule[_].apply_server_side_encryption_by_default[_].sse_algorithm == "aws:kms"
}

# RDS는 반드시 암호화 활성화
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_db_instance"
    resource.change.actions[_] == "create"

    not resource.change.after.storage_encrypted == true

    msg := sprintf(
        "❌ RDS instance '%s' must have storage encryption enabled",
        [resource.address]
    )
}

# CloudWatch Logs는 반드시 KMS 암호화
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_cloudwatch_log_group"
    resource.change.actions[_] == "create"

    not resource.change.after.kms_key_id

    msg := sprintf(
        "❌ CloudWatch Log Group '%s' must use KMS encryption",
        [resource.address]
    )
}
```

## 💰 4단계: 비용 분석 (Infracost)

### Infracost 설정

```yaml
# .github/workflows/infracost.yml
- name: Setup Infracost
  uses: infracost/actions/setup@v3
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Generate Infracost breakdown
  run: |
    infracost breakdown \
      --path=terraform/ \
      --format=json \
      --out-file=/tmp/infracost.json

- name: Post Infracost comment
  uses: infracost/actions/comment@v1
  with:
    path: /tmp/infracost.json
    behavior: update
```

### 실제 Infracost 출력 예시

````markdown
## 💰 Monthly cost estimate

```
Project: terraform/services/api-server

Name                                    Quantity  Unit         Monthly Cost
────────────────────────────────────────────────────────────────────────────
aws_db_instance.main
├─ Database instance (on-demand)             730  hours             $102.19
└─ Storage (general purpose SSD, gp3)        100  GB                 $11.50

aws_ecs_service.api
├─ Per GB per hour                           730  GB-hours           $73.00
└─ Per vCPU per hour                         730  vCPU-hours         $29.93

aws_lb.main
├─ Application load balancer                 730  hours              $16.43
└─ Load balancer capacity units              100  LCU-hours           $5.84

Total                                                               $238.89

────────────────────────────────────────────────────────────────────────────
Key: ~ changed, + added, - removed

Previous cost:                                                      $197.44  (was)
New cost:                                                          $238.89
Difference:                                                        +$41.45  (+21%)
```

**⚠️ Warning:** Monthly cost increase is +21% (+$41.45)
````

### 비용 임계값 설정

```yaml
# .github/workflows/terraform-plan.yml
- name: Check cost threshold
  run: |
    # Infracost JSON 파싱
    COST_CHANGE=$(jq '.diffTotalMonthlyCost' /tmp/infracost.json)
    COST_PERCENT=$(jq '.diffTotalMonthlyCostPercentage' /tmp/infracost.json)

    # 10% 이상 증가 시 경고
    if (( $(echo "$COST_PERCENT > 10" | bc -l) )); then
      echo "⚠️ WARNING: Cost increase is ${COST_PERCENT}%"
    fi

    # 30% 이상 증가 시 차단
    if (( $(echo "$COST_PERCENT > 30" | bc -l) )); then
      echo "❌ ERROR: Cost increase exceeds 30% threshold"
      exit 1
    fi
```

## 📝 PR 자동 코멘트 예시

### 모든 검증 통과 시

````markdown
## ✅ Terraform Validation Results

**Terraform Format:** ✅ PASSED
**Terraform Validate:** ✅ PASSED
**Security Scan (tfsec):** ✅ PASSED (0 issues)
**Policy Check (checkov):** ✅ PASSED (0 violations)
**OPA Policy:** ✅ PASSED
**Cost Analysis:** ✅ PASSED (+$12.50/month, +5%)

---

### 📋 Terraform Plan Summary
```
Plan: 2 to add, 0 to change, 0 to destroy.

Changes:
+ aws_security_group_rule.api_https
+ aws_cloudwatch_log_group.api_logs
```

### 💰 Cost Impact
```
Previous cost: $250.00/month
New cost:      $262.50/month
Difference:    +$12.50 (+5%)
```

### 🔍 Security Scan Results
- ✅ 0 critical issues
- ✅ 0 high issues
- ✅ 0 medium issues
- ✅ 0 low issues

---

**👍 All checks passed! Ready for review.**
````

### 검증 실패 시

````markdown
## ❌ Terraform Validation Failed

**Terraform Format:** ❌ FAILED
**Security Scan (tfsec):** ❌ FAILED (3 issues)
**Policy Check (OPA):** ❌ FAILED (2 violations)

---

### ❌ Issues Found

#### 1. Terraform Format
```diff
- resource "aws_vpc" "main" {
-     cidr_block = "10.0.0.0/16"
- }
+ resource "aws_vpc" "main" {
+   cidr_block = "10.0.0.0/16"
+ }
```

Run `terraform fmt -recursive terraform/` to fix.

#### 2. Security Issues (tfsec)

**CRITICAL: S3 bucket is not encrypted**
```
File: terraform/storage/s3.tf:10-15

resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
  # Missing: server_side_encryption_configuration
}
```

**Fix:**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}
```

#### 3. Policy Violations (OPA)

**Missing required tags:**
- ❌ Resource 'aws_vpc.main' is missing tags: ["CostCenter", "Owner"]

**Fix:**
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = merge(
    module.common_tags.tags,  # ← Use common tags module
    {
      Name = "prod-main-vpc"
    }
  )
}
```

---

**❌ Please fix the issues above before requesting review.**
````

## 🎓 로컬 개발 워크플로우

### Pre-commit Hook 설정

```bash
# 1. Pre-commit 설치
pip install pre-commit

# 2. .pre-commit-config.yaml 생성
cat > .pre-commit-config.yaml <<EOF
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_tfsec
      - id: terraform_checkov

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
EOF

# 3. Pre-commit 활성화
pre-commit install

# 4. 수동 실행 (모든 파일)
pre-commit run --all-files
```

### 로컬 검증 스크립트

```bash
#!/bin/bash
# scripts/validate-terraform.sh

set -e

echo "🔍 Starting Terraform validation..."

# 1. Format 검증
echo "1️⃣ Checking Terraform format..."
terraform fmt -check -recursive terraform/

# 2. Validate
echo "2️⃣ Running terraform validate..."
for dir in terraform/*/; do
  echo "Validating $dir"
  cd "$dir"
  terraform init -backend=false
  terraform validate
  cd -
done

# 3. tfsec
echo "3️⃣ Running tfsec..."
tfsec terraform/ --minimum-severity HIGH

# 4. checkov
echo "4️⃣ Running checkov..."
checkov -d terraform/ --framework terraform --quiet

# 5. OPA
echo "5️⃣ Running OPA policy tests..."
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
opa eval --data policies/ --input tfplan.json --format pretty "data.terraform.deny"

echo "✅ All validations passed!"
```

## 🚀 다음 단계

이제 자동화된 검증 파이프라인으로 안전하고 일관된 인프라 변경을 보장하는 방법을 배웠습니다.

**다음 글에서 다룰 내용:**
1. **프로덕션 운영 전략** - State 관리, 롤백, 재해 복구
2. **KMS 암호화 전략** - 데이터 클래스별 키 분리
3. **모니터링과 로깅** - CloudWatch, Prometheus, Grafana
4. **비상 대응 절차** - 장애 대응, 빠른 롤백

## 📚 참고 자료

- [tfsec 공식 문서](https://aquasecurity.github.io/tfsec/)
- [checkov 공식 문서](https://www.checkov.io/)
- [OPA 공식 문서](https://www.openpolicyagent.org/)
- [Infracost 공식 문서](https://www.infracost.io/)
- [프로젝트의 검증 워크플로우](../../.github/workflows/infra-checks.yml)

---

**이전 글:** [Terraform으로 인프라 코드화하기 (3편)](./03-terraform-modules.md)
**다음 글:** [프로덕션 운영과 보안 관리 (5편)](./05-production-operations-security.md)
