# OPA Policy Integration Guide

**목적**: Terraform 인프라 코드에 대한 다층 거버넌스 검증 시스템 구축

이 가이드는 OPA(Open Policy Agent) 정책을 세 가지 레이어에서 통합하는 방법을 설명합니다:
1. **로컬 개발**: Pre-commit hook (빠른 피드백)
2. **PR 리뷰**: Atlantis (팀 협업)
3. **CI/CD**: GitHub Actions (최종 보안 게이트)

---

## 개요

### 왜 세 가지 레이어가 필요한가?

**다층 방어(Defense in Depth)** 전략으로 각 단계에서 정책 위반을 조기에 발견합니다:

| 레이어 | 시점 | 피드백 속도 | 대상 | 우회 가능 |
|--------|------|------------|------|----------|
| **Pre-commit** | 커밋 전 | 1-2초 | 개발자 개인 | Yes (--no-verify) |
| **Atlantis** | PR plan 실행 시 | 30초-1분 | 팀원 전체 | No |
| **GitHub Actions** | PR 생성/업데이트 시 | 1-2분 | 전체 파이프라인 | No |

### 정책 검증 범위

현재 `policies/` 디렉토리의 OPA 정책:
- ✅ **필수 태그 검증** (`tagging/`) - 7개 필수 태그
- ✅ **네이밍 규약** (`naming/`) - kebab-case 강제
- ✅ **보안 그룹 규칙** (`security_groups/`) - SSH/RDP 인터넷 노출 방지
- ✅ **공개 리소스 제한** (`public_resources/`) - RDS, S3 공개 접근 차단

---

## 1. 로컬 개발: Pre-commit Hook

### 특징
- ⚡ **가장 빠른 피드백**: 1-2초
- 🎯 **로컬 검증**: 커밋하기 전에 문제 발견
- 🔧 **선택적**: 필요시 `--no-verify`로 우회 가능

### 설치 방법

#### 자동 설치 (권장)
```bash
# 프로젝트 루트에서 실행
./scripts/setup-hooks.sh
```

이 스크립트는 자동으로:
- Pre-commit hook을 `.git/hooks/pre-commit`에 설치
- 실행 권한 부여
- Conftest 설치 확인

#### 수동 설치
```bash
# Pre-commit hook 복사
cp scripts/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Conftest 설치 (macOS)
brew install conftest

# Conftest 설치 (Linux)
CONFTEST_VERSION=0.49.1
curl -L "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/conftest /usr/local/bin/
```

### 동작 방식

1. **파일 감지**: staged된 `.tf` 파일 탐지
2. **Terraform 검증**: fmt, validate 실행
3. **Plan 생성**: 임시 plan 생성 (백엔드 없이)
4. **정책 검증**: Conftest로 OPA 정책 적용
5. **결과 보고**: 통과/실패 결과 출력

### 사용 예시

```bash
# 정상적인 커밋
$ git add terraform/monitoring/main.tf
$ git commit -m "Add monitoring resources"

🔍 Running pre-commit checks...

📝 Checking Terraform formatting...
✓ terraform/monitoring/main.tf

🔒 Scanning for sensitive information...
✓ No sensitive information detected

✅ Running terraform validate...
Validating: terraform/monitoring
✓ terraform/monitoring is valid

📜 Running OPA policy validation...
Validating policies: terraform/monitoring
✓ OPA policies passed for terraform/monitoring

✓ All pre-commit checks passed!
```

```bash
# 정책 위반이 있는 경우
$ git commit -m "Add resources without tags"

📜 Running OPA policy validation...
Validating policies: terraform/monitoring
✗ OPA policy validation failed: terraform/monitoring

FAIL - terraform/monitoring/main.tf - Required tags missing: [Owner, CostCenter, Environment]

✗ 1 error(s) found
💡 Fix errors above or use: git commit --no-verify
⚠  Using --no-verify is not recommended
```

### 우회 방법 (긴급 상황)
```bash
# 정책 검증 건너뛰기 (권장하지 않음)
git commit --no-verify -m "Emergency fix"
```

---

## 2. PR 리뷰: Atlantis

### 특징
- 🤝 **팀 협업**: PR plan 결과를 팀원과 공유
- 📋 **자동 실행**: PR에 Terraform 변경사항이 있으면 자동 실행
- 🚫 **우회 불가능**: 정책 실패 시 apply 불가

### 설정 완료 사항

Atlantis에 OPA policy 검증이 이미 통합되어 있습니다:

#### `atlantis.yaml` 설정
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

#### `docker/Dockerfile` - Conftest 설치
```dockerfile
# Install conftest for OPA policy validation
ARG CONFTEST_VERSION=0.49.1
RUN curl -L "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
    | tar xz -C /tmp && \
    mv /tmp/conftest /usr/local/bin/ && \
    chmod +x /usr/local/bin/conftest && \
    conftest --version
```

### 동작 방식

1. **PR 생성**: Terraform 파일 변경 감지
2. **Atlantis Plan**: `atlantis plan` 자동 실행
3. **정책 검증**: Plan 이후 자동으로 Conftest 실행
4. **결과 코멘트**: PR에 검증 결과 자동 게시
5. **Apply 제어**: 정책 실패 시 apply 차단

### PR 코멘트 예시

```markdown
#### Atlantis Plan Output

✅ Terraform Plan Successful

📜 OPA Policy Validation
✅ All policies passed
- ✓ Required tags present
- ✓ Naming conventions followed
- ✓ No public resource exposure
- ✓ Security group rules valid

Plan: 3 to add, 1 to change, 0 to destroy
```

### 재배포 필요

Atlantis Docker 이미지를 재빌드하고 배포해야 합니다:

```bash
# Docker 이미지 빌드 및 푸시
./scripts/build-and-push.sh

# ECS 서비스 업데이트 (자동 배포)
# 또는 Atlantis terraform apply
cd terraform/atlantis
terraform apply
```

---

## 3. CI/CD: GitHub Actions

### 특징
- 🔒 **최종 보안 게이트**: 모든 PR이 통과해야 함
- 📊 **상세한 리포트**: 정책 위반 세부사항 제공
- 🚫 **우회 불가능**: Admin도 우회 불가

### 설정 완료 사항

GitHub Actions workflow에 OPA policy 검증이 통합되어 있습니다.

#### `.github/workflows/terraform-plan.yml` 주요 단계

**1. Conftest 설치**
```yaml
- name: Install Security Scanners
  run: |
    # Install conftest for OPA policy validation
    CONFTEST_VERSION=0.49.1
    curl -L "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
      | tar xz -C /tmp
    sudo mv /tmp/conftest /usr/local/bin/
    conftest --version
```

**2. 모듈별 정책 검증**
```yaml
# Monitoring 모듈
- name: Terraform Plan - Monitoring
  run: |
    terraform plan -out=tfplan
    terraform show -json tfplan > tfplan-monitoring.json

- name: OPA Policy Validation - Monitoring
  run: |
    conftest test tfplan-monitoring.json \
      --config ../../conftest.toml \
      --output json > conftest-monitoring.json
```

**3. PR 코멘트**
```yaml
- name: Comment Plan on PR
  uses: actions/github-script@v7
  with:
    script: |
      // Parse conftest results
      // Add to PR comment
```

### 동작 방식

1. **PR 생성/업데이트**: Terraform 변경 감지
2. **병렬 실행**: 모든 모듈 동시 검증
3. **정책 검증**: 각 모듈 plan에 대해 Conftest 실행
4. **결과 집계**: 모든 모듈 결과 통합
5. **PR 코멘트**: 상세한 검증 결과 게시

### PR 코멘트 예시

```markdown
#### Terraform Plan 📋

<details><summary>📜 OPA Policy Validation (Conftest)</summary>

**OPA Policy Validation Summary:**
✅ Passed: 45
❌ Failed: 2
⚠️ Warnings: 1

**Module Breakdown:**
- Monitoring: 23 passed, 1 failed
- Atlantis: 22 passed, 1 failed, 1 warnings

⚠️ **Action Required:** OPA policy violations must be resolved.
📚 Review policies in `policies/` directory for details.

**Failed Policies:**
1. **monitoring** - Required tag missing: CostCenter
2. **atlantis** - Security group allows SSH from 0.0.0.0/0

</details>
```

---

## 정책 수정 및 테스트

### 정책 파일 위치
```
policies/
├── tagging/
│   ├── tagging.rego          # 태그 정책
│   └── tagging_test.rego     # 테스트
├── naming/
│   ├── naming.rego           # 네이밍 정책
│   └── naming_test.rego
├── security_groups/
│   ├── security_groups.rego
│   └── security_groups_test.rego
└── public_resources/
    ├── public_resources.rego
    └── public_resources_test.rego
```

### 정책 테스트 실행

```bash
# 전체 정책 테스트
opa test policies/ -v

# 특정 정책 테스트
opa test policies/tagging/ -v

# Conftest로 실제 plan 테스트
terraform plan -out=tfplan
terraform show -json tfplan > tfplan.json
conftest test tfplan.json --config conftest.toml
```

### 정책 추가 방법

1. **정책 파일 작성** (`policies/my_policy/my_policy.rego`)
```rego
package main

deny[msg] {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not resource.values.versioning[0].enabled
    msg := sprintf("S3 bucket %s must have versioning enabled", [resource.name])
}
```

2. **테스트 작성** (`policies/my_policy/my_policy_test.rego`)
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

3. **conftest.toml 업데이트**
```toml
# 새 정책 디렉토리 추가
policy = ["policies/tagging", "policies/naming", "policies/my_policy"]
```

4. **테스트 실행**
```bash
opa test policies/my_policy/ -v
```

---

## 트러블슈팅

### Pre-commit Hook

**문제**: Conftest not found
```bash
⚠ Conftest not installed, skipping OPA policy validation
```
**해결**:
```bash
# macOS
brew install conftest

# Linux
curl -L "https://github.com/open-policy-agent/conftest/releases/download/v0.49.1/conftest_0.49.1_Linux_x86_64.tar.gz" \
  | tar xz -C /tmp
sudo mv /tmp/conftest /usr/local/bin/
```

**문제**: Terraform not initialized
```bash
⚠ Terraform not initialized in terraform/monitoring, skipping policy validation
```
**해결**:
```bash
cd terraform/monitoring
terraform init
```

### Atlantis

**문제**: Conftest command not found in Atlantis
```bash
/bin/sh: conftest: not found
```
**해결**:
```bash
# Docker 이미지 재빌드 필요
./scripts/build-and-push.sh

# ECS 서비스 업데이트
cd terraform/atlantis
terraform apply
```

**문제**: Policy file not found
```bash
Error: conftest.toml not found
```
**해결**: `conftest.toml`이 repository root에 있는지 확인
```bash
ls -la conftest.toml
```

### GitHub Actions

**문제**: Conftest 설치 실패
```bash
curl: (22) The requested URL returned error: 404
```
**해결**: `.github/workflows/terraform-plan.yml`에서 CONFTEST_VERSION 확인

**문제**: JSON parsing error
```bash
Error: invalid character '<' looking for beginning of value
```
**해결**: terraform show -json 단계가 성공했는지 확인

---

## 모범 사례

### 1. 점진적 롤아웃
- ⚠️ **처음에는 경고만**: 정책을 `warn`으로 시작
- ✅ **팀 교육 후 강제**: 팀이 익숙해진 후 `deny`로 변경

### 2. 정책 우선순위
- 🔴 **Critical**: 보안 취약점 (즉시 차단)
- 🟡 **High**: 필수 태그, 네이밍 (2주 유예)
- 🟢 **Medium**: 권장사항 (경고만)

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
- 📢 **정책 변경 공지**: 최소 1주 전 공지
- 📚 **문서화**: 각 정책의 이유와 해결 방법 문서화
- 🎓 **교육**: 정책 위반 시 가이드 제공

---

## 다음 단계

1. ✅ **설치 확인**: 세 가지 레이어 모두 정상 동작 확인
2. 📊 **모니터링**: 정책 위반 빈도 추적
3. 🔧 **정책 개선**: 팀 피드백 기반 정책 조정
4. 📈 **확장**: 새로운 정책 추가 (비용 최적화, 성능 등)

---

## 참고 자료

- [OPA 공식 문서](https://www.openpolicyagent.org/docs/latest/)
- [Conftest 문서](https://www.conftest.dev/)
- [Rego 언어 가이드](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [프로젝트 policies/README.md](../../policies/README.md)
- [Atlantis Workflow 문서](https://www.runatlantis.io/docs/custom-workflows.html)
