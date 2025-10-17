# GitHub Actions Setup Guide

GitHub Actions를 통한 Terraform 및 Docker 이미지 배포 자동화 설정 가이드입니다.

## 목차
- [AWS OIDC 설정](#aws-oidc-설정)
- [GitHub Secrets 설정](#github-secrets-설정)
- [워크플로우 구조](#워크플로우-구조)
- [이미지 태그 전략](#이미지-태그-전략)
- [트러블슈팅](#트러블슈팅)

## AWS OIDC 설정

GitHub Actions에서 AWS에 안전하게 접근하기 위해 OIDC(OpenID Connect)를 사용합니다.

### 1. IAM Identity Provider 생성

**이미 생성되어 있습니다:**
```
ARN: arn:aws:iam::646886795421:oidc-provider/token.actions.githubusercontent.com
```

만약 생성이 안되어 있다면:
```bash
# AWS Console에서:
# IAM > Identity providers > Add provider
# Provider type: OpenID Connect
# Provider URL: https://token.actions.githubusercontent.com
# Audience: sts.amazonaws.com
```

### 2. IAM Role 생성

**Trust Policy** (`github-actions-trust-policy.json`):

**중요**: `{GITHUB_ORG}/{REPO_NAME}` 부분을 실제 저장소 경로로 변경하세요.
예: `ryu-qqq/Infrastructure`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::646886795421:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:ryu-qqq/Infrastructure:*"
        }
      }
    }
  ]
}
```

**Permissions Policy** (`github-actions-permissions.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-bucket",
        "arn:aws:s3:::terraform-state-bucket/*"
      ]
    },
    {
      "Sid": "DynamoDBLockAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-lock"
    },
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:CreateRepository",
        "ecr:DescribeImages",
        "ecr:DescribeImageScanFindings"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KMSAccess",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformResourceManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "iam:GetRole",
        "iam:ListRoles",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. Role 생성 명령어

먼저 위의 Trust Policy와 Permissions Policy를 파일로 저장하세요:
- `github-actions-trust-policy.json`
- `github-actions-permissions.json`

그 다음 아래 명령어를 실행:

```bash
# 1. Trust policy로 role 생성
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-actions-trust-policy.json

# 2. Permissions policy attach
aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPermissions \
  --policy-document file://github-actions-permissions.json

# 3. Role ARN 확인 (이 값을 GitHub Secrets에 추가)
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
```

**예상 출력 (GitHub Secrets의 AWS_ROLE_ARN 값으로 사용):**
```
arn:aws:iam::646886795421:role/GitHubActionsRole
```

## GitHub Secrets 설정

Repository Settings > Secrets and variables > Actions에서 설정:

### Required Secrets

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_ROLE_ARN` | GitHub Actions가 assume할 IAM Role ARN | `arn:aws:iam::646886795421:role/GitHubActionsRole` |

**설정 방법:**
1. GitHub 저장소 → Settings → Secrets and variables → Actions
2. "New repository secret" 클릭
3. Name: `AWS_ROLE_ARN`
4. Secret: 위에서 생성한 Role ARN 입력
5. "Add secret" 클릭

### Optional Variables (Environment Variables)

| Variable Name | Description | Default |
|--------------|-------------|---------|
| `AWS_REGION` | AWS 리전 | `ap-northeast-2` |
| `ECR_REPOSITORY` | ECR 리포지토리 이름 | `atlantis` |

## 워크플로우 구조

### 1. Terraform Plan (PR 생성/업데이트 시)

**Trigger**: Pull Request to `main`
**File**: `.github/workflows/terraform-plan.yml`

**실행 단계**:
1. ✅ Governance validators 실행
2. ✅ Terraform format 검증
3. ✅ Terraform init & validate
4. ✅ Terraform plan 실행
5. ✅ Plan 결과를 PR 코멘트로 표시

### 2. Terraform Apply & Deploy (PR 머지 시)

**Trigger**: Push to `main`
**File**: `.github/workflows/terraform-apply-and-deploy.yml`

**실행 단계**:
1. ✅ Terraform apply (ECR 생성)
2. ✅ AWS ECR 로그인
3. ✅ Docker 이미지 빌드
4. ✅ ECR에 이미지 푸시 (다중 태그)
5. ✅ 이미지 스캔 결과 확인

## 이미지 태그 전략

모든 이미지는 **3가지 태그**로 푸시됩니다:

### 1. Git Commit SHA (Primary)
```
{account-id}.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:a1b2c3d
```
- **용도**: 정확한 버전 추적
- **형식**: Git commit SHA 앞 7자리
- **불변성**: ✅ 동일 태그 재사용 불가
- **권장 사용**: Production 배포

### 2. Latest (Development)
```
{account-id}.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:latest
```
- **용도**: 최신 버전 참조
- **업데이트**: 매 배포마다 덮어씌움
- **불변성**: ❌ 항상 최신 이미지를 가리킴
- **권장 사용**: Development/Staging 환경

### 3. Timestamp (Backup)
```
{account-id}.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:20250110-143022
```
- **용도**: 시간 기반 버전 추적
- **형식**: `YYYYMMDD-HHMMSS` (UTC)
- **불변성**: ✅ 고유한 타임스탬프
- **권장 사용**: 디버깅, 롤백

### 태그 사용 예시

```bash
# ECS Task Definition에서 사용 (권장: Git SHA)
"image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:a1b2c3d"

# Development/Staging 환경 (latest)
"image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:latest"

# 특정 시점으로 롤백 (timestamp)
"image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/atlantis:20250110-143022"
```

## 워크플로우 테스트

### 1. PR 생성하여 Plan 테스트

```bash
# Feature 브랜치 생성
git checkout -b test/github-actions

# 변경사항 커밋
git add .
git commit -m "test: GitHub Actions workflow"
git push origin test/github-actions

# PR 생성
gh pr create --base main --title "Test: GitHub Actions"
```

**예상 결과**:
- ✅ Governance validators 통과
- ✅ Terraform plan 성공
- ✅ PR에 plan 결과 코멘트 표시

### 2. PR 머지하여 Apply & Deploy 테스트

```bash
# PR 머지
gh pr merge --squash

# Actions 탭에서 워크플로우 실행 확인
gh workflow view "Terraform Apply and Deploy"
```

**예상 결과**:
- ✅ ECR 리포지토리 생성
- ✅ Docker 이미지 빌드 성공
- ✅ ECR에 3개 태그로 푸시 완료
- ✅ 이미지 스캔 시작

### 3. ECR 이미지 확인

```bash
# ECR 리포지토리 확인
aws ecr describe-repositories \
  --repository-names atlantis \
  --region ap-northeast-2

# 이미지 목록 확인
aws ecr describe-images \
  --repository-name atlantis \
  --region ap-northeast-2

# 이미지 스캔 결과 확인
aws ecr describe-image-scan-findings \
  --repository-name atlantis \
  --image-id imageTag=latest \
  --region ap-northeast-2
```

## 트러블슈팅

### Issue 1: AWS 인증 실패
```
Error: Failed to assume role
```

**해결 방법**:
1. IAM Identity Provider가 올바르게 설정되었는지 확인
2. Trust Policy의 GitHub repository 경로 확인
3. Role ARN이 GitHub Secrets에 올바르게 설정되었는지 확인

### Issue 2: Terraform 상태 잠금 오류
```
Error: Error acquiring the state lock
```

**해결 방법**:
```bash
# DynamoDB 잠금 테이블 확인
aws dynamodb get-item \
  --table-name terraform-lock \
  --key '{"LockID": {"S": "terraform-state-bucket/atlantis/terraform.tfstate-md5"}}'

# 필요시 수동으로 잠금 해제
aws dynamodb delete-item \
  --table-name terraform-lock \
  --key '{"LockID": {"S": "terraform-state-bucket/atlantis/terraform.tfstate-md5"}}'
```

### Issue 3: ECR 푸시 권한 오류
```
Error: denied: User is not authorized to perform ecr:PutImage
```

**해결 방법**:
1. IAM Role의 ECR 권한 확인
2. ECR 리포지토리 정책 확인
3. KMS 키 권한 확인 (암호화 사용 시)

### Issue 4: Docker 빌드 실패
```
Error: failed to solve: failed to compute cache key
```

**해결 방법**:
1. Dockerfile 경로 확인 (`./docker/Dockerfile`)
2. Build context 확인 (repository root)
3. GitHub Actions runner의 디스크 공간 확인

## 보안 고려사항

### 1. Least Privilege Principle
- IAM Role은 필요한 최소한의 권한만 부여
- 리소스별 ARN 명시 (와일드카드 최소화)

### 2. Secret Management
- AWS credentials는 절대 하드코딩하지 않음
- GitHub Secrets 사용
- OIDC 방식으로 temporary credentials 사용

### 3. 이미지 스캔
- ECR 이미지 스캔 자동 활성화
- Critical/High 취약점 발견 시 배포 중단 고려

### 4. Terraform 상태 보안
- S3 버킷 암호화 활성화
- 버전 관리 활성화
- 접근 로그 활성화

## 다음 단계

1. ✅ AWS OIDC 설정
2. ✅ GitHub Secrets 설정
3. ✅ PR 생성하여 Plan 테스트
4. ✅ PR 머지하여 Deploy 테스트
5. ✅ ECR 이미지 확인
6. 🔄 ECS Task Definition 업데이트 (이미지 태그 반영)
7. 🔄 모니터링 및 알림 설정
