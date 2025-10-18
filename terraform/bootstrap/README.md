# Bootstrap Infrastructure

Terraform Backend 인프라를 코드로 관리하기 위한 Bootstrap 구성입니다.

## 목적

Terraform의 상태 파일(state)과 잠금(lock)을 안전하게 관리하기 위한 기반 인프라를 제공합니다.

## 관리 리소스

### 1. S3 Bucket (`prod-connectly`)
- **용도**: Terraform state 파일 저장소
- **기능**:
  - 버저닝 활성화 (복구 가능)
  - KMS 암호화 (customer-managed key)
  - 퍼블릭 액세스 차단
  - 안전하지 않은 전송 거부
  - 암호화되지 않은 업로드 거부
  - 90일 후 이전 버전 자동 삭제
  - 7일 후 미완료 멀티파트 업로드 삭제

### 2. DynamoDB Table (`prod-connectly-tf-lock`)
- **용도**: Terraform state 잠금 메커니즘
- **기능**:
  - PAY_PER_REQUEST 결제 모드
  - KMS 암호화
  - 특정 시점 복구 (PITR) 활성화
  - LockID 해시 키

### 3. KMS Key (`alias/terraform-state`)
- **용도**: Terraform state 암호화
- **기능**:
  - 자동 키 로테이션 활성화
  - 30일 삭제 대기 기간

## 디렉토리 구조

```
terraform/bootstrap/
├── README.md           # 이 문서
├── versions.tf         # Terraform 및 Provider 버전
├── variables.tf        # 입력 변수
├── locals.tf          # 로컬 변수 (태그 포함)
├── kms.tf             # KMS 키 리소스
├── s3.tf              # S3 버킷 리소스
├── dynamodb.tf        # DynamoDB 테이블 리소스
├── outputs.tf         # 출력 값
└── .terraform/        # Provider 캐시
```

## 사용 방법

### 초기 배포

⚠️ **주의**: Bootstrap 인프라는 한 번만 배포하면 됩니다. 이미 배포된 경우 이 단계를 건너뛰세요.

```bash
# 1. 디렉토리 이동
cd terraform/bootstrap

# 2. Terraform 초기화
terraform init

# 3. 계획 확인
terraform plan

# 4. 배포
terraform apply
```

### 기존 리소스 가져오기 (Import)

만약 Bootstrap 인프라 리소스가 이미 수동으로 생성되어 있다면, `terraform apply`를 실행하기 전에 다음 명령어를 사용하여 Terraform 상태로 가져와야 합니다.

```bash
# 1. S3 버킷 가져오기
terraform import aws_s3_bucket.terraform-state prod-connectly

# 2. DynamoDB 테이블 가져오기
terraform import aws_dynamodb_table.terraform-lock prod-connectly-tf-lock

# 3. KMS 키 가져오기 (기존 키의 ID를 먼저 확인해야 합니다)
# AWS Console > KMS에서 "terraform-state" 키의 ID 확인
terraform import aws_kms_key.terraform-state <your-kms-key-id>

# 4. KMS 키 별칭 가져오기
terraform import aws_kms_alias.terraform-state alias/terraform-state
```

> **참고**: 임포트 후 `terraform plan`을 실행하여 변경 사항이 없는지 확인한 뒤, 이후 코드로 인프라를 관리할 수 있습니다.

### Backend 구성 예시

Bootstrap 인프라 배포 후, 다른 Terraform 프로젝트에서 다음과 같이 사용할 수 있습니다:

```hcl
terraform {
  backend "s3" {
    bucket         = "prod-connectly"
    key            = "network/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "prod-connectly-tf-lock"
    kms_key_id     = "alias/terraform-state"
  }
}
```

## 거버넌스 규칙 준수

이 구성은 다음 거버넌스 규칙을 준수합니다:

### ✅ 필수 태그
모든 리소스는 `local.required_tags`를 사용하여 다음 태그를 포함합니다:
- `Owner`: 소유자 이메일
- `CostCenter`: 비용 센터
- `Environment`: 환경 (prod)
- `Lifecycle`: 라이프사이클 (permanent)
- `DataClass`: 데이터 분류 (internal)
- `Service`: 서비스 이름

### ✅ KMS 암호화
모든 암호화는 customer-managed KMS 키를 사용합니다 (AES256 사용 안 함):
- S3: `aws:kms` with KMS key ARN
- DynamoDB: `kms_key_arn` 지정

### ✅ 네이밍 규칙
- 리소스 이름: `kebab-case` (예: `prod-connectly`)
- 변수/로컬: `snake_case` (예: `required_tags`)

## 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `aws_region` | AWS 리전 | `ap-northeast-2` |
| `environment` | 환경 | `prod` |
| `tfstate_bucket_name` | S3 버킷 이름 | `prod-connectly` |
| `dynamodb_table_name` | DynamoDB 테이블 이름 | `prod-connectly-tf-lock` |
| `service` | 서비스 이름 | `terraform-backend` |
| `owner` | 소유자 이메일 | `platform@ryuqqq.com` |
| `cost_center` | 비용 센터 | `infrastructure` |

## 출력

| 출력 | 설명 |
|------|------|
| `s3_bucket_name` | S3 버킷 이름 |
| `s3_bucket_arn` | S3 버킷 ARN |
| `dynamodb_table_name` | DynamoDB 테이블 이름 |
| `dynamodb_table_arn` | DynamoDB 테이블 ARN |
| `kms_key_id` | KMS 키 ID |
| `kms_key_arn` | KMS 키 ARN |
| `kms_key_alias` | KMS 키 별칭 |

## 보안 고려사항

### S3 버킷 보안
1. **버저닝**: 실수로 삭제된 state 파일 복구 가능
2. **암호화**: KMS 암호화로 저장 데이터 보호
3. **퍼블릭 액세스 차단**: 모든 퍼블릭 액세스 차단
4. **전송 중 암호화**: HTTPS만 허용 (HTTP 거부)
5. **암호화 강제**: 암호화되지 않은 객체 업로드 거부

### DynamoDB 보안
1. **암호화**: KMS 암호화로 저장 데이터 보호
2. **PITR**: 특정 시점 복구로 데이터 손실 방지
3. **PAY_PER_REQUEST**: 용량 계획 불필요, 자동 스케일링

### KMS 키 보안
1. **키 로테이션**: 자동 연간 키 로테이션
2. **삭제 보호**: 30일 삭제 대기 기간

## 유지보수

### State 파일 복구

S3 버전 목록 확인:
```bash
aws s3api list-object-versions \
  --bucket prod-connectly \
  --prefix network/terraform.tfstate
```

특정 버전 복원:
```bash
aws s3api get-object \
  --bucket prod-connectly \
  --key network/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.backup
```

### 잠금 해제

비정상 종료로 인한 잠금 수동 해제:

`terraform force-unlock` 명령어를 사용하는 것이 더 안전하고 권장됩니다.

```bash
# 1. `terraform plan` 실행 시 표시되는 LOCK_ID를 확인합니다.
$ terraform plan
Error: Error acquiring the state lock
...
Lock Info:
  ID:        <LOCK_ID>
...

# 2. 확인된 LOCK_ID로 잠금을 강제 해제합니다.
terraform force-unlock <LOCK_ID>
```

## 참고 문서

- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS Bootstrap Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/bootstrapping.html)
- [CLAUDE.md](../../CLAUDE.md) - 프로젝트 거버넌스 규칙

## 관련 이슈

- Jira: [IN-138 - Bootstrap 인프라 Terraform 코드화](https://ryuqqq.atlassian.net/browse/IN-138)
- Epic: [IN-98 - EPIC 2: 공통 플랫폼 인프라](https://ryuqqq.atlassian.net/browse/IN-98)
