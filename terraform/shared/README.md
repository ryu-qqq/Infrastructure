# Shared 리소스 크로스 스택 참조 아키텍처

SSM Parameter Store를 사용한 Terraform 스택 간 리소스 공유 패턴입니다. 이 디렉토리는 **물리적 공유 리소스를 포함하지 않으며**, 대신 다른 스택에서 생성된 리소스를 SSM Parameter Store를 통해 참조하는 **아키텍처 패턴**을 문서화합니다.

## 📋 목차

- [개요](#개요)
- [아키텍처 원칙](#아키텍처-원칙)
- [공유 리소스 목록](#공유-리소스-목록)
- [사용 방법](#사용-방법)
- [베스트 프랙티스](#베스트-프랙티스)
- [보안 고려사항](#보안-고려사항)
- [Troubleshooting](#troubleshooting)

---

## 개요

이 디렉토리는 Terraform 스택 간에 리소스를 공유하는 방법을 문서화합니다. 직접적인 스택 간 의존성 대신 **SSM Parameter Store를 중간 레이어**로 사용하여 느슨한 결합을 유지합니다.

### 주요 특징

- ✅ **느슨한 결합**: 스택 간 직접 의존성 제거
- ✅ **독립적 배포**: 각 스택을 독립적으로 배포 가능
- ✅ **버전 독립적**: 스택 버전과 무관하게 리소스 참조
- ✅ **순환 의존성 방지**: 간접 참조로 순환 의존성 해결
- ✅ **중앙 집중식 관리**: 모든 공유 리소스를 한 곳에서 관리

### 왜 직접 참조가 아닌 SSM Parameter를 사용하나요?

**직접 참조의 문제점**:
```hcl
# ❌ 나쁜 예: 직접 스택 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "tfstate-bucket"
    key    = "network/terraform.tfstate"
  }
}

# 문제:
# - network 스택이 먼저 배포되어야 함
# - network 스택 변경 시 이 스택도 재배포 필요
# - 순환 의존성 발생 가능
# - 스택 간 강한 결합
```

**SSM Parameter 패턴의 이점**:
```hcl
# ✅ 좋은 예: SSM Parameter 참조
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

# 이점:
# - 스택 간 독립적 배포
# - 느슨한 결합
# - 순환 의존성 방지
# - 버전 관리 용이
```

---

## 아키텍처 원칙

### Producer-Consumer 패턴

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│  Producer   │         │  SSM Parameter   │         │  Consumer   │
│   Stack     │────────>│     Store        │<────────│   Stack     │
│  (KMS, VPC) │ Write   │  (Middle Layer)  │  Read   │ (ECS, RDS)  │
└─────────────┘         └──────────────────┘         └─────────────┘
```

1. **Producer 스택**: 리소스 생성 후 ARN/ID를 SSM Parameter에 저장
2. **SSM Parameter Store**: 중앙 집중식 리소스 레지스트리
3. **Consumer 스택**: SSM Parameter에서 리소스 정보 조회

### 디렉토리 구조

```
terraform/shared/
├── README.md              # 이 파일 (아키텍처 문서)
├── CHANGELOG.md           # 변경 이력
├── kms/                   # (빈 디렉토리 - 실제 KMS 리소스는 terraform/kms에 있음)
├── network/               # (빈 디렉토리 - 실제 Network 리소스는 terraform/network에 있음)
└── security/              # (빈 디렉토리 - 실제 Security 리소스는 terraform/security에 있음)
```

**중요**: `kms/`, `network/`, `security/` 디렉토리는 **빈 디렉토리**입니다. 실제 리소스는 각각의 Terraform 스택에서 생성되며, 이 디렉토리는 공유 패턴을 문서화하는 용도입니다.

---

## 공유 리소스 목록

현재 SSM Parameter Store를 통해 공유되는 **19개**의 리소스가 있습니다.

### 1. KMS 암호화 키 (8개)

모든 암호화 키는 고객 관리형 KMS 키이며, 각 데이터 클래스별로 분리되어 있습니다.

| Parameter 경로 | 설명 | Producer | Consumer |
|---------------|------|----------|----------|
| `/shared/kms/cloudwatch-logs-key-arn` | CloudWatch Logs 암호화 키 | `terraform/kms` | `terraform/logging`, `terraform/monitoring` |
| `/shared/kms/secrets-manager-key-arn` | Secrets Manager 암호화 키 | `terraform/kms` | `terraform/secrets`, `terraform/atlantis` |
| `/shared/kms/rds-key-arn` | RDS 암호화 키 | `terraform/kms` | `terraform/rds` |
| `/shared/kms/s3-key-arn` | S3 버킷 암호화 키 | `terraform/kms` | `terraform/logging`, `terraform/bootstrap` |
| `/shared/kms/sqs-key-arn` | SQS 큐 암호화 키 | `terraform/kms` | 향후 메시징 서비스 |
| `/shared/kms/ssm-key-arn` | SSM Parameter 암호화 키 | `terraform/kms` | 민감한 파라미터 저장 시 |
| `/shared/kms/elasticache-key-arn` | ElastiCache 암호화 키 | `terraform/kms` | 향후 캐시 서비스 |
| `/shared/kms/ecs-secrets-key-arn` | ECS Secrets 암호화 키 | `terraform/kms` | `terraform/ecr`, ECS 태스크 |

**사용 예시**:
```hcl
# CloudWatch Log Group 생성 시 KMS 키 사용
data "aws_ssm_parameter" "cloudwatch_logs_key" {
  name = "/shared/kms/cloudwatch-logs-key-arn"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/my-app"
  kms_key_id        = data.aws_ssm_parameter.cloudwatch_logs_key.value
  retention_in_days = 7
}
```

### 2. 네트워크 리소스 (3개)

VPC 및 서브넷 정보는 모든 애플리케이션 스택에서 공통으로 사용됩니다.

| Parameter 경로 | 설명 | Producer | Consumer |
|---------------|------|----------|----------|
| `/shared/network/vpc-id` | VPC ID | `terraform/network` | `terraform/rds`, `terraform/atlantis`, ECS 서비스 |
| `/shared/network/public-subnet-ids` | 퍼블릭 서브넷 ID 목록 (쉼표 구분) | `terraform/network` | ALB, NAT Gateway |
| `/shared/network/private-subnet-ids` | 프라이빗 서브넷 ID 목록 (쉼표 구분) | `terraform/network` | ECS 태스크, RDS, ElastiCache |

**사용 예시**:
```hcl
# ECS 서비스를 프라이빗 서브넷에 배포
data "aws_ssm_parameter" "vpc_id" {
  name = "/shared/network/vpc-id"
}

data "aws_ssm_parameter" "private_subnets" {
  name = "/shared/network/private-subnet-ids"
}

resource "aws_ecs_service" "app" {
  name            = "my-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn

  network_configuration {
    subnets         = split(",", data.aws_ssm_parameter.private_subnets.value)
    security_groups = [aws_security_group.app.id]
  }
}
```

### 3. ECR 리포지토리 (1개)

컨테이너 이미지 저장소 URL 공유.

| Parameter 경로 | 설명 | Producer | Consumer |
|---------------|------|----------|----------|
| `/shared/ecr/fileflow-repository-url` | FileFlow ECR 리포지토리 URL | `terraform/ecr/fileflow` | FileFlow ECS 태스크 정의 |

**사용 예시**:
```hcl
# ECS 태스크 정의에서 ECR 이미지 사용
data "aws_ssm_parameter" "fileflow_ecr_url" {
  name = "/shared/ecr/fileflow-repository-url"
}

resource "aws_ecs_task_definition" "fileflow" {
  family = "fileflow"

  container_definitions = jsonencode([{
    name  = "fileflow"
    image = "${data.aws_ssm_parameter.fileflow_ecr_url.value}:latest"
    # ...
  }])
}
```

### 4. RDS 데이터베이스 (5개)

데이터베이스 연결 정보 공유.

| Parameter 경로 | 설명 | Producer | Consumer |
|---------------|------|----------|----------|
| `/shared/rds/db-instance-id` | RDS 인스턴스 ID | `terraform/rds` | 모니터링, 백업 |
| `/shared/rds/address` | RDS 엔드포인트 주소 | `terraform/rds` | 애플리케이션 스택 |
| `/shared/rds/port` | RDS 포트 번호 | `terraform/rds` | 애플리케이션 스택 |
| `/shared/rds/security-group-id` | RDS 보안 그룹 ID | `terraform/rds` | 애플리케이션 보안 그룹 인바운드 규칙 |
| `/shared/rds/master-password-secret-name` | RDS 마스터 비밀번호 Secrets Manager 이름 | `terraform/rds` | 애플리케이션 스택 |

**사용 예시**:
```hcl
# 애플리케이션에서 RDS 연결 정보 사용
data "aws_ssm_parameter" "db_address" {
  name = "/shared/rds/address"
}

data "aws_ssm_parameter" "db_port" {
  name = "/shared/rds/port"
}

data "aws_ssm_parameter" "db_password_secret" {
  name = "/shared/rds/master-password-secret-name"
}

# 데이터베이스 연결 URL 구성
locals {
  db_url = "postgresql://admin:${data.aws_secretsmanager_secret_version.db_password.secret_string}@${data.aws_ssm_parameter.db_address.value}:${data.aws_ssm_parameter.db_port.value}/mydb"
}
```

### 5. Secrets Manager 비밀 (2개)

민감한 정보 참조.

| Parameter 경로 | 설명 | Producer | Consumer |
|---------------|------|----------|----------|
| `/shared/secrets/atlantis-webhook-secret-arn` | Atlantis Webhook Secret ARN | `terraform/secrets` | `terraform/atlantis` |
| `/shared/secrets/atlantis-github-token-arn` | Atlantis GitHub Token ARN | `terraform/secrets` | `terraform/atlantis` |

**사용 예시**:
```hcl
# Atlantis ECS 태스크에서 GitHub 토큰 사용
data "aws_ssm_parameter" "github_token_arn" {
  name = "/shared/secrets/atlantis-github-token-arn"
}

resource "aws_ecs_task_definition" "atlantis" {
  family = "atlantis"

  container_definitions = jsonencode([{
    name = "atlantis"
    secrets = [
      {
        name      = "ATLANTIS_GH_TOKEN"
        valueFrom = data.aws_ssm_parameter.github_token_arn.value
      }
    ]
  }])
}
```

---

## 사용 방법

### 1. Producer: SSM Parameter 생성

리소스를 생성하는 스택에서 SSM Parameter로 내보내기:

```hcl
# terraform/kms/main.tf
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_ssm_parameter" "rds_key_arn" {
  name        = "/shared/kms/rds-key-arn"
  description = "RDS encryption KMS key ARN for cross-stack references"
  type        = "String"
  value       = aws_kms_key.rds.arn

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-kms-key-arn-export"
      Component = "kms"
    }
  )
}
```

### 2. Consumer: SSM Parameter 참조

리소스를 사용하는 스택에서 SSM Parameter 조회:

```hcl
# terraform/rds/main.tf
data "aws_ssm_parameter" "rds_key_arn" {
  name = "/shared/kms/rds-key-arn"
}

resource "aws_db_instance" "main" {
  identifier     = "prod-database"
  engine         = "postgres"
  engine_version = "15.3"

  # SSM Parameter에서 조회한 KMS 키 사용
  kms_key_id = data.aws_ssm_parameter.rds_key_arn.value

  storage_encrypted = true
  # ...
}
```

### 3. 배포 순서

1. **Producer 스택 먼저 배포**:
   ```bash
   cd terraform/kms
   terraform apply
   ```

2. **SSM Parameter 확인**:
   ```bash
   aws ssm get-parameter --name "/shared/kms/rds-key-arn"
   ```

3. **Consumer 스택 배포**:
   ```bash
   cd terraform/rds
   terraform apply
   ```

---

## 베스트 프랙티스

### 1. 네이밍 규칙

```
/shared/{category}/{resource-name}-{attribute}

예시:
✅ /shared/kms/rds-key-arn
✅ /shared/network/vpc-id
✅ /shared/ecr/fileflow-repository-url

❌ /kms/rds/key  (카테고리 누락)
❌ /shared/rds-key  (카테고리 없음)
```

### 2. Parameter 타입 선택

- **String**: 일반적인 ARN, ID, URL (대부분의 경우)
- **StringList**: 서브넷 ID 목록 같은 배열 (쉼표 구분)
- **SecureString**: 민감한 정보 (하지만 Secrets Manager를 우선 사용)

```hcl
# 일반 리소스 ID
resource "aws_ssm_parameter" "vpc_id" {
  type  = "String"
  value = aws_vpc.main.id
}

# 리스트 타입 (쉼표로 구분)
resource "aws_ssm_parameter" "subnet_ids" {
  type  = "String"  # StringList가 아닌 String 사용
  value = join(",", aws_subnet.private[*].id)
}

# 민감한 정보는 Secrets Manager ARN만 저장
resource "aws_ssm_parameter" "db_secret_arn" {
  type  = "String"
  value = aws_secretsmanager_secret.db_password.arn
}
```

### 3. 설명 작성

```hcl
resource "aws_ssm_parameter" "vpc_id" {
  name        = "/shared/network/vpc-id"

  # ✅ 좋은 설명: 용도와 참조 스택 명시
  description = "Production VPC ID for cross-stack references (used by ECS, RDS, ElastiCache)"

  # ❌ 나쁜 설명
  # description = "VPC ID"
}
```

### 4. 태그 표준 준수

```hcl
resource "aws_ssm_parameter" "rds_key_arn" {
  name  = "/shared/kms/rds-key-arn"
  type  = "String"
  value = aws_kms_key.rds.arn

  tags = merge(
    local.required_tags,  # 필수: Owner, CostCenter, Environment, Lifecycle, DataClass
    {
      Name      = "rds-kms-key-arn-export"
      Component = "kms"
      Purpose   = "cross-stack-reference"
    }
  )
}
```

### 5. 변경 영향 분석

Parameter 값을 변경하기 전에:

```bash
# 1. 어떤 스택에서 이 Parameter를 사용하는지 확인
aws resourcegroupstaggingapi get-resources \
  --resource-type-filters ssm:parameter \
  --tag-filters Key=Name,Values=rds-kms-key-arn-export

# 2. 각 Consumer 스택에서 영향 분석
cd terraform/rds
terraform plan  # Parameter 변경 시 어떤 리소스가 영향받는지 확인

# 3. 주의해서 변경
terraform apply
```

### 6. 문서화

새 공유 리소스를 추가할 때:

1. 이 README.md의 [공유 리소스 목록](#공유-리소스-목록)에 추가
2. Producer와 Consumer 스택 명시
3. 사용 예시 코드 추가
4. CHANGELOG.md에 기록

---

## 보안 고려사항

### 1. IAM 권한

**Producer 스택 권한** (SSM Parameter 생성):
```json
{
  "Effect": "Allow",
  "Action": [
    "ssm:PutParameter",
    "ssm:AddTagsToResource"
  ],
  "Resource": "arn:aws:ssm:ap-northeast-2:*:parameter/shared/*"
}
```

**Consumer 스택 권한** (SSM Parameter 읽기):
```json
{
  "Effect": "Allow",
  "Action": [
    "ssm:GetParameter",
    "ssm:GetParameters"
  ],
  "Resource": "arn:aws:ssm:ap-northeast-2:*:parameter/shared/*"
}
```

### 2. 민감한 정보 관리

**절대 하지 말아야 할 것**:
```hcl
# ❌ SSM Parameter에 직접 비밀번호 저장
resource "aws_ssm_parameter" "db_password" {
  name  = "/shared/rds/password"
  type  = "SecureString"
  value = "my-super-secret-password"  # 절대 안됨!
}
```

**올바른 방법**:
```hcl
# ✅ Secrets Manager에 비밀 저장
resource "aws_secretsmanager_secret" "db_password" {
  name       = "prod-rds-master-password"
  kms_key_id = data.aws_ssm_parameter.secrets_key.value
}

# ✅ SSM Parameter에는 Secrets Manager ARN만 저장
resource "aws_ssm_parameter" "db_password_secret_name" {
  name  = "/shared/rds/master-password-secret-name"
  type  = "String"  # SecureString 아님
  value = aws_secretsmanager_secret.db_password.name
}
```

### 3. KMS 암호화

민감한 Parameter는 KMS로 암호화:

```hcl
resource "aws_ssm_parameter" "sensitive_data" {
  name   = "/shared/app/config"
  type   = "SecureString"
  value  = "some-config-value"

  # KMS 키 지정 (지정하지 않으면 AWS 관리형 키 사용)
  key_id = data.aws_ssm_parameter.ssm_key.value
}
```

### 4. 최소 권한 원칙

```hcl
# Consumer 스택 IAM Role
resource "aws_iam_role_policy" "ecs_ssm_access" {
  name = "ssm-parameter-read"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ]
      # 필요한 Parameter만 허용
      Resource = [
        "arn:aws:ssm:ap-northeast-2:*:parameter/shared/kms/ecs-secrets-key-arn",
        "arn:aws:ssm:ap-northeast-2:*:parameter/shared/ecr/fileflow-repository-url"
      ]
    }]
  })
}
```

---

## Troubleshooting

### 1. Parameter를 찾을 수 없음

**증상**:
```
Error: error reading SSM Parameter (/shared/kms/rds-key-arn): ParameterNotFound
```

**해결**:
```bash
# 1. Parameter가 존재하는지 확인
aws ssm get-parameter --name "/shared/kms/rds-key-arn"

# 2. Producer 스택이 배포되었는지 확인
cd terraform/kms
terraform state show aws_ssm_parameter.rds_key_arn

# 3. 리전이 올바른지 확인
aws ssm get-parameter --name "/shared/kms/rds-key-arn" --region ap-northeast-2
```

### 2. IAM 권한 거부

**증상**:
```
Error: AccessDenied: User is not authorized to perform: ssm:GetParameter
```

**해결**:
```bash
# 1. 현재 IAM 권한 확인
aws sts get-caller-identity

# 2. 필요한 권한 추가 (위의 [IAM 권한](#1-iam-권한) 참조)

# 3. Terraform execution role 확인
terraform state show aws_iam_role.terraform_execution
```

### 3. 순환 의존성

**증상**:
```
Error: Cycle: module.network, module.ecs
```

**원인**: 두 스택이 서로를 참조

**해결**: SSM Parameter 패턴 사용으로 해결 (이미 적용됨)

### 4. Parameter 값 불일치

**증상**: Parameter는 존재하지만 값이 예상과 다름

**해결**:
```bash
# 1. Parameter 값 확인
aws ssm get-parameter --name "/shared/kms/rds-key-arn" --query "Parameter.Value" --output text

# 2. Producer 스택의 실제 리소스 ARN 확인
cd terraform/kms
terraform output kms_rds_key_arn

# 3. 값이 다르면 Producer 스택 재배포
terraform apply
```

---

## 📥 Variables

이 디렉토리는 공유 리소스 정의와 예시를 포함하는 컬렉션으로, 중앙화된 변수 파일이 없습니다. 각 하위 모듈(`kms/`, `network/`, `security/`)은 자체적인 variables.tf 파일을 가지고 있습니다.

### 하위 모듈별 변수
- **kms/**: KMS 키 관련 변수 - [kms/variables.tf](./kms/variables.tf) 참조
- **network/**: 네트워크 리소스 변수 - [network/variables.tf](./network/variables.tf) 참조
- **security/**: 보안 그룹 변수 - [security/variables.tf](./security/variables.tf) 참조

## 📤 Outputs

이 디렉토리는 공유 리소스의 컬렉션으로, 중앙화된 outputs.tf 파일이 없습니다. 각 하위 모듈은 자체적인 outputs.tf 파일을 통해 SSM Parameter Store에 값을 저장합니다.

### SSM Parameter 네이밍 패턴
공유 리소스는 다음 패턴으로 SSM Parameter에 저장됩니다:
- KMS 키: `/shared/kms/{purpose}-key-arn` (예: `/shared/kms/rds-key-arn`)
- 네트워크: `/shared/network/{resource}` (예: `/shared/network/vpc-id`)
- RDS: `/shared/rds/{attribute}` (예: `/shared/rds/endpoint`)

### 하위 모듈별 출력
- **kms/**: KMS 키 ARN들 - [kms/outputs.tf](./kms/outputs.tf) 참조
- **network/**: VPC, 서브넷 ID들 - [network/outputs.tf](./network/outputs.tf) 참조
- **security/**: 보안 그룹 ID들 - [security/outputs.tf](./security/outputs.tf) 참조

## 관련 문서

### 내부 문서
- [Infrastructure Governance](../../docs/governance/infrastructure_governance.md) - 태그 표준, 리소스 네이밍
- [KMS Strategy](../../docs/guides/kms-strategy.md) - KMS 키 관리 전략
- [Terraform Best Practices](../../docs/guides/terraform-best-practices.md) - Terraform 코딩 표준

### AWS 공식 문서
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)
- [Terraform Data Sources](https://www.terraform.io/language/data-sources)

---

## 다음 단계

### 현재 공유 리소스
- ✅ KMS 키 8개
- ✅ 네트워크 리소스 3개
- ✅ ECR 리포지토리 1개
- ✅ RDS 정보 5개
- ✅ Secrets Manager 비밀 2개
- **총 19개 Parameter 관리 중**

### 추가 계획
- [ ] ElastiCache 엔드포인트 공유 (필요 시)
- [ ] ALB ARN 공유 (필요 시)
- [ ] CloudFront 배포 ID 공유 (필요 시)
- [ ] 공유 Parameter 사용 현황 모니터링 대시보드

---

**Last Updated**: 2025-10-22
**Maintained By**: Platform Team
