# Terraform Import Guide

기존에 수동으로 생성한 `prod-connectly` 리소스를 Terraform으로 관리하기 위한 Import 가이드입니다.

## 🎯 Import 목표

현재 **수동 생성된 리소스**를 Terraform 코드로 관리:
- S3 버킷: `prod-connectly`
- DynamoDB 테이블: `prod-connectly-tf-lock`
- KMS 키: (신규 생성 필요)

## ⚠️ 사전 준비

### 1. 백업 필수

Import는 **위험한 작업**이므로 먼저 백업:

```bash
# 현재 사용 중인 다른 모듈의 state 백업
cd terraform/atlantis
terraform state pull > backup-atlantis-$(date +%Y%m%d-%H%M%S).tfstate

cd terraform/test
terraform state pull > backup-test-$(date +%Y%m%d-%H%M%S).tfstate

# 백업 파일을 안전한 곳에 보관
mkdir -p ~/terraform-backups/$(date +%Y%m%d)
mv backup-*.tfstate ~/terraform-backups/$(date +%Y%m%d)/
```

### 2. AWS 권한 확인

다음 권한 필요:
- S3: `s3:GetBucket*`, `s3:ListBucket`
- DynamoDB: `dynamodb:DescribeTable`
- KMS: `kms:DescribeKey`, `kms:GetKeyPolicy`

```bash
# 현재 사용자 확인
aws sts get-caller-identity

# 권한 테스트
aws s3api get-bucket-versioning --bucket prod-connectly --region ap-northeast-2
aws dynamodb describe-table --table-name prod-connectly-tf-lock --region ap-northeast-2
```

### 3. 현재 리소스 설정 확인

Import 전에 **실제 설정**을 파악해야 Terraform 코드와 일치시킬 수 있습니다.

#### S3 버킷 설정 조회

```bash
# 버킷 기본 정보
aws s3api get-bucket-location --bucket prod-connectly
aws s3api get-bucket-versioning --bucket prod-connectly

# 암호화 설정
aws s3api get-bucket-encryption --bucket prod-connectly

# 수명주기 정책
aws s3api get-bucket-lifecycle-configuration --bucket prod-connectly

# 퍼블릭 액세스 차단
aws s3api get-public-access-block --bucket prod-connectly

# 버킷 정책
aws s3api get-bucket-policy --bucket prod-connectly

# 태그
aws s3api get-bucket-tagging --bucket prod-connectly
```

#### DynamoDB 테이블 설정 조회

```bash
# 테이블 기본 정보
aws dynamodb describe-table --table-name prod-connectly-tf-lock --region ap-northeast-2

# JSON 형식으로 저장
aws dynamodb describe-table \
  --table-name prod-connectly-tf-lock \
  --region ap-northeast-2 \
  --output json > existing-dynamodb-table.json
```

**확인할 항목**:
- `BillingModeSummary.BillingMode`: PAY_PER_REQUEST vs PROVISIONED
- `AttributeDefinitions`: LockID (S) 확인
- `KeySchema`: HASH 키가 LockID인지 확인
- `PointInTimeRecoveryDescription.PointInTimeRecoveryStatus`: ENABLED인지 확인
- `SSEDescription`: 암호화 활성화 여부

## 📋 Import 절차

### Step 1: Terraform 초기화

```bash
cd terraform/bootstrap

# Terraform 초기화
terraform init

# 현재 상태 확인 (빈 상태여야 함)
terraform state list
```

### Step 2: S3 버킷 Import

```bash
# S3 버킷 Import
terraform import aws_s3_bucket.terraform_state prod-connectly

# Import 성공 확인
terraform state show aws_s3_bucket.terraform_state
```

**예상 출력**:
```
aws_s3_bucket.terraform_state:
resource "aws_s3_bucket" "terraform_state" {
    bucket = "prod-connectly"
    region = "ap-northeast-2"
    ...
}
```

### Step 3: S3 버킷 하위 리소스 Import

S3 버킷 자체만 import했으므로, 설정들도 각각 import 필요:

```bash
# Versioning
terraform import aws_s3_bucket_versioning.terraform_state prod-connectly

# Encryption
terraform import aws_s3_bucket_server_side_encryption_configuration.terraform_state prod-connectly

# Public Access Block
terraform import aws_s3_bucket_public_access_block.terraform_state prod-connectly

# Lifecycle Configuration
terraform import aws_s3_bucket_lifecycle_configuration.terraform_state prod-connectly

# Bucket Policy
terraform import aws_s3_bucket_policy.terraform_state prod-connectly
```

### Step 4: DynamoDB 테이블 Import

```bash
# DynamoDB 테이블 Import
terraform import aws_dynamodb_table.terraform_lock prod-connectly-tf-lock

# Import 성공 확인
terraform state show aws_dynamodb_table.terraform_lock
```

### Step 5: KMS 키 생성

**주의**: 기존 버킷이 KMS 암호화를 사용 중이라면, 그 키를 import해야 합니다.

```bash
# 현재 사용 중인 KMS 키 확인
aws s3api get-bucket-encryption --bucket prod-connectly

# KMS 키 ID가 있다면
# terraform import aws_kms_key.terraform_state <KMS_KEY_ID>

# 없다면 (AES256 사용 중) - terraform apply로 신규 생성
# 주의: 버킷 암호화 방식이 변경되므로 주의 필요
```

### Step 6: Drift 확인

모든 import 완료 후, Terraform 코드와 실제 리소스가 일치하는지 확인:

```bash
terraform plan
```

**이상적인 결과**:
```
No changes. Your infrastructure matches the configuration.
```

**변경사항이 있다면**:
1. **코드 수정**: Terraform 코드를 실제 리소스에 맞춤
2. **리소스 수정**: `terraform apply`로 실제 리소스를 코드에 맞춤 (주의!)

### Step 7: 코드와 리소스 일치시키기

Drift가 발생한 경우 수정 방법:

#### 예시 1: 버전 관리가 비활성화된 경우

**Plan 출력**:
```
~ resource "aws_s3_bucket_versioning" "terraform_state" {
    ~ versioning_configuration {
        ~ status = "Suspended" -> "Enabled"
      }
  }
```

**해결책**:
```bash
# Option A: 코드를 실제에 맞춤
# variables.tf에서
variable "state_bucket_versioning" {
  default     = false  # Enabled -> false로 변경
}

# Option B: 실제를 코드에 맞춤 (권장)
terraform apply  # 버전 관리 활성화
```

#### 예시 2: 수명주기 정책이 없는 경우

**Plan 출력**:
```
+ resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
    + bucket = "prod-connectly"
    + rule {
        ...
      }
  }
```

**해결책**:
```bash
# 새 정책 추가 (권장)
terraform apply

# 또는 코드에서 lifecycle_configuration 블록 제거 (비권장)
```

#### 예시 3: 태그 불일치

**Plan 출력**:
```
~ tags = {
    ~ "Environment" = "production" -> "prod"
    + "DataClass"   = "confidential"
  }
```

**해결책**:
```bash
# Option A: 코드 수정
# variables.tf에서 default 값 변경

# Option B: 실제 태그 업데이트 (권장)
terraform apply
```

## 🔍 검증 단계

Import 완료 후 다음을 확인:

### 1. State 파일 확인

```bash
# 모든 리소스가 import되었는지 확인
terraform state list

# 예상 출력:
# aws_dynamodb_table.terraform_lock
# aws_kms_alias.terraform_state
# aws_kms_key.terraform_state
# aws_kms_key_policy.terraform_state
# aws_s3_bucket.terraform_state
# aws_s3_bucket_lifecycle_configuration.terraform_state
# aws_s3_bucket_policy.terraform_state
# aws_s3_bucket_public_access_block.terraform_state
# aws_s3_bucket_server_side_encryption_configuration.terraform_state
# aws_s3_bucket_versioning.terraform_state
```

### 2. 기능 테스트

다른 모듈에서 백엔드가 정상 작동하는지 확인:

```bash
cd ../atlantis

# Init 성공 확인
terraform init

# Plan 실행 (Lock 테스트)
terraform plan

# State 조회 성공 확인
terraform state list
```

### 3. Lock 기능 테스트

```bash
# 터미널 1
cd terraform/atlantis
terraform plan  # 실행 중 유지

# 터미널 2 (동시 실행)
cd terraform/atlantis
terraform plan  # Lock에 의해 대기해야 함
```

**예상 출력 (터미널 2)**:
```
Acquiring state lock. This may take a few moments...
```

## 🚨 롤백 절차

Import 중 문제 발생 시:

### 부분 Import 롤백

```bash
# 특정 리소스만 state에서 제거
terraform state rm aws_s3_bucket.terraform_state

# 또는 전체 state 초기화
rm terraform.tfstate terraform.tfstate.backup
```

### 기존 state 복원 (다른 모듈)

```bash
cd terraform/atlantis

# 백업에서 복원
terraform state push ~/terraform-backups/20251013/backup-atlantis-*.tfstate
```

## 📊 Import vs 신규 생성 비교

| 항목 | Import | 신규 생성 |
|------|--------|-----------|
| **시간** | 오래 걸림 | 빠름 |
| **위험도** | 높음 (state 손상 가능) | 낮음 |
| **기존 데이터** | 보존됨 | 마이그레이션 필요 |
| **권장 상황** | 운영 환경 | 개발/테스트 환경 |

## ✅ Import 완료 체크리스트

- [ ] 기존 state 백업 완료
- [ ] AWS 권한 확인
- [ ] 기존 리소스 설정 문서화
- [ ] S3 버킷 import 성공
- [ ] S3 하위 리소스 import 성공
- [ ] DynamoDB 테이블 import 성공
- [ ] KMS 키 생성/import 성공
- [ ] `terraform plan` No changes 확인
- [ ] 다른 모듈에서 backend 정상 작동 확인
- [ ] Lock 기능 테스트 성공
- [ ] 문서 업데이트

## 🆘 문제 해결

### Error: resource already managed by Terraform

**원인**: 리소스가 이미 state에 존재

**해결**:
```bash
terraform state list  # 확인
terraform state rm <resource>  # 제거 후 재시도
```

### Error: resource not found

**원인**: 리소스 이름 또는 리전 불일치

**해결**:
```bash
# 리전 확인
aws configure get region

# 리소스 존재 확인
aws s3 ls | grep prod-connectly
```

### Error: code와 실제 설정 불일치

**원인**: Terraform 코드가 실제 리소스 설정과 다름

**해결**: 위 "Step 7: 코드와 리소스 일치시키기" 참조

## 📞 도움이 필요하면

- **Platform Team**: platform-team@company.com
- **Jira**: [IN-103](https://ryuqqq.atlassian.net/browse/IN-103)
- **Slack**: #infrastructure-help
