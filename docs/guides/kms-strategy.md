# KMS 키 전략 가이드

## 개요

이 문서는 공통 플랫폼 인프라를 위한 KMS 키 전략 및 사용 가이드를 제공합니다.

## 아키텍처

### 설계 원칙

1. **Data-Class Based Key Separation**: 데이터 분류 수준에 따라 키 분리
2. **Customer-Managed Keys Only**: AWS 관리형 키 사용 금지
3. **Automatic Key Rotation**: 모든 키에 자동 로테이션 활성화
4. **Least Privilege Access**: 최소 권한 원칙 적용

### 키 구성

```
terraform/kms/
├── main.tf          # 4개 KMS 키 리소스
├── policies.tf      # 키별 IAM 정책
├── variables.tf     # 입력 변수
├── outputs.tf       # 키 ID/ARN 출력
├── provider.tf      # Backend 구성
└── locals.tf        # required_tags 정의
```

## 생성된 KMS 키

### 1. Terraform State 암호화 키 (terraform-state)

**용도**: Terraform State 파일 S3 암호화

**DataClass**: confidential

**Alias**: `alias/terraform-state`

**권한**:
- S3 서비스: Decrypt, GenerateDataKey
- GitHub Actions Role: Encrypt, Decrypt, DescribeKey, GenerateDataKey, ReEncrypt
- Terraform 실행 계정: Full access via ViaService condition

**사용 방법**:
```hcl
terraform {
  backend "s3" {
    bucket         = "prod-tfstate"
    key            = "module-name/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "prod-tfstate-tf-lock"
    encrypt        = true
    kms_key_id     = "alias/terraform-state"  # 추가
  }
}
```

### 2. RDS 암호화 키 (rds-encryption)

**용도**: RDS 인스턴스 및 스냅샷 암호화

**DataClass**: highly-confidential

**Alias**: `alias/rds-encryption`

**권한**:
- RDS 서비스: Decrypt, DescribeKey, CreateGrant, GenerateDataKey
- GitHub Actions Role: Decrypt, DescribeKey, CreateGrant, GenerateDataKey

**사용 방법**:
```hcl
resource "aws_db_instance" "example" {
  # ... other configuration ...

  storage_encrypted = true
  kms_key_id        = data.terraform_remote_state.kms.outputs.rds_key_arn
}
```

### 3. ECS Secrets 암호화 키 (ecs-secrets)

**용도**: ECS 태스크 환경변수 및 시크릿 암호화

**DataClass**: confidential

**Alias**: `alias/ecs-secrets`

**권한**:
- ECS Tasks 서비스: Decrypt, DescribeKey
- Secrets Manager 서비스: Decrypt, DescribeKey, GenerateDataKey
- GitHub Actions Role: Encrypt, Decrypt, DescribeKey, GenerateDataKey, CreateGrant

**사용 방법**:
```hcl
resource "aws_ecs_task_definition" "example" {
  # ... other configuration ...

  container_definitions = jsonencode([{
    # ... container config ...
    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = aws_secretsmanager_secret.db_password.arn
    }]
  }])
}

resource "aws_secretsmanager_secret" "db_password" {
  name       = "db-password"
  kms_key_id = data.terraform_remote_state.kms.outputs.ecs_secrets_key_id
}
```

### 4. Secrets Manager 암호화 키 (secrets-manager)

**용도**: AWS Secrets Manager 전용 암호화

**DataClass**: highly-confidential

**Alias**: `alias/secrets-manager`

**권한**:
- Secrets Manager 서비스: Decrypt, DescribeKey, GenerateDataKey, CreateGrant, RetireGrant
- 애플리케이션 역할: Decrypt, DescribeKey (via Secrets Manager service)
- GitHub Actions Role: Encrypt, Decrypt, DescribeKey, GenerateDataKey, CreateGrant

**사용 방법**:
```hcl
resource "aws_secretsmanager_secret" "app_secret" {
  name       = "application-secret"
  kms_key_id = data.terraform_remote_state.kms.outputs.secrets_manager_key_id
}
```

## Remote State 참조

다른 Terraform 모듈에서 KMS 키를 참조하는 방법:

```hcl
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = "prod-tfstate"
    key    = "kms/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 사용 예시
resource "aws_s3_bucket" "example" {
  bucket = "example-bucket"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = data.terraform_remote_state.kms.outputs.terraform_state_key_arn
      }
    }
  }
}
```

## 배포

### 초기 배포

```bash
cd terraform/kms

# 초기화
terraform init

# 계획 확인
terraform plan

# 적용
terraform apply
```

### 주의사항

1. **순환 참조 방지**: KMS 모듈은 다른 모듈에 의존하지 않도록 설계
2. **Backend 설정**: 초기 배포 시에는 KMS 키 없이 시작, 배포 후 backend 설정 업데이트
3. **키 삭제**: 30일 대기 기간 이후 영구 삭제됨

## 키 로테이션

### 자동 로테이션

모든 키는 `enable_key_rotation = true`로 설정되어 있어 AWS에서 자동으로 1년마다 로테이션합니다.

**특징**:
- 기존 키 ID는 변경되지 않음
- 이전 키 버전은 자동으로 유지되어 이전 데이터 복호화 가능
- 애플리케이션 코드 변경 불필요

### 로테이션 확인

```bash
# 키 로테이션 상태 확인
aws kms get-key-rotation-status \
  --key-id alias/terraform-state \
  --region ap-northeast-2
```

## 모니터링 및 감사

### CloudTrail 로깅

모든 KMS 키 사용은 CloudTrail에 자동으로 기록됩니다:

- `Encrypt`, `Decrypt` 작업 추적
- 키 정책 변경 감사
- 키 생성/삭제 이벤트

### 비용 모니터링

- 키 생성 비용: $1/월/키 (총 $4/월)
- API 요청 비용: 무료 티어 10,000 요청/월 초과 시 $0.03/10,000 요청

## 트러블슈팅

### 문제: Access Denied 에러

**원인**: IAM 역할에 KMS 키 사용 권한 없음

**해결**:
```hcl
# IAM 정책에 추가
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "arn:aws:kms:ap-northeast-2:ACCOUNT_ID:key/KEY_ID"
}
```

### 문제: Key is pending deletion

**원인**: 키가 삭제 예약 상태

**해결**:
```bash
# 삭제 취소
aws kms cancel-key-deletion \
  --key-id alias/terraform-state \
  --region ap-northeast-2
```

### 문제: Terraform state lock 실패

**원인**: DynamoDB 테이블 또는 KMS 키 권한 문제

**해결**:
1. GitHub Actions Role에 적절한 권한 확인
2. KMS 키 정책에서 ViaService condition 확인
3. DynamoDB 테이블 존재 여부 확인

## 보안 모범 사례

1. **최소 권한 원칙**: 필요한 작업에만 최소한의 권한 부여
2. **ViaService Condition**: 특정 AWS 서비스를 통해서만 키 사용 허용
3. **키 분리**: 용도별로 키를 분리하여 영향 범위 최소화
4. **정기 감사**: CloudTrail 로그를 정기적으로 검토
5. **삭제 보호**: 30일 대기 기간 활용하여 실수로 인한 삭제 방지

## 거버넌스 준수

### 필수 태그

모든 KMS 키는 다음 태그를 포함합니다:

- `Owner`: platform-team
- `CostCenter`: infrastructure
- `Environment`: prod
- `Lifecycle`: permanent
- `DataClass`: confidential/highly-confidential
- `Service`: common-platform
- `ManagedBy`: terraform
- `Project`: infrastructure

### 네이밍 규칙

- 키 리소스: snake_case (예: `aws_kms_key.terraform_state`)
- 키 Alias: kebab-case (예: `alias/terraform-state`)
- 파일명: kebab-case (예: `kms-strategy.md`)

## 참고 자료

- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
- [Terraform AWS KMS Key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key)
- [Infrastructure Governance Guide](../docs/infrastructure_governance.md)
