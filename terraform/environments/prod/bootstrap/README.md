# Production Bootstrap Infrastructure

**버전**: 1.0.0
**환경**: Production
**리전**: ap-northeast-2 (Seoul)

> **중요**: 이 스택은 Terraform 자체의 state를 관리하는 bootstrap 스택입니다.
> 다른 모든 스택이 의존하는 기반 인프라로, 순환 참조 문제를 고려한 특별한 배포 절차가 필요합니다.

---

## 📋 목차

- [개요](#개요)
- [아키텍처](#아키텍처)
- [부트스트랩 순환 참조 문제](#부트스트랩-순환-참조-문제)
- [리소스 목록](#리소스-목록)
- [변수 설정](#변수-설정)
- [출력값](#출력값)
- [배포 방법](#배포-방법)
- [운영 가이드](#운영-가이드)
- [문제 해결](#문제-해결)

---

## 개요

Production 환경의 Terraform 백엔드 및 CI/CD 인프라를 관리하는 bootstrap 스택입니다.

### 주요 특징

- **Terraform State 관리**: S3 버킷과 DynamoDB 테이블을 통한 안전한 state 관리
- **State 암호화**: KMS 고객 관리형 키를 통한 state 파일 암호화
- **State 버전 관리**: S3 버저닝으로 state 파일 변경 이력 추적
- **State 잠금**: DynamoDB를 통한 동시 실행 방지
- **GitHub Actions 통합**: OIDC 기반 안전한 CI/CD 권한 관리
- **순환 참조 해결**: 특별한 초기 부트스트랩 절차로 순환 참조 문제 해결

### 사용 모듈

| 모듈 | 버전 | 용도 |
|------|------|------|
| `../../modules/s3-bucket` | v1.0.0 | Terraform state S3 버킷 생성 |
| `../../modules/iam-role-policy` | v1.0.0 | GitHub Actions IAM 역할 관리 |

---

## 아키텍처

### 전체 구조

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Bootstrap Infrastructure                         │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    Terraform Backend                          │   │
│  │                                                                │   │
│  │  ┌──────────────┐      ┌──────────────┐     ┌─────────────┐  │   │
│  │  │   S3 Bucket  │      │  DynamoDB    │     │  KMS Key    │  │   │
│  │  │              │      │              │     │             │  │   │
│  │  │ prod-connectly──────│ terraform-   │◄────│ Customer    │  │   │
│  │  │              │      │ lock table   │     │ Managed     │  │   │
│  │  │ [versioning] │      │ [PAY_PER_    │     │ Key         │  │   │
│  │  │ [encrypted]  │      │  REQUEST]    │     │ [rotation]  │  │   │
│  │  └──────────────┘      └──────────────┘     └─────────────┘  │   │
│  │                                                                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    GitHub Actions OIDC                        │   │
│  │                                                                │   │
│  │  ┌──────────────────────────────────────────────────────┐    │   │
│  │  │ GitHubActionsRole (iam-role-policy module)           │    │   │
│  │  │                                                       │    │   │
│  │  │ Trust Policy:                                        │    │   │
│  │  │  - token.actions.githubusercontent.com (OIDC)       │    │   │
│  │  │  - Repository: ryu-qqq/Infrastructure, fileflow     │    │   │
│  │  │                                                       │    │   │
│  │  │ Inline Policies:                                     │    │   │
│  │  │  - terraform-state: S3 + DynamoDB access            │    │   │
│  │  │  - ssm-access: SSM Parameter Store                  │    │   │
│  │  │  - kms-access: KMS 암호화/복호화                      │    │   │
│  │  │  - resource-management: VPC, ECS, IAM               │    │   │
│  │  │                                                       │    │   │
│  │  │ Managed Policy Attachment:                           │    │   │
│  │  │  - GitHubActionsFileFlowPolicy (ElastiCache, etc.)  │    │   │
│  │  └──────────────────────────────────────────────────────┘    │   │
│  │                                                                │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                               │
                               │ Used by all other stacks
                               │
                      ┌────────▼────────┐
                      │  Other Stacks   │
                      │  (network,      │
                      │   security,     │
                      │   monitoring)   │
                      └─────────────────┘
```

### State 관리 흐름

```
┌──────────────────┐
│ Terraform Init   │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│ 1. S3 Backend Configuration                          │
│    - bucket: prod-connectly                          │
│    - key: {stack}/terraform.tfstate                  │
│    - dynamodb_table: prod-connectly-tf-lock          │
│    - kms_key_id: alias/terraform-state               │
└────────┬─────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│ 2. State Lock Acquisition (DynamoDB)                 │
│    - LockID: "prod-connectly/{stack}/terraform.tfstate" │
│    - Prevents concurrent Terraform runs              │
└────────┬─────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│ 3. State File Download from S3                       │
│    - Encrypted with KMS                              │
│    - Versioned (90-day noncurrent retention)        │
└────────┬─────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│ 4. Terraform Operation (plan/apply)                  │
└────────┬─────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│ 5. State File Upload to S3 (encrypted)               │
└────────┬─────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────┐
│ 6. State Lock Release (DynamoDB)                     │
└──────────────────────────────────────────────────────┘
```

---

## 부트스트랩 순환 참조 문제

### 문제 정의

Bootstrap 스택은 Terraform의 "닭이 먼저냐, 달걀이 먼저냐" 문제를 가지고 있습니다:

1. **Terraform state는 S3에 저장되어야 함**
2. **S3 버킷은 Terraform으로 생성해야 함**
3. **하지만 Terraform이 S3 버킷을 생성하려면 state를 어딘가에 저장해야 함**

이것이 바로 **순환 참조(Circular Dependency)** 문제입니다.

### 해결 전략

Bootstrap 스택은 2단계 배포 절차를 통해 이 문제를 해결합니다:

#### 1단계: 로컬 State로 초기 리소스 생성
```bash
# backend.tf를 주석 처리하거나 삭제
# Terraform이 로컬 state를 사용하도록 설정

terraform init
terraform apply
# → S3 버킷, DynamoDB 테이블, KMS 키 생성
```

#### 2단계: S3 Backend로 State 마이그레이션
```bash
# backend.tf 주석 해제 또는 생성
# S3 backend 설정 활성화

terraform init -migrate-state
# → 로컬 state를 S3로 마이그레이션
```

**중요**:
- 이후 모든 bootstrap 스택의 변경은 S3 backend를 사용합니다
- 다른 스택들은 처음부터 S3 backend를 사용하므로 순환 참조 문제가 없습니다

---

## 리소스 목록

### 1. S3 State 버킷 (s3-bucket 모듈)

**리소스**: `module.terraform_state_bucket`

```hcl
module "terraform_state_bucket" {
  source = "../../modules/s3-bucket"

  bucket_name        = "prod-connectly"
  environment        = "prod"
  versioning_enabled = true
  kms_key_id         = aws_kms_key.terraform-state.arn

  lifecycle_rules = [
    {
      id                         = "expire-old-versions"
      enabled                    = true
      noncurrent_expiration_days = 90  # 90일 이후 삭제
    },
    {
      id                           = "delete-incomplete-multipart-uploads"
      enabled                      = true
      abort_incomplete_upload_days = 7
    }
  ]
}
```

**특징**:
- **버전 관리**: 모든 state 파일 변경 이력 추적
- **KMS 암호화**: 고객 관리형 키로 저장 시 암호화
- **라이프사이클 정책**:
  - 90일 이후 이전 버전 자동 삭제 (비용 절감)
  - 7일 이후 불완전한 멀티파트 업로드 정리
- **Bucket Policy**:
  - HTTP 연결 거부 (HTTPS 강제)
  - 비암호화 객체 업로드 거부

### 2. DynamoDB State Lock 테이블

**리소스**: `aws_dynamodb_table.terraform-lock`

```hcl
resource "aws_dynamodb_table" "terraform-lock" {
  name         = "prod-connectly-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform-state.arn
  }

  point_in_time_recovery {
    enabled = true
  }
}
```

**특징**:
- **PAY_PER_REQUEST**: 사용량 기반 과금 (프로비저닝 용량 불필요)
- **State Lock**: `LockID` 키로 Terraform 동시 실행 방지
- **KMS 암호화**: Lock 정보도 암호화 저장
- **PITR**: Point-in-Time Recovery 활성화 (데이터 복구)

**비용**:
- 쓰기 요청: $1.25 per million writes
- 읽기 요청: $0.25 per million reads
- 스토리지: $0.25/GB-month
- **예상 월 비용**: ~$1-2 (일반적인 사용 패턴)

### 3. KMS 암호화 키

**리소스**: `aws_kms_key.terraform-state`

```hcl
resource "aws_kms_key" "terraform-state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}
```

**특징**:
- **고객 관리형 키**: AWS 관리형 키보다 더 세밀한 제어
- **자동 키 교체**: 매년 자동으로 키 교체 (보안 강화)
- **삭제 대기 기간**: 30일 (실수로 삭제 방지)
- **Alias**: `alias/terraform-state` (편리한 참조)

**사용처**:
- S3 state 버킷 암호화
- DynamoDB lock 테이블 암호화

### 4. GitHub Actions IAM Role (iam-role-policy 모듈)

**리소스**: `module.github_actions_role`

```hcl
module "github_actions_role" {
  source = "../../modules/iam-role-policy"

  role_name    = "GitHubActionsRole"
  description  = "IAM role for GitHub Actions workflows"
  environment  = "prod"
  service_name = "github-actions"
}
```

**Trust Policy (OIDC)**:
```json
{
  "Principal": {
    "Federated": "arn:aws:iam::{account-id}:oidc-provider/token.actions.githubusercontent.com"
  },
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": [
        "repo:ryu-qqq/Infrastructure:*",
        "repo:ryu-qqq/fileflow:*"
      ]
    }
  }
}
```

**Inline Policies**:

1. **terraform-state**: Terraform backend 접근
   - S3: ListBucket, GetObject, PutObject, DeleteObject
   - DynamoDB: GetItem, PutItem, DeleteItem, DescribeTable

2. **ssm-access**: SSM Parameter Store 관리
   - SSM: Get/Put/DeleteParameter, ListTagsForResource
   - Resource: `/shared/*` 네임스페이스

3. **kms-access**: KMS 암호화/복호화
   - KMS: Encrypt, Decrypt, DescribeKey, CreateGrant

4. **resource-management**: 인프라 리소스 관리
   - VPC: CreateVpc, CreateSubnet, CreateRouteTable 등
   - KMS: CreateKey, CreateAlias 등
   - IAM: CreateRole, PutRolePolicy (제한된 리소스만)

**Managed Policy**:
- **GitHubActionsFileFlowPolicy**: FileFlow 애플리케이션 인프라
  - ElastiCache, CloudWatch Logs, S3, SQS
  - ECS, ALB, Security Groups

### 5. S3 Bucket Policy

**리소스**: `aws_s3_bucket_policy.terraform-state`

**보안 정책**:
```json
{
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Action": "s3:*",
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    },
    {
      "Sid": "DenyUnencryptedObjectUploads",
      "Effect": "Deny",
      "Action": "s3:PutObject",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    }
  ]
}
```

**보안 강화**:
- HTTP 연결 완전 차단 (HTTPS 강제)
- 비암호화 객체 업로드 차단 (KMS 암호화 강제)

---

## 변수 설정

### 필수 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `environment` | `string` | `prod` | 환경 이름 |
| `aws_region` | `string` | `ap-northeast-2` | AWS 리전 |

### Terraform State 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `tfstate_bucket_name` | `string` | `prod-connectly` | S3 버킷 이름 |
| `dynamodb_table_name` | `string` | `prod-connectly-tf-lock` | DynamoDB 테이블 이름 |
| `service` | `string` | `terraform-backend` | 서비스 이름 |

### 거버넌스 태그 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `owner` | `string` | `fbtkdals2@naver.com` | 소유자 이메일 |
| `cost_center` | `string` | `infrastructure` | 비용 센터 |
| `team` | `string` | `platform-team` | 담당 팀 |
| `project` | `string` | `infrastructure` | 프로젝트 이름 |
| `data_class` | `string` | `internal` | 데이터 분류 (confidential, internal, public) |
| `lifecycle` | `string` | `permanent` | 라이프사이클 (temporary, permanent) |

---

## 출력값

### Terraform Backend 정보

| 출력명 | 설명 |
|--------|------|
| `s3_bucket_name` | Terraform state S3 버킷 이름 |
| `s3_bucket_arn` | Terraform state S3 버킷 ARN |
| `dynamodb_table_name` | State lock DynamoDB 테이블 이름 |
| `dynamodb_table_arn` | State lock DynamoDB 테이블 ARN |

### KMS 암호화 키 정보

| 출력명 | 설명 |
|--------|------|
| `kms_key_id` | KMS 키 ID |
| `kms_key_arn` | KMS 키 ARN |
| `kms_key_alias` | KMS 키 Alias (`alias/terraform-state`) |

### GitHub Actions 정보

| 출력명 | 설명 |
|--------|------|
| `github_actions_role_arn` | GitHub Actions IAM Role ARN |
| `github_actions_role_name` | GitHub Actions IAM Role 이름 |

**GitHub Actions에서 사용 예시**:
```yaml
# .github/workflows/terraform.yml
jobs:
  terraform:
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}  # GitHubActionsRole ARN
          aws-region: ap-northeast-2
```

---

## 배포 방법

### 사전 준비

#### AWS Credentials 설정
```bash
export AWS_PROFILE=prod
export AWS_REGION=ap-northeast-2
```

#### GitHub OIDC Provider 생성 (최초 1회)

Bootstrap 스택을 배포하기 전에 GitHub OIDC Provider가 AWS 계정에 이미 생성되어 있어야 합니다.

```bash
# 수동으로 OIDC Provider 생성 (AWS Console 또는 CLI)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

또는 AWS Console:
1. IAM → Identity providers → Add provider
2. Provider type: OpenID Connect
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`

### 초기 Bootstrap 배포 (최초 1회)

#### 1단계: 로컬 State로 리소스 생성

**중요**: 순환 참조 문제를 해결하기 위해 처음에는 로컬 state를 사용합니다.

```bash
cd terraform/environments/prod/bootstrap

# backend.tf가 있다면 백업
mv backend.tf backend.tf.backup

# Terraform 초기화 (로컬 state)
terraform init

# 배포 계획 확인
terraform plan

# 리소스 생성
terraform apply
```

**생성되는 리소스**:
- S3 버킷: `prod-connectly`
- DynamoDB 테이블: `prod-connectly-tf-lock`
- KMS 키: `alias/terraform-state`
- GitHub Actions IAM Role: `GitHubActionsRole`

#### 2단계: S3 Backend로 State 마이그레이션

리소스가 생성되었으므로 이제 S3 backend를 사용할 수 있습니다.

```bash
# backend.tf 복원 또는 생성
mv backend.tf.backup backend.tf
# 또는 새로 생성:
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket         = "prod-connectly"
    key            = "bootstrap/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "prod-connectly-tf-lock"
    kms_key_id     = "alias/terraform-state"
  }
}
EOF

# State 마이그레이션
terraform init -migrate-state
# → "Do you want to copy existing state to the new backend?" → yes

# 로컬 state 파일 삭제 (백업 후)
rm -f terraform.tfstate terraform.tfstate.backup
```

**검증**:
```bash
# S3에 state 파일 업로드 확인
aws s3 ls s3://prod-connectly/bootstrap/

# Output 확인
terraform output
```

### 일반 배포 (초기 bootstrap 이후)

초기 bootstrap이 완료된 후에는 일반적인 Terraform 워크플로우를 사용합니다.

```bash
cd terraform/environments/prod/bootstrap

# 초기화
terraform init

# 변경 사항 확인
terraform plan

# 배포
terraform apply
```

### 배포 전 검증

#### 코드 포맷팅
```bash
terraform fmt
```

#### 코드 검증
```bash
terraform validate
```

#### 보안 스캔
```bash
# tfsec 스캔
tfsec .

# checkov 스캔
checkov -d .
```

---

## 운영 가이드

### State 파일 백업

#### 수동 백업
```bash
# 현재 state를 로컬로 다운로드
terraform state pull > terraform.tfstate.backup

# S3에서 직접 백업
aws s3 cp s3://prod-connectly/bootstrap/terraform.tfstate \
  terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)
```

#### S3 버전 관리로 복구
```bash
# 모든 버전 확인
aws s3api list-object-versions \
  --bucket prod-connectly \
  --prefix bootstrap/terraform.tfstate

# 특정 버전으로 복구
aws s3api get-object \
  --bucket prod-connectly \
  --key bootstrap/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.restored

# 복원된 state를 S3에 업로드
terraform state push terraform.tfstate.restored
```

### State Lock 해제

Terraform이 비정상 종료되어 lock이 남아있는 경우:

```bash
# Lock ID 확인
aws dynamodb get-item \
  --table-name prod-connectly-tf-lock \
  --key '{"LockID":{"S":"prod-connectly/bootstrap/terraform.tfstate"}}'

# Lock 강제 해제
terraform force-unlock <LOCK_ID>

# 또는 DynamoDB에서 직접 삭제
aws dynamodb delete-item \
  --table-name prod-connectly-tf-lock \
  --key '{"LockID":{"S":"prod-connectly/bootstrap/terraform.tfstate"}}'
```

**주의**: Lock을 강제 해제하기 전에 다른 Terraform 프로세스가 실행 중이지 않은지 반드시 확인하세요.

### KMS 키 교체

KMS 키는 자동으로 매년 교체되지만, 수동 교체도 가능합니다:

```bash
# 키 교체 상태 확인
aws kms get-key-rotation-status \
  --key-id alias/terraform-state

# 키 교체 활성화 (이미 활성화됨)
aws kms enable-key-rotation \
  --key-id alias/terraform-state
```

### GitHub Actions Role 권한 업데이트

새로운 AWS 리소스를 관리해야 하는 경우:

```hcl
# github-actions.tf 수정

module "github_actions_role" {
  # ...

  custom_inline_policies = {
    # 기존 정책...

    new-service-access = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "NewServiceAccess"
            Effect = "Allow"
            Action = [
              "service:Action1",
              "service:Action2"
            ]
            Resource = "*"
          }
        ]
      })
    }
  }
}
```

```bash
terraform apply
```

### State 파일 크기 모니터링

```bash
# State 파일 크기 확인
aws s3api head-object \
  --bucket prod-connectly \
  --key bootstrap/terraform.tfstate \
  --query 'ContentLength' \
  --output text

# 모든 버전의 크기 확인
aws s3api list-object-versions \
  --bucket prod-connectly \
  --prefix bootstrap/terraform.tfstate \
  --query 'Versions[*].[VersionId,Size,LastModified]' \
  --output table
```

**권장 조치**:
- State 파일 크기가 5MB를 초과하면 리소스 분리 고려
- 90일 이상 된 버전은 자동 삭제됨 (lifecycle rule)

### 비용 모니터링

```bash
# S3 스토리지 비용
aws s3api list-objects-v2 \
  --bucket prod-connectly \
  --output json \
  --query "sum(Contents[].Size)" | \
  awk '{printf "%.2f GB\n", $1/1024/1024/1024}'

# DynamoDB 사용량 (CloudWatch)
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=prod-connectly-tf-lock \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

**예상 월 비용**:
- S3 스토리지: ~$0.50 (20GB 기준)
- S3 요청: ~$0.10
- DynamoDB: ~$1-2
- KMS: $1
- **총 예상 비용**: ~$3-4/month

---

## 문제 해결

### 1. 순환 참조 에러

**증상**: Terraform이 backend 설정을 찾을 수 없다고 에러

```
Error: Failed to get existing workspaces: S3 bucket does not exist.
```

**원인**: S3 버킷이 아직 생성되지 않았는데 backend 설정이 활성화됨

**해결 방법**:
```bash
# backend.tf 비활성화
mv backend.tf backend.tf.disabled

# 로컬 state로 리소스 생성
terraform init
terraform apply

# backend 활성화 및 마이그레이션
mv backend.tf.disabled backend.tf
terraform init -migrate-state
```

### 2. State Lock 획득 실패

**증상**:
```
Error: Error acquiring the state lock
Lock Info:
  ID:        12345678-1234-1234-1234-123456789012
  Path:      prod-connectly/bootstrap/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.6.0
  Created:   2024-11-24 10:00:00.000000 UTC
```

**확인 방법**:
```bash
# Lock 상태 확인
aws dynamodb get-item \
  --table-name prod-connectly-tf-lock \
  --key '{"LockID":{"S":"prod-connectly/bootstrap/terraform.tfstate"}}'
```

**해결 방법**:

**옵션 1**: 다른 Terraform 프로세스가 완료될 때까지 대기

**옵션 2**: 확실히 다른 프로세스가 없다면 강제 해제
```bash
terraform force-unlock 12345678-1234-1234-1234-123456789012
```

### 3. KMS 권한 에러

**증상**:
```
Error: AccessDenied: User is not authorized to perform: kms:Decrypt
```

**확인 방법**:
```bash
# KMS 키 정책 확인
aws kms get-key-policy \
  --key-id alias/terraform-state \
  --policy-name default
```

**해결 방법**:

KMS 키 정책에 사용자/Role 추가:
```json
{
  "Sid": "Allow Terraform Backend Access",
  "Effect": "Allow",
  "Principal": {
    "AWS": [
      "arn:aws:iam::{account-id}:role/GitHubActionsRole",
      "arn:aws:iam::{account-id}:user/your-user"
    ]
  },
  "Action": [
    "kms:Decrypt",
    "kms:Encrypt",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

### 4. GitHub Actions OIDC 인증 실패

**증상**:
```
Error: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**확인 방법**:
```bash
# OIDC Provider 존재 확인
aws iam list-open-id-connect-providers

# Trust Policy 확인
aws iam get-role \
  --role-name GitHubActionsRole \
  --query 'Role.AssumeRolePolicyDocument'
```

**해결 방법**:

1. **OIDC Provider 생성** (없는 경우):
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

2. **Repository 경로 확인**:
```hcl
# github-actions.tf

assume_role_policy = jsonencode({
  Condition = {
    StringLike = {
      "token.actions.githubusercontent.com:sub" = [
        "repo:ryu-qqq/Infrastructure:*",  # 정확한 repository 이름 확인
        "repo:ryu-qqq/fileflow:*"
      ]
    }
  }
})
```

### 5. S3 버킷 접근 거부

**증상**:
```
Error: AccessDenied: Access Denied
Status Code: 403
```

**확인 방법**:
```bash
# Bucket Policy 확인
aws s3api get-bucket-policy \
  --bucket prod-connectly

# IAM 권한 확인
aws iam get-role-policy \
  --role-name GitHubActionsRole \
  --policy-name terraform-state
```

**해결 방법**:

1. **HTTPS 사용 확인**: HTTP 연결은 bucket policy에 의해 차단됨
2. **KMS 암호화 확인**: 비암호화 업로드는 거부됨
3. **IAM 권한 확인**: S3 접근 권한이 있는지 확인

### 6. DynamoDB Lock 테이블 접근 실패

**증상**:
```
Error: error acquiring the state lock: ConditionalCheckFailedException
```

**확인 방법**:
```bash
# 테이블 존재 확인
aws dynamodb describe-table \
  --table-name prod-connectly-tf-lock

# IAM 권한 확인
aws iam get-role-policy \
  --role-name GitHubActionsRole \
  --policy-name terraform-state
```

**해결 방법**:

DynamoDB 권한 확인:
```json
{
  "Action": [
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:DeleteItem",
    "dynamodb:DescribeTable"
  ],
  "Resource": "arn:aws:dynamodb:ap-northeast-2:{account-id}:table/prod-connectly-tf-lock"
}
```

### 7. Terraform State Drift

**증상**: Terraform이 이미 존재하는 리소스를 다시 생성하려고 함

**확인 방법**:
```bash
# State와 실제 인프라 비교
terraform plan -detailed-exitcode
```

**해결 방법**:

**옵션 1**: State 새로고침
```bash
terraform refresh
```

**옵션 2**: 리소스 Import
```bash
# S3 버킷 import
terraform import module.terraform_state_bucket.aws_s3_bucket.this prod-connectly

# DynamoDB 테이블 import
terraform import aws_dynamodb_table.terraform-lock prod-connectly-tf-lock

# KMS 키 import
terraform import aws_kms_key.terraform-state <KEY_ID>
```

---

## 보안 고려사항

### 필수 보안 설정

- [x] **State 암호화**: KMS 고객 관리형 키로 암호화
- [x] **전송 암호화**: HTTPS 강제 (HTTP 차단)
- [x] **State 버전 관리**: S3 버저닝으로 변경 이력 추적
- [x] **State Lock**: DynamoDB로 동시 실행 방지
- [x] **OIDC 인증**: GitHub Actions용 비밀 키 없는 인증
- [x] **최소 권한**: GitHub Actions Role에 필요한 권한만 부여
- [x] **Repository 제한**: 특정 repository만 Role 사용 가능

### 권장 보안 설정

- [ ] **MFA Delete**: S3 버킷 객체 삭제 시 MFA 요구
- [ ] **CloudTrail 감사**: State 파일 접근 로깅
- [ ] **VPC Endpoint**: S3 트래픽을 AWS 내부망으로 제한
- [ ] **접근 로깅**: S3 버킷 접근 로그 활성화
- [ ] **정기 백업**: State 파일 정기 백업 및 재해 복구 계획
- [ ] **IAM 권한 검토**: 분기별 GitHub Actions Role 권한 검토

### 보안 체크리스트

```bash
# 1. S3 버킷 암호화 확인
aws s3api get-bucket-encryption --bucket prod-connectly

# 2. S3 버킷 버저닝 확인
aws s3api get-bucket-versioning --bucket prod-connectly

# 3. S3 버킷 공개 액세스 차단 확인
aws s3api get-public-access-block --bucket prod-connectly

# 4. DynamoDB 암호화 확인
aws dynamodb describe-table \
  --table-name prod-connectly-tf-lock \
  --query 'Table.SSEDescription'

# 5. KMS 키 교체 활성화 확인
aws kms get-key-rotation-status --key-id alias/terraform-state

# 6. GitHub Actions Role Trust Policy 확인
aws iam get-role \
  --role-name GitHubActionsRole \
  --query 'Role.AssumeRolePolicyDocument'
```

---

## 재해 복구 (Disaster Recovery)

### State 파일 복구

#### 시나리오 1: 실수로 State 파일 삭제

```bash
# S3 버전 관리에서 복구
aws s3api list-object-versions \
  --bucket prod-connectly \
  --prefix bootstrap/terraform.tfstate

# 최신 버전으로 복구
aws s3api copy-object \
  --bucket prod-connectly \
  --copy-source prod-connectly/bootstrap/terraform.tfstate?versionId=<VERSION_ID> \
  --key bootstrap/terraform.tfstate
```

#### 시나리오 2: State 파일 손상

```bash
# 로컬 백업에서 복구
terraform state push terraform.tfstate.backup

# 또는 S3 이전 버전에서 복구
aws s3api get-object \
  --bucket prod-connectly \
  --key bootstrap/terraform.tfstate \
  --version-id <PREVIOUS_VERSION_ID> \
  terraform.tfstate.recovered

terraform state push terraform.tfstate.recovered
```

#### 시나리오 3: S3 버킷 전체 삭제

**주의**: 이것은 최악의 시나리오입니다. S3 버킷이 삭제되면 모든 state가 손실됩니다.

**예방책**:
1. S3 버킷에 삭제 방지 설정
2. 정기적인 오프사이트 백업
3. MFA Delete 활성화

**복구 방법**:
```bash
# 1. 로컬 백업이 있는 경우
terraform init -migrate-state
terraform state push terraform.tfstate.backup

# 2. 백업이 없는 경우 - 리소스 재 import
terraform init
terraform import module.terraform_state_bucket.aws_s3_bucket.this prod-connectly
terraform import aws_dynamodb_table.terraform-lock prod-connectly-tf-lock
terraform import aws_kms_key.terraform-state <KEY_ID>
```

### RTO/RPO 목표

| 시나리오 | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) |
|---------|------------------------------|-------------------------------|
| State 파일 손상 | < 15분 | < 1시간 (S3 버전 관리) |
| DynamoDB Lock 손실 | < 5분 | N/A (재생성 가능) |
| KMS 키 손실 | < 30분 | N/A (키 복구 불가, 재암호화 필요) |
| S3 버킷 삭제 | < 1시간 | 마지막 백업 시점 |

---

## 버전 히스토리

| 버전 | 날짜 | 변경 사항 |
|------|------|-----------|
| 1.0.0 | 2024-11-24 | 초기 문서화 (modules v1.0.0 패턴 기준) |

---

## 관련 문서

- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [AWS DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Infrastructure 프로젝트 거버넌스](../../../docs/governance/)
- [S3 Bucket Module v1.0.0](../../modules/s3-bucket/)
- [IAM Role Policy Module v1.0.0](../../modules/iam-role-policy/)

---

**Maintained By**: Platform Team
**Last Updated**: 2024-11-24
