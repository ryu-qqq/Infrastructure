# 인프라 체크 워크플로우 사용 가이드

서비스 리포지토리에 중앙화된 인프라 체크 재사용 워크플로우를 통합하는 방법을 설명합니다.

## 개요

`infra-checks.yml` 재사용 워크플로우는 Terraform 인프라 코드에 대해 보안, 정책, 비용을 자동 검증합니다. 통합 도구:

- **tfsec**: 보안 취약점 스캔
- **checkov**: 정책 준수 검증(CIS, PCI-DSS, HIPAA, ISO 27001)
- **OPA/Conftest**: 커스텀 정책 강제
- **Infracost**: 비용 추정 및 예산 검증

## 사전 준비

### 필요한 도구

워크플로우가 필요한 도구를 자동 설치하지만, Terraform 코드는 올바르게 구성되어야 합니다:

1. 유효한 Terraform 구성 파일(`.tf`)
2. Terraform 1.6.0 호환 코드
3. (선택) 클라우드 공급자 검증을 위한 AWS 자격 증명

### 필요한 시크릿

리포지토리에 다음 시크릿을 설정하세요:

| Secret | 필요 여부 | 설명 |
|--------|-----------|------|
| `INFRACOST_API_KEY` | 비용 체크 시 필요 | [Infracost](https://www.infracost.io/) 에서 발급 |
| `AWS_ROLE_ARN` | AWS 리소스 검증 시 필요 | OIDC 인증용 IAM Role ARN |
| `GITHUB_TOKEN` | 자동 제공 | GitHub Actions 기본 토큰 |

## 기본 사용법

### 최소 구성

서비스 리포지토리에 `.github/workflows/terraform-validation.yml` 생성:

```yaml
name: Terraform Validation

on:
  pull_request:
    branches:
      - main
    paths:
      - 'terraform/**'
      - 'infrastructure/**'

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  infrastructure-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

기본 설정으로 모든 체크가 실행됩니다:
- ✅ tfsec 보안 스캔
- ✅ checkov 정책 검증
- ✅ Conftest OPA 정책
- ✅ Infracost 비용 추정
- ⚠️ Non-blocking(이슈를 보고하되 워크플로우는 실패 처리하지 않음)

### 커스텀 구성

입력 파라미터로 동작을 커스터마이즈하세요:

```yaml
jobs:
  infrastructure-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      # Terraform 디렉터리 경로
      terraform_directory: 'infrastructure/terraform'

      # 개별 체크 활성/비활성
      run_tfsec: true
      run_checkov: true
      run_conftest: true
      run_infracost: true

      # 비용 임계값
      cost_threshold_warning: 10   # 10% 증가 시 경고
      cost_threshold_block: 30     # 30% 증가 시 차단

      # 워크플로우 실패 조건
      fail_on_security_issues: false    # 보안 이슈로 실패 처리하지 않음
      fail_on_policy_violations: false  # 정책 위반으로 실패 처리하지 않음

    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

## 설정 옵션

### 입력 파라미터

| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| `terraform_directory` | string | `terraform` | Terraform 코드가 포함된 디렉터리 |
| `run_tfsec` | boolean | `true` | tfsec 보안 스캔 활성화 |
| `run_checkov` | boolean | `true` | checkov 정책 검증 활성화 |
| `run_conftest` | boolean | `true` | OPA/Conftest 검증 활성화 |
| `run_infracost` | boolean | `true` | 비용 추정 활성화 |
| `cost_threshold_warning` | number | `10` | 경고 임계 비율(%) |
| `cost_threshold_block` | number | `30` | 차단 임계 비율(%) |
| `fail_on_security_issues` | boolean | `false` | 보안 이슈 발생 시 워크플로우 실패 여부 |
| `fail_on_policy_violations` | boolean | `false` | 정책 위반 발생 시 워크플로우 실패 여부 |

### 워크플로우 동작 모드

#### Non-Blocking 모드(기본)
```yaml
fail_on_security_issues: false
fail_on_policy_violations: false
```

- ✅ 모든 체크가 완료까지 실행
- 📊 결과는 PR 코멘트로 보고
- ⚠️ 이슈는 표시되지만 병합은 차단하지 않음
- 💡 초기 도입 및 개발 환경에 적합

#### Blocking 모드(엄격)
```yaml
fail_on_security_issues: true
fail_on_policy_violations: true
```

- ❌ 심각/높음 보안 이슈 발생 시 워크플로우 실패
- ❌ 정책 위반 시 워크플로우 실패
- 🛑 문제 해결 전까지 PR 병합 불가
- 🔒 프로덕션 환경에 적합

## 사용 예시

### 예시 1: 개발 환경

빠른 반복을 위한 관대한 설정:

```yaml
jobs:
  dev-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      terraform_directory: 'terraform/dev'
      cost_threshold_warning: 25
      cost_threshold_block: 50
      fail_on_security_issues: false
      fail_on_policy_violations: false
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_DEV_ROLE_ARN }}
```

### 예시 2: 프로덕션 환경

안전을 위한 엄격한 설정:

```yaml
jobs:
  prod-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      terraform_directory: 'terraform/prod'
      cost_threshold_warning: 5
      cost_threshold_block: 15
      fail_on_security_issues: true
      fail_on_policy_violations: true
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_PROD_ROLE_ARN }}
```

### 예시 3: 보안 전용 체크

비용 분석은 생략하고 보안에 집중:

```yaml
jobs:
  security-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      run_tfsec: true
      run_checkov: true
      run_conftest: true
      run_infracost: false  # 비용 분석 생략
      fail_on_security_issues: true
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### 예시 4: 비용 분석 전용

비용 관리에 집중:

```yaml
jobs:
  cost-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      run_tfsec: false
      run_checkov: false
      run_conftest: false
      run_infracost: true
      cost_threshold_warning: 10
      cost_threshold_block: 20
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

### 예시 5: 멀티 환경 파이프라인

환경별로 서로 다른 체크 구성:

```yaml
name: Multi-Environment Validation

on:
  pull_request:
    branches: [main, develop]

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  dev-checks:
    if: github.base_ref == 'develop'
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      terraform_directory: 'terraform/dev'
      fail_on_security_issues: false
      fail_on_policy_violations: false
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_DEV_ROLE_ARN }}

  prod-checks:
    if: github.base_ref == 'main'
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    with:
      terraform_directory: 'terraform/prod'
      cost_threshold_block: 10
      fail_on_security_issues: true
      fail_on_policy_violations: true
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_PROD_ROLE_ARN }}
```

## 결과 이해하기

### PR 코멘트 형식

워크플로우는 PR 코멘트로 종합 리포트를 게시합니다:

```markdown
## 🛡️ Infrastructure Security & Compliance Report

<details><summary>🔒 Security Scan (tfsec)</summary>
✅ No security issues found!
</details>

<details><summary>📋 Policy Compliance (checkov)</summary>
✅ Passed: 45
❌ Failed: 2
⚠️ Action Required: Policy violations must be resolved.
</details>

<details><summary>⚖️ OPA Policy Validation (conftest)</summary>
✅ All OPA policies passed!
</details>

<details><summary>💰 Cost Impact (Infracost)</summary>
💰 Current: $125.50
📊 Previous: $100.00
📈 Increase: +$25.50 (+25.5%)
✅ Within acceptable thresholds
</details>
```

### 결과 해석

#### 보안 스캔(tfsec)
- **🚨 Critical**: 즉시 조치 필요, 반드시 수정
- **❌ High**: 심각 이슈, 가급적 빠른 수정 권장
- **⚠️ Medium**: 중간 위험, 검토 필요
- **ℹ️ Low**: 경미한 이슈, Non-blocking

#### 정책 준수(checkov)
- **✅ Passed**: 검증 통과
- **❌ Failed**: 정책 위반 발견
- **⊘ Skipped**: 적용 불가 또는 건너뜀

#### OPA 정책(Conftest)
- **✅ Passed**: 모든 커스텀 정책 충족
- **❌ Failed**: 정책 위반 발견

#### 비용 영향(Infracost)
- **✅ OK**: 허용 임계값 이내
- **⚠️ WARNING**: 비용 한계치 접근
- **🚫 BLOCKED**: 비용 임계치 초과

## 트러블슈팅

### 자주 발생하는 문제

#### 1. 워크플로우를 찾을 수 없음

**에러**: `Unable to resolve action ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main`

**해결**: Infrastructure 리포지토리에 해당 워크플로우 파일이 존재하고 참조가 올바른지 확인하세요.

#### 2. Infracost 실패

**에러**: `Infracost analysis failed`

**가능한 원인**:
- `INFRACOST_API_KEY` 시크릿 누락
- 삭제 전용 변경(비용 영향 없음)
- 설정만 변경(비용 영향 없음)

**해결**: 과금 리소스 변경이 있는지 확인하세요. 비과금 변경은 비용 추정을 생략합니다.

#### 3. AWS 인증 실패

**에러**: `Failed to configure AWS credentials`

**가능한 원인**:
- `AWS_ROLE_ARN` 시크릿 누락
- IAM Role 구성 오류
- OIDC 신뢰 관계 미설정

**해결**:
1. IAM Role 존재 확인
2. OIDC 신뢰 정책에 해당 리포지토리 포함 확인
3. Role 권한 확인

#### 4. 정책 검증 실패

**에러**: `Conftest policy validation failed`

**가능한 원인**:
- Terraform 코드가 커스텀 정책을 위반
- 정책 파일 부재
- Conftest 구성 누락

**해결**:
1. 워크플로우 로그에서 정책 위반 내역 확인
2. 리포지토리에 `conftest.toml` 존재 확인
3. `policies/` 디렉터리에 정책 파일 확인

#### 5. Terraform 초기화 실패

**에러**: `Terraform initialization failed`

**가능한 원인**:
- 잘못된 Terraform 구성
- 프로바이더 설정 누락
- 백엔드 설정 문제

**해결**:
1. 로컬에서 Terraform init 테스트
2. Terraform 버전 호환성 점검
3. 프로바이더 요구사항 확인

### 디버그 모드

문제 해결을 위한 상세 로그 활성화:

**단계별 디버그 로그**:

호출 리포지토리에서 `ACTIONS_STEP_DEBUG` 시크릿을 `true`로 설정해야 합니다.

1. 리포지토리 **Settings** → **Secrets and variables** → **Actions** 이동
2. `ACTIONS_STEP_DEBUG` 시크릿을 추가하고 값을 `true`로 설정
3. 워크플로우 재실행 후 디버그 로그 확인

**러너 진단 로그**:

리포지토리 시크릿 `ACTIONS_RUNNER_DEBUG` 를 `true`로 설정:
1. 리포지토리 **Settings** → **Secrets and variables** → **Actions**
2. 새 시크릿 생성: `ACTIONS_RUNNER_DEBUG` = `true`
3. 워크플로우 재실행

**참고**: 두 디버그 모드는 호출 워크플로우의 env가 재사용 워크플로우로 전달되지 않기 때문에, 워크플로우 파일의 환경변수가 아니라 리포지토리 시크릿으로만 활성화할 수 있습니다.

## 모범 사례

### 1. Non-Blocking으로 시작

베이스라인 이슈 파악을 위해 Non-Blocking 모드로 시작하세요:

```yaml
fail_on_security_issues: false
fail_on_policy_violations: false
```

### 2. 점진적 엄격화

시간 경과에 따라 엄격도를 높이세요:

1. **1주차**: 모든 체크 실행, Non-Blocking
2. **2주차**: 기존 이슈 해결
3. **3주차**: `fail_on_security_issues` 활성화
4. **4주차**: `fail_on_policy_violations` 활성화

### 3. 환경별 설정

프로덕션으로 갈수록 엄격하게:

- **Development**: 관대(빠른 피드백)
- **Staging**: 중간(조기 이슈 포착)
- **Production**: 엄격(컴플라이언스 보장)

### 4. 비용 모니터링

현실적인 임계값 설정:

- **경고 임계값**: 10% (검토 필요)
- **차단 임계값**: 30% (승인 필요)

조직의 예산 정책에 따라 조정하세요.

### 5. 정책 커스터마이징

서비스 리포지토리에서 커스텀 OPA 정책을 작성하세요:

```bash
service-repo/
├── policies/
│   ├── naming/
│   │   └── naming.rego
│   ├── tagging/
│   │   └── tags.rego
│   └── security/
│       └── security_groups.rego
└── conftest.toml
```

### 6. 버전 고정(권장)

**프로덕션 환경에서는 항상 특정 버전에 고정하세요:**

```yaml
# ✅ 권장: 특정 버전에 고정하여 안정성과 재현성 보장
uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@v1.0.0

# ✅ 대안: 특정 커밋 SHA에 고정하여 최대 안정성 확보
actions: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@a1b2c3d

# ⚠️ 프로덕션 비권장: @main 은 파괴적 변경을 포함할 수 있음
# 최신 기능을 원하는 개발/테스트 환경에서만 사용 권장
uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
```

**버전 고정의 이점:**
- **예측 가능한 빌드**: 실행마다 동일한 워크플로우 버전으로 돌발 실패 방지
- **파괴적 변경 보호**: 자동 업데이트로 인한 파이프라인 붕괴 방지
- **변경 통제**: 업데이트를 채택하기 전에 리뷰/테스트 가능
- **롤백 용이성**: 문제 발생 시 이전 버전으로 즉시 복귀 가능

**업데이트 전략:**
1. Infrastructure 리포지토리의 릴리즈 모니터링
2. 개발 환경에서 신버전 테스트
3. 검증 후 버전 참조 업데이트
4. 변경 로그에 버전 업데이트 기록

## 다른 워크플로우와의 통합

### Terraform Apply와 결합

검증 후 변경을 적용하려면 `push` to `main` 트리거의 별도 워크플로우를 사용하세요:

**검증 워크플로우**(`.github/workflows/terraform-validation.yml`):
```yaml
name: Terraform Validation

on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  validate:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}
```

**적용 워크플로우**(`.github/workflows/terraform-apply.yml`):
```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'

permissions:
  contents: read
  id-token: write

jobs:
  terraform-apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Apply
        working-directory: terraform
        run: |
          terraform init
          terraform apply -auto-approve
```

### 다른 체크와 병렬 실행

```yaml
jobs:
  infrastructure-checks:
    uses: ryu-qqq/Infrastructure/.github/workflows/infra-checks.yml@main
    secrets:
      INFRACOST_API_KEY: ${{ secrets.INFRACOST_API_KEY }}
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN }}

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Tests
        run: npm test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: npm run lint
```

## 지원 및 기여

### 도움 받기

- **문서**: [Infrastructure Governance](../governance/infrastructure_governance.md)
- **이슈**: Infrastructure 리포지토리에 이슈 등록
- **정책 가이드**: [Checkov Policy Guide](../governance/CHECKOV_POLICY_GUIDE.md)

### 기여하기

워크플로우 개선 제안을 하려면:

1. Infrastructure 리포지토리를 포크
2. 기능 브랜치 생성
3. `.github/workflows/infra-checks.yml` 변경
4. 서비스 리포지토리에서 테스트
5. Pull Request 제출

## 버전 이력

| 버전 | 날짜 | 변경 |
|------|------|------|
| 1.0.0 | 2024-01 | tfsec, checkov, conftest, infracost 포함 초기 릴리스 |

## 추가 자료

- [tfsec 문서](https://aquasecurity.github.io/tfsec/)
- [checkov 문서](https://www.checkov.io/documentation.html)
- [Conftest 문서](https://www.conftest.dev/)
- [Infracost 문서](https://www.infracost.io/docs/)
- [GitHub Actions 재사용 워크플로우](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
