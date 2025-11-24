# KMS Encryption Keys Module

AWS KMS를 사용한 데이터 암호화 키 관리 인프라 모듈입니다.

## 개요

이 모듈은 다음을 제공합니다:
- 데이터 분류 기반 KMS 키 분리 전략
- 자동 키 로테이션 (365일 주기)
- 서비스별 암호화 키 관리
- SSM Parameter Store를 통한 cross-stack 참조
- 표준화된 키 정책 및 태깅

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ ECS      │  │ RDS      │  │ S3       │  │ Lambda   │   │
│  │ Tasks    │  │ Database │  │ Buckets  │  │ Functions│   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │             │          │
│       └─────────────┴──────────────┴─────────────┘          │
│                          │                                   │
└──────────────────────────┼───────────────────────────────────┘
                           │ Encryption
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                   AWS KMS (9 Keys)                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Infrastructure Keys (confidential)                     │ │
│  │  - alias/terraform-state                               │ │
│  │  - alias/cloudwatch-logs                               │ │
│  │  - alias/s3-encryption                                 │ │
│  │  - alias/sqs-encryption                                │ │
│  │  - alias/ssm-encryption                                │ │
│  │  - alias/elasticache-encryption                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Application Keys (highly-confidential)                │ │
│  │  - alias/rds-encryption                                │ │
│  │  - alias/secrets-manager                               │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Service Keys (confidential)                           │ │
│  │  - alias/ecs-secrets                                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Export ARNs
                           ↓
┌─────────────────────────────────────────────────────────────┐
│              SSM Parameter Store (Cross-Stack)               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  /shared/kms/terraform-state-key-arn                   │ │
│  │  /shared/kms/rds-key-arn                               │ │
│  │  /shared/kms/secrets-manager-key-arn                   │ │
│  │  /shared/kms/cloudwatch-logs-key-arn                   │ │
│  │  /shared/kms/s3-key-arn                                │ │
│  │  /shared/kms/sqs-key-arn                               │ │
│  │  /shared/kms/ssm-key-arn                               │ │
│  │  /shared/kms/elasticache-key-arn                       │ │
│  │  /shared/kms/ecs-secrets-key-arn                       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## KMS 키 목록 및 용도

### 1. Terraform State Key (최우선순위)
**Alias**: `alias/terraform-state`
**DataClass**: `confidential`

- **용도**: S3에 저장되는 Terraform state 파일 암호화
- **사용처**:
  - S3 bucket: `ryuqqq-{env}-tfstate`
  - DynamoDB table: `terraform-lock`
- **정책**: Root account 전체 권한
- **로테이션**: 자동 (365일)

```hcl
# 사용 예시
resource "aws_s3_bucket" "tfstate" {
  bucket = "ryuqqq-prod-tfstate"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = data.aws_ssm_parameter.terraform_state_key.value
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
```

### 2. RDS Encryption Key (고도 기밀)
**Alias**: `alias/rds-encryption`
**DataClass**: `highly-confidential`

- **용도**: RDS 인스턴스 스토리지 암호화
- **사용처**:
  - RDS 인스턴스
  - RDS 스냅샷
  - Read Replica
- **정책**: Root account 전체 권한
- **로테이션**: 자동 (365일)

```hcl
# 사용 예시
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id        = data.aws_ssm_parameter.rds_key.value
}
```

### 3. ECS Secrets Key (기밀)
**Alias**: `alias/ecs-secrets`
**DataClass**: `confidential`

- **용도**: ECS Task Definition의 secrets 및 environment 암호화
- **사용처**:
  - ECS Task Definition secrets
  - ECS Task Definition environment variables
- **정책**: Root account 전체 권한
- **로테이션**: 자동 (365일)

```hcl
# 사용 예시
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = "arn:aws:secretsmanager:...:secret:db-password"
    }]
  }])
}
```

### 4. Secrets Manager Key (고도 기밀)
**Alias**: `alias/secrets-manager`
**DataClass**: `highly-confidential`

- **용도**: AWS Secrets Manager 시크릿 암호화
- **사용처**:
  - 데이터베이스 자격증명
  - API 키
  - 애플리케이션 시크릿
- **정책**: Root account 전체 권한
- **로테이션**: 자동 (365일)

```hcl
# 사용 예시
resource "aws_secretsmanager_secret" "db_password" {
  kms_key_id = data.aws_ssm_parameter.secrets_manager_key.value
}
```

### 5. CloudWatch Logs Key (기밀)
**Alias**: `alias/cloudwatch-logs`
**DataClass**: `confidential`

- **용도**: CloudWatch Logs 로그 그룹 암호화
- **사용처**:
  - ECS 컨테이너 로그
  - Lambda 함수 로그
  - Application 로그
- **정책**:
  - Root account 전체 권한
  - CloudWatch Logs 서비스: `Encrypt`, `Decrypt`, `GenerateDataKey`, `CreateGrant`
- **로테이션**: 자동 (365일)

**특별 정책**:
```json
{
  "Sid": "Allow CloudWatch Logs",
  "Effect": "Allow",
  "Principal": {
    "Service": "logs.{region}.amazonaws.com"
  },
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:CreateGrant",
    "kms:DescribeKey"
  ],
  "Resource": "*",
  "Condition": {
    "ArnLike": {
      "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:{region}:{account}:log-group:*"
    }
  }
}
```

```hcl
# 사용 예시
resource "aws_cloudwatch_log_group" "app" {
  kms_key_id = data.aws_ssm_parameter.cloudwatch_logs_key.value
}
```

### 6. S3 Encryption Key (기밀)
**Alias**: `alias/s3-encryption`
**DataClass**: `confidential`

- **용도**: S3 버킷 객체 암호화
- **사용처**:
  - 애플리케이션 파일 스토리지
  - 백업 데이터
  - 정적 자산
- **정책**:
  - Root account 전체 권한
  - S3 서비스: `Decrypt`, `GenerateDataKey`
- **로테이션**: 자동 (365일)

```hcl
# 사용 예시
resource "aws_s3_bucket" "data" {
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = data.aws_ssm_parameter.s3_key.value
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
```

### 7. SQS Encryption Key (기밀)
**Alias**: `alias/sqs-encryption`
**DataClass**: `confidential`

- **용도**: SQS 큐 메시지 암호화
- **사용처**:
  - Application 메시지 큐
  - 이벤트 큐
  - Dead Letter Queue
- **정책**:
  - Root account 전체 권한
  - SQS 서비스: `Decrypt`, `GenerateDataKey`
- **로테이션**: 자동 (365일)

```hcl
# 사용 예시
resource "aws_sqs_queue" "events" {
  kms_master_key_id = data.aws_ssm_parameter.sqs_key.value
}
```

### 8. SSM Parameter Store Key (기밀)
**Alias**: `alias/ssm-encryption`
**DataClass**: `confidential`

- **용도**: SSM Parameter Store SecureString 암호화
- **사용처**:
  - 환경 변수
  - 설정 값
  - Cross-stack 참조 값
- **정책**: Root account 전체 권한
- **로테이션**: 자동 (365일)

```hcl
# 사용 예시
resource "aws_ssm_parameter" "config" {
  type   = "SecureString"
  key_id = data.aws_ssm_parameter.ssm_key.value
}
```

### 9. ElastiCache Encryption Key (기밀)
**Alias**: `alias/elasticache-encryption`
**DataClass**: `confidential`

- **용도**: ElastiCache 클러스터 암호화 (at-rest, in-transit)
- **사용처**:
  - Redis 클러스터
  - Memcached 클러스터
- **정책**: Root account 전체 권한
- **로테이션**: 자동 (365일)

```hcl
# 사용 예시
resource "aws_elasticache_replication_group" "redis" {
  at_rest_encryption_enabled = true
  kms_key_id                 = data.aws_ssm_parameter.elasticache_key.value
}
```

## Cross-Stack 참조 방법

모든 KMS 키 ARN은 SSM Parameter Store에 export되어 다른 스택에서 참조할 수 있습니다.

### SSM Parameter 네이밍 패턴

```
/shared/kms/{key-name}-key-arn
```

### 참조 예시

```hcl
# 다른 스택에서 KMS 키 ARN 참조
data "aws_ssm_parameter" "cloudwatch_logs_key" {
  name = "/shared/kms/cloudwatch-logs-key-arn"
}

data "aws_ssm_parameter" "rds_key" {
  name = "/shared/kms/rds-key-arn"
}

data "aws_ssm_parameter" "secrets_manager_key" {
  name = "/shared/kms/secrets-manager-key-arn"
}

# 사용
resource "aws_cloudwatch_log_group" "app" {
  name       = "/aws/ecs/my-app"
  kms_key_id = data.aws_ssm_parameter.cloudwatch_logs_key.value
}

resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id        = data.aws_ssm_parameter.rds_key.value
}
```

### Export된 SSM Parameters 목록

| SSM Parameter 경로 | KMS 키 | 용도 |
|-------------------|--------|------|
| `/shared/kms/terraform-state-key-arn` | `alias/terraform-state` | Terraform state 암호화 |
| `/shared/kms/rds-key-arn` | `alias/rds-encryption` | RDS 암호화 |
| `/shared/kms/ecs-secrets-key-arn` | `alias/ecs-secrets` | ECS secrets 암호화 |
| `/shared/kms/secrets-manager-key-arn` | `alias/secrets-manager` | Secrets Manager 암호화 |
| `/shared/kms/cloudwatch-logs-key-arn` | `alias/cloudwatch-logs` | CloudWatch Logs 암호화 |
| `/shared/kms/s3-key-arn` | `alias/s3-encryption` | S3 암호화 |
| `/shared/kms/sqs-key-arn` | `alias/sqs-encryption` | SQS 암호화 |
| `/shared/kms/ssm-key-arn` | `alias/ssm-encryption` | SSM Parameter Store 암호화 |
| `/shared/kms/elasticache-key-arn` | `alias/elasticache-encryption` | ElastiCache 암호화 |

## 데이터 분류 전략

### DataClass: highly-confidential
- **민감도**: 최고
- **키**: `rds-encryption`, `secrets-manager`
- **데이터 유형**:
  - 데이터베이스 자격증명
  - API 키
  - 개인정보 (PII)
- **규정 준수**: GDPR, PCI-DSS

### DataClass: confidential
- **민감도**: 높음
- **키**: 나머지 모든 키
- **데이터 유형**:
  - 인프라 설정
  - 애플리케이션 로그
  - 일반 시스템 데이터
- **규정 준수**: 내부 보안 정책

## 키 정책 패턴

### 기본 정책 (대부분의 키)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::{account-id}:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
```

### 서비스 통합 정책 (CloudWatch Logs, S3, SQS)
기본 정책 + 서비스별 추가 Statement:

```json
{
  "Sid": "Allow {Service} to use the key",
  "Effect": "Allow",
  "Principal": {
    "Service": "{service}.amazonaws.com"
  },
  "Action": [
    "kms:Decrypt",
    "kms:GenerateDataKey"
  ],
  "Resource": "*"
}
```

## 보안 모범 사례

### ✅ Do's
1. **최소 권한 원칙**: 필요한 키에만 접근 권한 부여
2. **키 분리**: 데이터 분류에 따라 별도 키 사용
3. **자동 로테이션**: 모든 키에 자동 로테이션 활성화
4. **모니터링**: CloudTrail로 키 사용 추적
5. **Cross-Stack 참조**: SSM Parameter Store 사용

### ❌ Don'ts
1. **키 공유 남용**: 단일 키로 모든 데이터 암호화 금지
2. **수동 로테이션**: 자동 로테이션 비활성화 금지
3. **Hard-coding**: 코드에 KMS 키 ARN 직접 작성 금지
4. **과도한 권한**: `kms:*` 권한 무분별하게 부여 금지

## 거버넌스

### 필수 태그

모든 KMS 키는 다음 태그를 포함해야 합니다:

| 태그 | 설명 | 예시 |
|-----|------|------|
| Name | 키 이름 | `terraform-state`, `rds-encryption` |
| Environment | 환경 | `prod` |
| Service | 서비스 | `kms` |
| Team | 담당 팀 | `platform-team` |
| Owner | 소유자 | `platform-team` |
| CostCenter | 비용 센터 | `infrastructure` |
| ManagedBy | 관리 도구 | `terraform` |
| Project | 프로젝트 | `infrastructure` |
| DataClass | 데이터 분류 | `confidential`, `highly-confidential` |
| Component | 컴포넌트 | `terraform-backend`, `database`, `ecs` 등 |

### 키 삭제 정책

- **Deletion Window**: 30일 (기본값)
- **변경 가능 범위**: 7-30일
- **복구**: 삭제 예약 후 30일 이내 취소 가능

```hcl
variable "key_deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction"
  type        = number
  default     = 30
  validation {
    condition     = var.key_deletion_window_in_days >= 7 && var.key_deletion_window_in_days <= 30
    error_message = "Key deletion window must be between 7 and 30 days."
  }
}
```

## 모니터링

### CloudTrail 이벤트

KMS 키 사용은 CloudTrail에 자동으로 기록됩니다:

```bash
# KMS 키 사용 이벤트 조회
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::KMS::Key \
  --max-results 10

# 특정 키의 Decrypt 호출 조회
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=Decrypt \
  --max-results 50
```

### 주요 모니터링 메트릭

CloudWatch에서 다음 메트릭을 모니터링합니다:

| 메트릭 | 설명 | 알람 임계값 |
|-------|------|------------|
| `NumberOfKeysCreated` | 생성된 키 수 | > 예상치 |
| `NumberOfKeysDeleted` | 삭제 예약된 키 수 | > 0 |
| `KeyAge` | 키 생성 후 경과 시간 | > 365일 (수동 로테이션 필요) |

### CloudWatch Alarms 예시

```hcl
resource "aws_cloudwatch_metric_alarm" "kms_key_deletion" {
  alarm_name          = "kms-key-deletion-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfKeysDeleted"
  namespace           = "AWS/KMS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when KMS key is scheduled for deletion"
}
```

## 비용

**예상 월 비용**:
- KMS 키: $1/키/월 × 9개 = **$9/월**
- KMS 요청:
  - 처음 20,000 요청/월: 무료
  - 이후 $0.03/10,000 요청
- SSM Parameter Store (Standard): 무료

**총 예상 비용**: **$9-12/월** (요청량에 따라 변동)

## 배포

### 전제 조건
- AWS CLI 설치 및 구성
- Terraform 1.5.0 이상
- 적절한 AWS IAM 권한

### 배포 순서

```bash
cd /Users/sangwon-ryu/infrastructure/terraform/environments/prod/kms

# 1. 초기화
terraform init

# 2. 포맷 검사
terraform fmt -check

# 3. 유효성 검사
terraform validate

# 4. 계획 확인
terraform plan

# 5. 적용
terraform apply
```

### 주의사항

1. **삭제 보호**: KMS 키는 즉시 삭제되지 않으며 30일 대기 기간이 있습니다
2. **의존성**: 다른 리소스가 KMS 키를 사용 중이면 삭제가 차단됩니다
3. **우선순위**: 이 모듈은 다른 모든 인프라보다 먼저 배포되어야 합니다
4. **SSM Export**: 키 생성 시 자동으로 SSM Parameter에 ARN이 export됩니다

### 배포 순서 (전체 인프라)

```
1. KMS (이 모듈) ← 최우선
2. Network, Secrets Manager, Logging
3. RDS, ECS (KMS 키 의존성)
```

## 트러블슈팅

### Access Denied 에러

```bash
# KMS 키 정책 확인
aws kms get-key-policy \
  --key-id alias/cloudwatch-logs \
  --policy-name default

# 사용자/역할의 KMS 권한 확인
aws iam get-user-policy \
  --user-name my-user \
  --policy-name kms-access
```

### 키를 찾을 수 없음

```bash
# 키 별칭으로 검색
aws kms describe-key --key-id alias/rds-encryption

# 모든 KMS 키 목록
aws kms list-keys

# 특정 키의 별칭 확인
aws kms list-aliases --key-id <key-id>
```

### SSM Parameter를 찾을 수 없음

```bash
# SSM Parameter 확인
aws ssm get-parameter --name /shared/kms/cloudwatch-logs-key-arn

# 모든 KMS 관련 SSM Parameters 확인
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Option=BeginsWith,Values=/shared/kms/"
```

### 로테이션 실패

```bash
# 키 로테이션 상태 확인
aws kms get-key-rotation-status --key-id alias/rds-encryption

# 키 로테이션 활성화
aws kms enable-key-rotation --key-id <key-id>
```

## 📥 Variables

이 모듈은 다음과 같은 입력 변수를 사용합니다:

### 기본 설정
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `environment` | 환경 이름 (dev, staging, prod) | `string` | `prod` | No |
| `aws_region` | AWS 리전 | `string` | `ap-northeast-2` | No |
| `service` | 서비스 이름 | `string` | `kms` | No |
| `project` | 프로젝트 이름 | `string` | `infrastructure` | No |

### 태그 관련
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `team` | 담당 팀 | `string` | `platform-team` | No |
| `owner` | 소유자 이메일 또는 식별자 | `string` | `platform-team` | No |
| `cost_center` | 비용 센터 | `string` | `infrastructure` | No |
| `managed_by` | 관리 도구 | `string` | `terraform` | No |

### KMS 키 구성
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `key_deletion_window_in_days` | 키 삭제 전 대기 기간 (7-30일) | `number` | `30` | No |
| `enable_key_rotation` | 자동 키 로테이션 활성화 | `bool` | `true` | No |
| `github_actions_role_name` | GitHub Actions IAM 역할 이름 | `string` | `GitHubActionsRole` | No |

전체 변수 목록은 [variables.tf](./variables.tf) 파일을 참조하세요.

## 📤 Outputs

이 모듈은 다음과 같은 출력 값을 제공합니다:

### Terraform State Key
| 출력 이름 | 설명 |
|-----------|------|
| `terraform_state_key_id` | Terraform state 암호화 KMS 키 ID |
| `terraform_state_key_arn` | Terraform state 암호화 KMS 키 ARN |
| `terraform_state_key_alias` | Terraform state 암호화 KMS 키 별칭 |

### RDS Key
| 출력 이름 | 설명 |
|-----------|------|
| `rds_key_id` | RDS 암호화 KMS 키 ID |
| `rds_key_arn` | RDS 암호화 KMS 키 ARN |
| `rds_key_alias` | RDS 암호화 KMS 키 별칭 |

### ECS Secrets Key
| 출력 이름 | 설명 |
|-----------|------|
| `ecs_secrets_key_id` | ECS secrets 암호화 KMS 키 ID |
| `ecs_secrets_key_arn` | ECS secrets 암호화 KMS 키 ARN |
| `ecs_secrets_key_alias` | ECS secrets 암호화 KMS 키 별칭 |

### Secrets Manager Key
| 출력 이름 | 설명 |
|-----------|------|
| `secrets_manager_key_id` | Secrets Manager 암호화 KMS 키 ID |
| `secrets_manager_key_arn` | Secrets Manager 암호화 KMS 키 ARN |
| `secrets_manager_key_alias` | Secrets Manager 암호화 KMS 키 별칭 |

### CloudWatch Logs Key
| 출력 이름 | 설명 |
|-----------|------|
| `cloudwatch_logs_key_id` | CloudWatch Logs 암호화 KMS 키 ID |
| `cloudwatch_logs_key_arn` | CloudWatch Logs 암호화 KMS 키 ARN |
| `cloudwatch_logs_key_alias` | CloudWatch Logs 암호화 KMS 키 별칭 |

### 요약 정보
| 출력 이름 | 설명 |
|-----------|------|
| `kms_keys_summary` | 생성된 모든 KMS 키의 요약 정보 (ID, ARN, Alias) |

**참고**: S3, SQS, SSM, ElastiCache 키의 출력은 SSM Parameter Store를 통해서만 접근 가능합니다 (직접 output 없음).

전체 출력 목록은 [outputs.tf](./outputs.tf) 파일을 참조하세요.

## 참고 자료

- [KMS Strategy Guide](../../../docs/kms-strategy.md)
- [Data Classification Policy](../../../docs/governance/data-classification.md)
- [Infrastructure Governance](../../../docs/infrastructure_governance.md)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/)
- [AWS KMS Best Practices](https://docs.aws.amazon.com/kms/latest/developerguide/best-practices.html)
