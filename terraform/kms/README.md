# KMS Module

Common Platform KMS Keys for infrastructure encryption.

## Overview

This module creates and manages 4 KMS keys for different encryption purposes following data-class based key separation principles.

## Keys Created

| Key | Alias | DataClass | Purpose |
|-----|-------|-----------|---------|
| terraform_state | alias/terraform-state | confidential | Terraform State S3 encryption |
| rds | alias/rds-encryption | highly-confidential | RDS instance encryption |
| ecs_secrets | alias/ecs-secrets | confidential | ECS task secrets encryption |
| secrets_manager | alias/secrets-manager | highly-confidential | Secrets Manager encryption |

## Features

- ✅ Automatic key rotation enabled
- ✅ 30-day deletion window
- ✅ Least-privilege key policies
- ✅ Service-specific access control
- ✅ Governance-compliant tagging

## Usage

### Deploy KMS Keys

```bash
cd terraform/kms
terraform init
terraform plan
terraform apply
```

### Reference Keys from Other Modules

```hcl
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = "prod-tfstate"
    key    = "kms/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Use in backend configuration
terraform {
  backend "s3" {
    kms_key_id = "alias/terraform-state"
  }
}

# Use in RDS
resource "aws_db_instance" "example" {
  storage_encrypted = true
  kms_key_id        = data.terraform_remote_state.kms.outputs.rds_key_arn
}
```

## Outputs

All keys provide:
- `*_key_id`: KMS key ID
- `*_key_arn`: KMS key ARN
- `*_key_alias`: KMS key alias
- `kms_keys_summary`: Complete summary of all keys

## Variables

| Name | Description | Default |
|------|-------------|---------|
| environment | Environment name | `prod` |
| aws_region | AWS region | `ap-northeast-2` |
| owner | Resource owner | `platform-team` |
| cost_center | Cost center | `infrastructure` |
| resource_lifecycle | Lifecycle | `permanent` |
| service | Service name | `common-platform` |
| key_deletion_window_in_days | Deletion window | `30` |
| enable_key_rotation | Enable rotation | `true` |

## Security

### Key Policies

Each key has service-specific policies following least-privilege principles:

- **Terraform State**: S3, GitHub Actions
- **RDS**: RDS service, GitHub Actions
- **ECS Secrets**: ECS Tasks, Secrets Manager, GitHub Actions
- **Secrets Manager**: Secrets Manager, Application roles, GitHub Actions

### Monitoring

All key operations are logged to CloudTrail for audit purposes.

## Cost

- **Key Cost**: $1/month per key = $4/month total
- **API Requests**: First 10,000 requests/month free, $0.03/10,000 thereafter

## 🔧 Troubleshooting

### 1. KMS 키 접근 권한 문제 (Access Denied)

**증상**: `AccessDeniedException: User is not authorized to perform: kms:Decrypt`

**확인 방법**:
```bash
# KMS 키 정책 확인
aws kms get-key-policy \
  --key-id alias/rds-encryption \
  --policy-name default \
  --region ap-northeast-2
```

**해결 방법**:

1. **IAM 역할/사용자 권한 확인**:
   필요한 KMS 권한:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "kms:Decrypt",
       "kms:Encrypt",
       "kms:DescribeKey",
       "kms:CreateGrant"
     ],
     "Resource": "arn:aws:kms:ap-northeast-2:*:key/*"
   }
   ```

2. **키 정책에 Principal 추가**:
   ```bash
   # 현재 키 정책 가져오기
   aws kms get-key-policy \
     --key-id alias/rds-encryption \
     --policy-name default \
     --region ap-northeast-2 > key-policy.json

   # 편집 후 업데이트
   aws kms put-key-policy \
     --key-id alias/rds-encryption \
     --policy-name default \
     --policy file://key-policy.json \
     --region ap-northeast-2
   ```

3. **Service-Linked Role 확인** (RDS, ECS 등):
   - RDS: `AWSServiceRoleForRDS`
   - ECS: `AWSServiceRoleForECS`

### 2. 암호화/복호화 실패

**증상**: 데이터 암호화 또는 복호화 작업 실패

**확인 방법**:
```bash
# 키 상태 확인
aws kms describe-key \
  --key-id alias/terraform-state \
  --region ap-northeast-2 \
  --query 'KeyMetadata.{State:KeyState,Enabled:Enabled,KeyManager:KeyManager}'

# 키로 암호화 테스트
echo "test" | aws kms encrypt \
  --key-id alias/terraform-state \
  --plaintext fileb:///dev/stdin \
  --region ap-northeast-2
```

**해결 방법**:

1. **키 상태 확인**:
   - `Enabled`: true여야 함
   - `KeyState`: `Enabled`여야 함 (PendingDeletion, Disabled 등이면 사용 불가)

2. **키 활성화**:
   ```bash
   aws kms enable-key \
     --key-id <key-id> \
     --region ap-northeast-2
   ```

3. **Grant 권한 확인**:
   ```bash
   # Grant 목록 확인
   aws kms list-grants \
     --key-id alias/rds-encryption \
     --region ap-northeast-2
   ```

### 3. 키 회전 관련 문제

**증상**: 키 회전 후 이전 데이터 복호화 실패

**확인 방법**:
```bash
# 키 회전 상태 확인
aws kms get-key-rotation-status \
  --key-id alias/terraform-state \
  --region ap-northeast-2

# 키 메타데이터 확인 (마지막 회전 날짜 포함)
aws kms describe-key \
  --key-id alias/terraform-state \
  --region ap-northeast-2 \
  --query 'KeyMetadata.{Created:CreationDate,Rotation:KeyRotationEnabled}'
```

**해결 방법**:

1. **자동 키 회전은 이전 데이터 자동 복호화 지원**:
   - AWS KMS는 이전 키 구성 요소를 자동으로 유지
   - 수동 작업 불필요

2. **수동 키 회전 시**:
   - 새 키 생성 필요
   - Alias만 변경하여 점진적 마이그레이션

3. **키 회전 확인 및 활성화**:
   ```bash
   # 키 회전 활성화
   aws kms enable-key-rotation \
     --key-id <key-id> \
     --region ap-northeast-2
   ```

### 4. 키 삭제 예약 및 복구

**증상**: 실수로 키를 삭제 예약함

**확인 방법**:
```bash
# 삭제 예약된 키 확인
aws kms describe-key \
  --key-id <key-id> \
  --region ap-northeast-2 \
  --query 'KeyMetadata.{State:KeyState,DeletionDate:DeletionDate}'
```

**해결 방법**:

1. **삭제 취소** (30일 대기 기간 내):
   ```bash
   aws kms cancel-key-deletion \
     --key-id <key-id> \
     --region ap-northeast-2
   ```

2. **삭제 예약 확인**:
   - `KeyState`: `PendingDeletion`이면 삭제 예약 상태
   - `DeletionDate`: 실제 삭제 예정일

3. **예방 조치**:
   - Terraform에서 `deletion_window_in_days = 30` 설정 (기본값)
   - `prevent_destroy` 라이프사이클 추가:
     ```hcl
     lifecycle {
       prevent_destroy = true
     }
     ```

### 5. CloudTrail 로그로 키 사용 추적

**증상**: 키 사용 내역 확인 필요

**확인 방법**:
```bash
# 최근 KMS API 호출 확인
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::KMS::Key \
  --region ap-northeast-2 \
  --max-results 10

# 특정 키에 대한 이벤트
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<key-arn> \
  --region ap-northeast-2
```

**해결 방법**:

1. **CloudWatch Logs Insights 쿼리**:
   ```sql
   fields @timestamp, userIdentity.principalId, requestParameters.keyId, errorCode
   | filter eventSource = "kms.amazonaws.com"
   | filter requestParameters.keyId like /alias\/rds-encryption/
   | sort @timestamp desc
   | limit 100
   ```

2. **실패한 KMS 작업 찾기**:
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::KMS::Key \
     --region ap-northeast-2 \
     --query 'Events[?contains(CloudTrailEvent, `errorCode`)].CloudTrailEvent'
   ```

### 6. 키 정책(Key Policy) 문제

**증상**: 키 정책으로 인해 특정 작업이 거부됨

**확인 방법**:
```bash
# 키 정책 JSON 포맷으로 확인
aws kms get-key-policy \
  --key-id alias/ecs-secrets \
  --policy-name default \
  --region ap-northeast-2 \
  --output json | jq .
```

**해결 방법**:

1. **키 정책 기본 구조 확인**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "Enable IAM User Permissions",
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::646886795421:root"
         },
         "Action": "kms:*",
         "Resource": "*"
       },
       {
         "Sid": "Allow service to use the key",
         "Effect": "Allow",
         "Principal": {
           "Service": "rds.amazonaws.com"
         },
         "Action": [
           "kms:Decrypt",
           "kms:DescribeKey",
           "kms:CreateGrant"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

2. **서비스별 필수 작업 권한**:
   - **RDS**: `kms:Decrypt`, `kms:DescribeKey`, `kms:CreateGrant`
   - **ECS**: `kms:Decrypt`, `kms:DescribeKey`
   - **S3**: `kms:Decrypt`, `kms:Encrypt`, `kms:GenerateDataKey`
   - **Secrets Manager**: `kms:Decrypt`, `kms:Encrypt`, `kms:GenerateDataKey`

3. **정책 업데이트**:
   - Terraform 코드 수정 후 apply
   - 또는 AWS CLI로 직접 업데이트

### 7. 비용 관련 문제

**증상**: 예상보다 높은 KMS 비용

**확인 방법**:
```bash
# Cost Explorer API (지난 30일 KMS 비용)
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter file://<(cat <<EOF
{
  "Dimensions": {
    "Key": "SERVICE",
    "Values": ["AWS Key Management Service"]
  }
}
EOF
)
```

**해결 방법**:

1. **비용 구조 이해**:
   - 키 생성/보관: $1/월 per key
   - API 요청: 무료 10,000회/월, 이후 $0.03/10,000회
   - 자동 키 회전: 추가 비용 없음

2. **불필요한 키 삭제**:
   ```bash
   # 사용하지 않는 키 찾기
   aws kms list-keys --region ap-northeast-2 \
     --query 'Keys[*].KeyId' --output text | \
     while read key; do
       echo "Key: $key"
       aws cloudtrail lookup-events \
         --lookup-attributes AttributeKey=ResourceName,AttributeValue=$key \
         --region ap-northeast-2 \
         --max-results 1
     done
   ```

3. **API 요청 최적화**:
   - 애플리케이션에서 KMS 호출 캐싱
   - Data Key 캐싱 사용 (AWS Encryption SDK)

### 8. 일반적인 체크리스트

KMS 배포 및 사용 시 확인 사항:
- [ ] 모든 키가 `Enabled` 상태
- [ ] 자동 키 회전 활성화됨 (`enable_key_rotation = true`)
- [ ] 삭제 대기 기간 30일 설정됨 (`deletion_window_in_days = 30`)
- [ ] 키 정책에 필요한 Principal 포함됨
- [ ] IAM 정책에 KMS 작업 권한 부여됨
- [ ] CloudTrail 로깅 활성화됨 (키 사용 추적용)
- [ ] 서비스별 필수 KMS 권한 확인:
  - RDS: `kms:Decrypt`, `kms:CreateGrant`
  - ECS: `kms:Decrypt`
  - S3: `kms:GenerateDataKey`, `kms:Decrypt`
- [ ] 키 Alias가 올바르게 설정됨
- [ ] 테스트 암호화/복호화 작업 성공
- [ ] 비용 알림 설정 (예상 초과 시)

## Documentation

See [KMS Strategy Guide](../../claudedocs/kms-strategy.md) for detailed usage guide.

## Related Issues

