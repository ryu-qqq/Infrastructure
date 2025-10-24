# GitHub Actions IAM Policies

GitHub Actions에서 사용하는 IAM 역할 및 정책 문서

## 📋 정책 파일

### 1. github-actions-trust-policy.json
**용도**: GitHub Actions OIDC Trust Policy

GitHub Actions에서 AWS 리소스에 접근하기 위한 신뢰 정책 (Trust Policy)

- **Principal**: `token.actions.githubusercontent.com`
- **Condition**: 특정 레포지토리에서만 assume role 허용

### 2. github-actions-permissions.json
**용도**: GitHub Actions IAM Permissions Policy

GitHub Actions에서 필요한 AWS 권한 정의

**주요 권한**:
- ECS 관리 (Task Definition, Service 업데이트)
- ECR 이미지 푸시
- S3 접근 (Terraform State)
- KMS 암호화/복호화
- IAM PassRole

### 3. github-actions-role-policy-update.json
**용도**: GitHub Actions 역할 정책 업데이트 버전

`github-actions-permissions.json`의 확장 버전으로, 추가 권한 포함

**추가 권한**:
- RDS 접근
- Secrets Manager 읽기
- SSM Parameter Store 접근

## 🔧 사용 방법

### Terraform에서 IAM 역할 생성

```hcl
# Trust Policy
data "local_file" "github_actions_trust_policy" {
  filename = "${path.module}/../../../docs/governance/iam-policies/github-actions-trust-policy.json"
}

# IAM Role
resource "aws_iam_role" "github_actions" {
  name               = "github-actions-role"
  assume_role_policy = data.local_file.github_actions_trust_policy.content
}

# Permissions Policy
data "local_file" "github_actions_permissions" {
  filename = "${path.module}/../../../docs/governance/iam-policies/github-actions-permissions.json"
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-permissions"
  role   = aws_iam_role.github_actions.id
  policy = data.local_file.github_actions_permissions.content
}
```

### GitHub Actions에서 사용

```yaml
# .github/workflows/terraform-apply.yml
permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-role
          aws-region: ap-northeast-2
```

## 📖 관련 문서

- [Infrastructure Governance](../infrastructure_governance.md)
- [GitHub Actions 워크플로](.github/workflows/)
- [Terraform Bootstrap](../../../terraform/bootstrap/)

## ⚠️ 보안 주의사항

1. **최소 권한 원칙**: 필요한 권한만 부여
2. **Trust Policy 조건**: 특정 레포지토리/브랜치로 제한
3. **정기 검토**: 분기별 권한 검토 및 최적화
4. **감사 로그**: CloudTrail을 통한 모든 작업 기록

## 🔄 업데이트 이력

- **2025-10-24**: docs/governance/iam-policies/로 이동
- **2025-10-14**: github-actions-role-policy-update.json 추가 (RDS, Secrets Manager 권한)
- **2025-10-12**: 초기 정책 생성
