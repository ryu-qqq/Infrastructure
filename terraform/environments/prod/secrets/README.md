# Secrets Manager 모듈

AWS Secrets Manager 기반 중앙 집중식 비밀 정보 관리 및 자동 로테이션 시스템.

## 개요

이 모듈은 AWS Secrets Manager를 사용하여 RDS 자격증명, API 키, 기타 민감한 정보를 안전하게 관리하고 자동으로 로테이션합니다. Lambda 기반 로테이션 함수를 통해 보안 컴플라이언스를 자동화합니다.

## 생성 리소스

| 리소스 | 이름 | 용도 |
|--------|------|------|
| Secrets Manager Secret | `/{org}/common/{env}/db-master` | RDS 마스터 자격증명 |
| Secrets Manager Secret | `/{org}/common/{env}/api-key-example` | API 키 예제 |
| Lambda Function | `rotation` | Secrets 자동 로테이션 |
| IAM Role | `secrets-manager-rotation-lambda-role` | Lambda 실행 역할 |
| Security Group | `secrets-manager-rotation-lambda-sg` | Lambda 네트워크 보안 |
| CloudWatch Alarm | `rotation-failures` | 로테이션 실패 알림 |
| CloudWatch Alarm | `rotation-duration` | 로테이션 지연 알림 |

## 주요 기능

- ✅ KMS 고객 관리형 키를 통한 암호화
- ✅ Lambda 기반 자동 비밀번호 로테이션 (RDS MySQL)
- ✅ VPC 내 Lambda 배포로 RDS 안전 접근
- ✅ 로테이션 실패 및 성능 모니터링
- ✅ 서비스별 최소 권한 IAM 정책
- ✅ 30일 복구 창으로 실수 방지

## 사용법

### Secrets Manager 스택 배포

```bash
cd terraform/environments/prod/secrets
terraform init
terraform plan
terraform apply
```

### Lambda 배포 패키지 빌드

```bash
cd lambda
./build.sh
```

빌드 스크립트는 다음을 수행합니다:
1. Python 의존성 설치 (`requirements.txt` - pymysql)
2. Lambda 함수 코드와 의존성을 `rotation.zip`으로 패키징

### 다른 모듈에서 Secret 참조

```hcl
# Secret 값 읽기
data "aws_secretsmanager_secret_version" "db_master" {
  secret_id = "/${local.org_name}/common/prod/db-master"
}

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.db_master.secret_string)
}

# RDS 연결에 사용
resource "aws_db_instance" "example" {
  username = local.db_credentials.username
  password = local.db_credentials.password
}
```

### 서비스별 Secret 생성 패턴

```hcl
# 서비스별 Secret 생성 예제
resource "aws_secretsmanager_secret" "crawler_api_key" {
  name        = "/ryuqqq/crawler/prod/api-key"
  description = "Crawler service API key"
  kms_key_id  = local.secrets_manager_kms_key_id

  tags = merge(local.required_tags, {
    Name       = "/ryuqqq/crawler/prod/api-key"
    SecretType = "api_key"
    Component  = "secret"
  })
}

resource "aws_secretsmanager_secret_version" "crawler_api_key" {
  secret_id     = aws_secretsmanager_secret.crawler_api_key.id
  secret_string = jsonencode({
    api_key = random_password.crawler_api_key.result
  })
}
```

## 출력

### KMS 키 정보
- `secrets_manager_kms_key_id`: Secrets Manager 암호화용 KMS 키 ID
- `secrets_manager_kms_key_arn`: Secrets Manager 암호화용 KMS 키 ARN

### Secret 정보
- `example_secret_arns`: 생성된 예제 Secret ARN 맵
- `example_secret_ids`: 생성된 예제 Secret ID 맵
- `secret_naming_pattern`: Secret 명명 규칙 패턴

### Lambda 로테이션
- `rotation_lambda_arn`: 로테이션 Lambda 함수 ARN
- `rotation_lambda_name`: 로테이션 Lambda 함수 이름
- `rotation_lambda_role_arn`: Lambda 실행 역할 ARN
- `rotation_lambda_security_group_id`: Lambda 보안 그룹 ID

### IAM 정책
- `crawler_secrets_read_policy_arn`: Crawler 서비스 Secret 읽기 정책
- `devops_secrets_management_policy_arn`: DevOps 팀 Secret 관리 정책
- `github_actions_secrets_policy_arn`: GitHub Actions Secret 정책

## 변수

### 필수 태그 변수
| 이름 | 설명 | 기본값 | 검증 |
|------|------|--------|------|
| `environment` | 환경 이름 | `prod` | dev, staging, prod |
| `team` | 담당 팀 | `platform-team` | kebab-case |
| `owner` | 리소스 소유자 | `platform-team` | email or kebab-case |
| `cost_center` | 비용 센터 | `infrastructure` | kebab-case |
| `service` | 서비스 이름 | `secrets-manager` | kebab-case |
| `data_class` | 데이터 분류 | `highly-confidential` | highly-confidential, confidential, internal, public |

### Secrets 설정
| 이름 | 설명 | 기본값 | 검증 |
|------|------|--------|------|
| `secret_recovery_window_in_days` | Secret 복구 대기 기간 (일) | `30` | 7-30 |
| `rotation_days` | 자동 로테이션 주기 (일) | `90` | 1-365 |
| `enable_rotation` | 자동 로테이션 활성화 | `true` | - |

### 네트워크 설정 (Lambda VPC)
| 이름 | 설명 | 기본값 |
|------|------|--------|
| `vpc_id` | Lambda를 배포할 VPC ID | `""` |
| `private_subnet_ids` | Lambda용 프라이빗 서브넷 ID 리스트 | `[]` |
| `rds_security_group_id` | RDS 보안 그룹 ID | `""` |
| `vpc_cidr` | VPC CIDR 블록 | `""` |

## 아키텍처

### Secret 로테이션 플로우

```
┌─────────────────────┐      ┌──────────────────────┐
│ Secrets Manager     │─────▶│ Rotation Lambda      │
│ - RDS Credentials   │      │ - VPC: Private       │
│ - 90일 자동 로테이션  │      │ - Python 3.11        │
│ - KMS 암호화        │      │ - Timeout: 60s       │
└─────────────────────┘      └──────────────────────┘
                                      │
                                      ▼
                              ┌──────────────────────┐
                              │ RDS MySQL            │
                              │ - ALTER USER         │
                              │ - Connection Test    │
                              └──────────────────────┘
```

### Lambda 로테이션 단계

1. **createSecret**: Secrets Manager에서 새 비밀번호 생성
2. **setSecret**: RDS MySQL에서 `ALTER USER` 실행
3. **testSecret**: 새 비밀번호로 연결 테스트
4. **finishSecret**: 로테이션 완료 및 버전 전환

### 사용 모듈

#### 1. iam-role-policy 모듈 (v1.0.0)
Lambda 실행 역할 생성 및 권한 관리:

```hcl
module "rotation_lambda_role" {
  source = "../../../modules/iam-role-policy"

  # 기본 설정
  role_name   = "secrets-manager-rotation-lambda-role"
  description = "IAM role for Secrets Manager rotation Lambda function"

  # Lambda 신뢰 정책
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  # VPC Lambda용 관리형 정책
  attach_aws_managed_policies = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]

  # Secrets Manager 접근 권한
  enable_secrets_manager_policy = true
  secrets_manager_allow_update  = true
  secrets_manager_secret_arns   = ["arn:aws:secretsmanager:*:*:secret:/ryuqqq/*"]

  # KMS 키 접근 권한
  kms_key_arns = [local.secrets_manager_kms_key_arn]

  # CloudWatch Logs 권한
  enable_cloudwatch_logs_policy = true
  cloudwatch_log_group_arns     = ["arn:aws:logs:*:*:log-group:/aws/lambda/rotation"]

  # RDS 접근 커스텀 정책
  custom_inline_policies = {
    rds-access = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "secretsmanager:GetRandomPassword",
              "rds:DescribeDBInstances",
              "rds:ModifyDBInstance"
            ]
            Resource = "*"
          }
        ]
      })
    }
  }
}
```

#### 2. lambda 모듈 (v1.0.0)
로테이션 Lambda 함수 배포:

```hcl
module "rotation_lambda" {
  source = "../../../modules/lambda"

  # 함수 기본 설정
  name        = "rotation"
  handler     = "index.lambda_handler"
  runtime     = "python3.11"
  timeout     = 60
  memory_size = 128

  # 배포 패키지
  filename         = "${path.module}/lambda/rotation.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/rotation.zip")

  # 환경 변수
  environment_variables = {
    SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.ap-northeast-2.amazonaws.com"
  }

  # VPC 설정 (RDS 접근용)
  vpc_config = {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.rotation-lambda[0].id]
  }

  # IAM 역할 재사용
  create_role     = false
  lambda_role_arn = module.rotation_lambda_role.role_arn

  # CloudWatch Logs
  create_log_group   = true
  log_retention_days = 14
  log_kms_key_id     = local.cloudwatch_logs_kms_key_arn
}
```

## 보안

### Secret 명명 규칙

```
/{organization}/{service}/{environment}/{name}

예제:
/ryuqqq/common/prod/db-master           # 공통 DB 자격증명
/ryuqqq/crawler/prod/api-key            # Crawler 서비스 API 키
/ryuqqq/authhub/prod/jwt-secret         # AuthHub JWT 서명 키
```

### KMS 암호화

모든 Secret은 KMS 고객 관리형 키로 암호화됩니다:
- **키 ARN**: `data.terraform_remote_state.kms.outputs.secrets_manager_key_arn`
- **자동 키 회전**: 활성화
- **데이터 분류**: `highly-confidential`

### IAM 정책 예제

#### 서비스 애플리케이션용 (읽기 전용)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/crawler/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "<kms-key-arn>",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "secretsmanager.ap-northeast-2.amazonaws.com"
        }
      }
    }
  ]
}
```

#### DevOps 팀용 (전체 관리)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:UpdateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:PutSecretValue",
        "secretsmanager:GetSecretValue",
        "secretsmanager:RotateSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "<kms-key-arn>"
    }
  ]
}
```

### 네트워크 보안

Lambda 보안 그룹 규칙:
```hcl
# Outbound to Secrets Manager
egress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Outbound to RDS MySQL
egress {
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = [var.vpc_cidr]
}
```

## 모니터링

### CloudWatch 알람

#### 1. 로테이션 실패 알람 (심각도: HIGH)
```hcl
alarm_name          = "secrets-manager-rotation-failures"
metric_name         = "Errors"
namespace           = "AWS/Lambda"
threshold           = 0
evaluation_periods  = 1
period              = 300 (5분)
```

**알림 조건**: Lambda 실행 실패 발생 시 즉시
**대응 방법**: [Secrets Rotation Runbook](https://github.com/ryu-qqq/Infrastructure/wiki/Secrets-Rotation-Runbook)

#### 2. 로테이션 지연 알람 (심각도: MEDIUM)
```hcl
alarm_name          = "secrets-manager-rotation-duration"
metric_name         = "Duration"
namespace           = "AWS/Lambda"
threshold           = 50000 (50초)
evaluation_periods  = 1
period              = 300 (5분)
```

**알림 조건**: Lambda 실행 시간 > 50초
**원인**: DB 성능 저하 또는 네트워크 지연

### CloudWatch Logs

Lambda 로그 그룹: `/aws/lambda/rotation`
- **보존 기간**: 14일
- **암호화**: CloudWatch Logs KMS 키

로그 확인:
```bash
# 실시간 로그 모니터링
aws logs tail /aws/lambda/rotation --follow

# 최근 1시간 로그
aws logs tail /aws/lambda/rotation --since 1h

# 에러 로그 필터링
aws logs filter-log-events \
  --log-group-name /aws/lambda/rotation \
  --filter-pattern "ERROR"
```

## 운영 가이드

### 초기 배포

1. **KMS 스택 배포 확인**
   ```bash
   cd terraform/environments/prod/kms
   terraform output secrets_manager_key_arn
   ```

2. **Lambda 배포 패키지 빌드**
   ```bash
   cd terraform/environments/prod/secrets/lambda
   ./build.sh
   ```

3. **Secrets Manager 스택 배포**
   ```bash
   cd terraform/environments/prod/secrets
   terraform init
   terraform plan
   terraform apply
   ```

4. **VPC 설정 (RDS 로테이션용)**
   ```bash
   # terraform.tfvars 또는 변수 파일에서 설정
   vpc_id              = "vpc-xxxxx"
   private_subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
   vpc_cidr            = "10.0.0.0/16"
   ```

### Secret 생성

#### AWS CLI로 생성
```bash
# RDS 자격증명 생성
aws secretsmanager create-secret \
  --name /ryuqqq/common/prod/db-master \
  --description "RDS master database credentials" \
  --kms-key-id <kms-key-id> \
  --secret-string '{
    "username": "admin",
    "password": "초기비밀번호",
    "engine": "mysql",
    "host": "db.example.com",
    "port": 3306,
    "dbname": "production"
  }' \
  --region ap-northeast-2

# API 키 생성
aws secretsmanager create-secret \
  --name /ryuqqq/crawler/prod/api-key \
  --description "Crawler service API key" \
  --kms-key-id <kms-key-id> \
  --secret-string '{"api_key": "your-api-key-here"}' \
  --region ap-northeast-2
```

#### Terraform으로 생성 (권장)
```hcl
resource "aws_secretsmanager_secret" "service_secret" {
  name        = "/ryuqqq/myservice/prod/credentials"
  description = "My service credentials"
  kms_key_id  = local.secrets_manager_kms_key_id

  tags = merge(local.required_tags, {
    Name       = "/ryuqqq/myservice/prod/credentials"
    SecretType = "credentials"
    Component  = "secret"
  })
}
```

### 로테이션 설정

#### 자동 로테이션 활성화
```hcl
resource "aws_secretsmanager_secret_rotation" "example" {
  secret_id           = aws_secretsmanager_secret.example.id
  rotation_lambda_arn = module.rotation_lambda.function_arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

#### 수동 로테이션 실행
```bash
# 즉시 로테이션 트리거
aws secretsmanager rotate-secret \
  --secret-id /ryuqqq/common/prod/db-master \
  --region ap-northeast-2

# 로테이션 상태 확인
aws secretsmanager describe-secret \
  --secret-id /ryuqqq/common/prod/db-master \
  --region ap-northeast-2 \
  --query 'RotationEnabled'
```

### Secret 값 조회

```bash
# Secret 값 가져오기
aws secretsmanager get-secret-value \
  --secret-id /ryuqqq/common/prod/db-master \
  --region ap-northeast-2 \
  --query 'SecretString' \
  --output text | jq .

# 특정 필드만 추출
aws secretsmanager get-secret-value \
  --secret-id /ryuqqq/common/prod/db-master \
  --region ap-northeast-2 \
  --query 'SecretString' \
  --output text | jq -r '.password'
```

### Secret 삭제 및 복구

```bash
# Secret 삭제 예약 (30일 복구 기간)
aws secretsmanager delete-secret \
  --secret-id /ryuqqq/common/prod/old-secret \
  --recovery-window-in-days 30 \
  --region ap-northeast-2

# 삭제 취소
aws secretsmanager restore-secret \
  --secret-id /ryuqqq/common/prod/old-secret \
  --region ap-northeast-2

# 즉시 삭제 (복구 불가 - 주의!)
aws secretsmanager delete-secret \
  --secret-id /ryuqqq/common/prod/old-secret \
  --force-delete-without-recovery \
  --region ap-northeast-2
```

## 🔧 트러블슈팅

### 1. 로테이션 실패 (Rotation Failed)

**증상**: `aws secretsmanager describe-secret` 결과에서 `RotationEnabled: true`이지만 실패 상태

**확인 방법**:
```bash
# Secret 상태 확인
aws secretsmanager describe-secret \
  --secret-id /ryuqqq/common/prod/db-master \
  --region ap-northeast-2

# Lambda 로그 확인
aws logs tail /aws/lambda/rotation --since 1h
```

**일반적인 원인**:

1. **Lambda가 RDS에 접근 불가**
   - 보안 그룹: Lambda SG → RDS SG (3306 포트) 허용 확인
   - 서브넷: Lambda가 Private Subnet에 배포되었는지 확인
   - VPC 엔드포인트: Secrets Manager VPC Endpoint 설정 확인

2. **IAM 권한 부족**
   ```bash
   # Lambda 실행 역할 정책 확인
   aws iam get-role \
     --role-name secrets-manager-rotation-lambda-role

   # 필요한 권한:
   # - secretsmanager:GetSecretValue, PutSecretValue
   # - kms:Decrypt, GenerateDataKey
   # - rds:DescribeDBInstances
   ```

3. **KMS 키 접근 거부**
   ```bash
   # KMS 키 정책 확인
   aws kms get-key-policy \
     --key-id <secrets-manager-kms-key-id> \
     --policy-name default \
     --region ap-northeast-2
   ```

4. **MySQL 권한 부족**
   - Secret의 사용자가 `ALTER USER` 권한 보유 확인
   - Master user만 다른 사용자 비밀번호 변경 가능

### 2. Lambda Timeout

**증상**: CloudWatch 알람 `rotation-duration` 발생

**확인 방법**:
```bash
# Lambda 실행 시간 메트릭
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=rotation \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum \
  --region ap-northeast-2
```

**해결 방법**:

1. **RDS 성능 확인**
   ```bash
   # RDS CPU 사용률
   aws cloudwatch get-metric-statistics \
     --namespace AWS/RDS \
     --metric-name CPUUtilization \
     --dimensions Name=DBInstanceIdentifier,Value=<db-instance-id> \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average
   ```

2. **Lambda 타임아웃 증가** (현재 60초)
   ```hcl
   # rotation.tf
   module "rotation_lambda" {
     timeout = 120  # 60 → 120초로 증가
   }
   ```

3. **네트워크 지연 확인**
   - VPC Flow Logs 분석
   - Lambda ENI 상태 확인

### 3. Secret 값 조회 실패 (Access Denied)

**증상**: `aws secretsmanager get-secret-value` 실행 시 권한 거부

**확인 방법**:
```bash
# 현재 IAM 엔티티 확인
aws sts get-caller-identity

# Secret 리소스 정책 확인
aws secretsmanager get-resource-policy \
  --secret-id /ryuqqq/common/prod/db-master \
  --region ap-northeast-2
```

**해결 방법**:

1. **IAM 정책 확인**
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "secretsmanager:GetSecretValue",
       "secretsmanager:DescribeSecret"
     ],
     "Resource": "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/*"
   }
   ```

2. **KMS 복호화 권한 확인**
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "kms:Decrypt",
       "kms:DescribeKey"
     ],
     "Resource": "<kms-key-arn>",
     "Condition": {
       "StringEquals": {
         "kms:ViaService": "secretsmanager.ap-northeast-2.amazonaws.com"
       }
     }
   }
   ```

3. **서비스별 IAM 정책 연결**
   ```bash
   # Crawler 서비스 역할에 정책 연결
   aws iam attach-role-policy \
     --role-name crawler-service-role \
     --policy-arn <crawler-secrets-read-policy-arn>
   ```

### 4. Lambda VPC 연결 문제

**증상**: Lambda가 Secrets Manager 또는 RDS에 연결 불가

**확인 방법**:
```bash
# Lambda VPC 설정 확인
aws lambda get-function-configuration \
  --function-name rotation \
  --region ap-northeast-2 \
  --query 'VpcConfig'

# ENI 상태 확인
aws ec2 describe-network-interfaces \
  --filters "Name=description,Values=AWS Lambda VPC ENI*" \
  --region ap-northeast-2
```

**해결 방법**:

1. **VPC 엔드포인트 생성** (NAT Gateway 대안)
   ```hcl
   # Secrets Manager VPC Endpoint
   resource "aws_vpc_endpoint" "secretsmanager" {
     vpc_id            = var.vpc_id
     service_name      = "com.amazonaws.ap-northeast-2.secretsmanager"
     vpc_endpoint_type = "Interface"
     subnet_ids        = var.private_subnet_ids
     security_group_ids = [aws_security_group.vpc_endpoints.id]
   }
   ```

2. **라우팅 테이블 확인**
   - Private Subnet → NAT Gateway 또는 VPC Endpoint 경로 확인

3. **보안 그룹 규칙 검증**
   ```bash
   # Lambda 보안 그룹의 Egress 규칙
   aws ec2 describe-security-groups \
     --group-ids <lambda-sg-id> \
     --region ap-northeast-2 \
     --query 'SecurityGroups[0].IpPermissionsEgress'
   ```

### 5. Secret 값이 업데이트되지 않음

**증상**: `aws secretsmanager put-secret-value` 후에도 이전 값 조회됨

**확인 방법**:
```bash
# Secret 버전 히스토리 확인
aws secretsmanager list-secret-version-ids \
  --secret-id /ryuqqq/common/prod/db-master \
  --region ap-northeast-2

# 특정 버전 조회
aws secretsmanager get-secret-value \
  --secret-id /ryuqqq/common/prod/db-master \
  --version-id <version-id> \
  --region ap-northeast-2
```

**해결 방법**:

1. **버전 스테이징 라벨 확인**
   ```bash
   # AWSCURRENT 라벨이 최신 버전을 가리키는지 확인
   aws secretsmanager describe-secret \
     --secret-id /ryuqqq/common/prod/db-master \
     --region ap-northeast-2 \
     --query 'VersionIdsToStages'
   ```

2. **캐싱 지연**
   - 애플리케이션에서 Secret 값을 캐싱하는 경우 TTL 확인
   - AWS SDK는 기본적으로 캐싱하지 않음

3. **Terraform lifecycle 충돌**
   ```hcl
   # lifecycle ignore_changes 제거 또는 조정
   resource "aws_secretsmanager_secret_version" "example" {
     secret_id = aws_secretsmanager_secret.example.id
     secret_string = jsonencode(local.credentials)

     lifecycle {
       ignore_changes = [secret_string]  # 이 설정 확인
     }
   }
   ```

### 6. 비용 급증 (Unexpected Costs)

**증상**: Secrets Manager 비용이 예상보다 높음

**확인 방법**:
```bash
# 생성된 Secret 개수 확인
aws secretsmanager list-secrets \
  --region ap-northeast-2 \
  --query 'length(SecretList)'

# API 호출 메트릭 (CloudTrail)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetSecretValue \
  --region ap-northeast-2 \
  --max-results 50
```

**비용 구조**:
- Secret 저장: $0.40/월 per secret
- API 호출: $0.05 per 10,000 호출
- 로테이션: 추가 비용 없음 (Lambda 비용 별도)

**해결 방법**:

1. **사용하지 않는 Secret 삭제**
   ```bash
   # 최근 30일간 액세스되지 않은 Secret 찾기
   aws secretsmanager list-secrets \
     --region ap-northeast-2 \
     --query 'SecretList[?LastAccessedDate<`'$(date -u -d '30 days ago' +%Y-%m-%d)'`].Name'
   ```

2. **API 호출 최적화**
   - 애플리케이션에서 Secret 캐싱 구현
   - AWS Secrets Manager Caching Library 사용

3. **Secret 통합**
   - 여러 관련 값을 하나의 Secret JSON에 저장
   ```json
   {
     "db_master_password": "xxx",
     "db_readonly_password": "yyy",
     "redis_password": "zzz"
   }
   ```

### 7. 체크리스트

Secrets Manager 운영 시 확인 사항:
- [ ] 모든 Secret이 KMS 고객 관리형 키로 암호화됨
- [ ] Secret 명명 규칙 준수 (`/{org}/{service}/{env}/{name}`)
- [ ] 로테이션이 필요한 Secret에 자동 로테이션 설정됨
- [ ] Lambda 함수가 VPC Private Subnet에 배포됨
- [ ] Lambda 보안 그룹이 RDS 접근 허용
- [ ] IAM 정책이 최소 권한 원칙 준수
- [ ] CloudWatch 알람이 활성화되고 SNS 연결됨
- [ ] Secret 복구 대기 기간 30일 설정됨
- [ ] 하드코딩된 비밀번호가 코드에 없음
- [ ] CloudTrail로 Secret 접근 감사 로깅 활성화
- [ ] Secret 값이 Git에 커밋되지 않음 (`.gitignore` 확인)
- [ ] 로테이션 Lambda 배포 패키지 최신 상태 유지

## 비용

### 월간 예상 비용 (prod 환경)

| 항목 | 수량 | 단가 | 월 비용 |
|------|------|------|---------|
| Secret 저장 | 10개 | $0.40/secret | $4.00 |
| API 호출 | 100,000회 | $0.05/10K | $0.50 |
| Lambda 실행 | 90회/월 | 무료 티어 | $0.00 |
| Lambda VPC ENI | 1개 | $0.01/시간 | $7.30 |
| CloudWatch Logs | 1GB | $0.50/GB | $0.50 |
| **합계** | - | - | **$12.30** |

> **참고**: API 호출 횟수는 애플리케이션 캐싱 전략에 따라 크게 달라질 수 있습니다.

## 참고 자료

### 공식 문서
- [AWS Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/latest/userguide/)
- [Secrets Manager Rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [Lambda Rotation Functions](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets-lambda-function-overview.html)

### Terraform 문서
- [aws_secretsmanager_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)
- [aws_secretsmanager_secret_rotation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_rotation)

### 내부 문서
- [Lambda 로테이션 함수 가이드](./lambda/README.md)
- [Secrets Rotation Runbook](https://github.com/ryu-qqq/Infrastructure/wiki/Secrets-Rotation-Runbook)

## 관련 이슈

<!-- Jira 티켓 또는 GitHub Issues 링크 -->
