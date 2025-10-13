# Secrets Manager Module

AWS Secrets Manager를 사용한 시크릿 관리 인프라 모듈입니다.

## 개요

이 모듈은 다음을 제공합니다:
- AWS Secrets Manager를 통한 중앙 집중식 시크릿 관리
- KMS 암호화를 통한 저장 데이터 보호
- 90일 주기 자동 로테이션
- 서비스별 최소 권한 IAM 정책
- 표준화된 네이밍 규칙 및 태깅

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Services                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Crawler  │  │ AuthHub  │  │ Common   │  │ Others   │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │             │          │
│       └─────────────┴──────────────┴─────────────┘          │
│                          │                                   │
└──────────────────────────┼───────────────────────────────────┘
                           │ IAM Policy (Read Only)
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  AWS Secrets Manager                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  /ryuqqq/{service}/{env}/{name}                        │ │
│  │  - /ryuqqq/crawler/prod/db-master                      │ │
│  │  - /ryuqqq/crawler/prod/api-openai                     │ │
│  │  - /ryuqqq/common/prod/api-sendgrid                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          │ KMS Encryption                    │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  KMS Key: alias/secrets-manager                        │ │
│  │  (highly-confidential)                                 │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Rotation (90 days)
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                  Lambda Rotation Function                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  createSecret  → setSecret → testSecret → finishSecret │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 네이밍 규칙

모든 시크릿은 다음 패턴을 따릅니다:

```
/ryuqqq/{service}/{environment}/{name}
```

**예시**:
- `/ryuqqq/crawler/prod/db-master` - Crawler 서비스의 RDS 마스터 자격증명
- `/ryuqqq/authhub/prod/jwt-secret` - AuthHub 서비스의 JWT 시크릿
- `/ryuqqq/common/prod/api-sendgrid` - 공통 서비스의 SendGrid API 키

## 사용 방법

### 1. 서비스 레포에서 시크릿 생성

서비스별 Terraform 코드에서 시크릿을 생성합니다:

```hcl
# Remote state로 KMS 키 및 정책 참조
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = "prod-connectly"
    key    = "kms/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "secrets" {
  backend = "s3"
  config = {
    bucket = "prod-connectly"
    key    = "secrets/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 시크릿 생성
resource "aws_secretsmanager_secret" "db_password" {
  name        = "/ryuqqq/crawler/prod/db-master"
  description = "RDS master database credentials for Crawler service"
  kms_key_id  = data.terraform_remote_state.kms.outputs.secrets_manager_key_id

  recovery_window_in_days = 30

  tags = {
    Owner       = "platform-team"
    CostCenter  = "infrastructure"
    Environment = "prod"
    Service     = "crawler"
    ManagedBy   = "terraform"
    Project     = "crawler"
    DataClass   = "highly-confidential"
    SecretType  = "rds"
  }
}

# 초기값 설정
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_master.result
    engine   = "postgres"
    host     = aws_db_instance.main.endpoint
    port     = 5432
    dbname   = "crawler"
    dbInstanceIdentifier = aws_db_instance.main.id
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# 로테이션 설정 (옵션)
resource "aws_secretsmanager_secret_rotation" "db_password" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = data.terraform_remote_state.secrets.outputs.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

### 2. ECS Task Definition에서 시크릿 참조

```hcl
resource "aws_ecs_task_definition" "crawler" {
  family = "crawler"

  container_definitions = jsonencode([{
    name  = "crawler"
    image = "crawler:latest"

    # 시크릿을 환경 변수로 주입
    secrets = [
      {
        name      = "DB_USERNAME"
        valueFrom = "${aws_secretsmanager_secret.db_password.arn}:username::"
      },
      {
        name      = "DB_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.db_password.arn}:password::"
      },
      {
        name      = "DB_HOST"
        valueFrom = "${aws_secretsmanager_secret.db_password.arn}:host::"
      }
    ]
  }])

  task_role_arn      = aws_iam_role.crawler_task.arn
  execution_role_arn = aws_iam_role.crawler_execution.arn
}

# Task Role에 시크릿 읽기 권한 부여
resource "aws_iam_role_policy_attachment" "crawler_secrets" {
  role       = aws_iam_role.crawler_task.name
  policy_arn = data.terraform_remote_state.secrets.outputs.crawler_secrets_read_policy_arn
}
```

### 3. 애플리케이션 코드에서 접근

#### Python 예시

```python
import boto3
import json
from functools import lru_cache
from datetime import datetime, timedelta

class SecretCache:
    def __init__(self, ttl_seconds=3600):
        self.client = boto3.client('secretsmanager', region_name='ap-northeast-2')
        self.ttl = ttl_seconds
        self.cache = {}

    def get_secret(self, secret_name):
        now = datetime.now()

        if secret_name in self.cache:
            cached_time, cached_value = self.cache[secret_name]
            if now - cached_time < timedelta(seconds=self.ttl):
                return cached_value

        # 캐시 미스: Secrets Manager에서 가져오기
        response = self.client.get_secret_value(SecretId=secret_name)
        value = json.loads(response['SecretString'])
        self.cache[secret_name] = (now, value)
        return value

# 전역 캐시 인스턴스
secret_cache = SecretCache(ttl_seconds=3600)

# 사용
db_creds = secret_cache.get_secret("/ryuqqq/crawler/prod/db-master")
connection = psycopg2.connect(
    host=db_creds['host'],
    port=db_creds['port'],
    user=db_creds['username'],
    password=db_creds['password'],
    database=db_creds['dbname']
)
```

#### Node.js 예시

```javascript
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

class SecretCache {
  constructor(ttl = 3600000) { // 1 hour default
    this.client = new SecretsManagerClient({ region: "ap-northeast-2" });
    this.ttl = ttl;
    this.cache = new Map();
  }

  async getSecret(secretName) {
    const now = Date.now();
    const cached = this.cache.get(secretName);

    if (cached && now - cached.timestamp < this.ttl) {
      return cached.value;
    }

    const response = await this.client.send(
      new GetSecretValueCommand({ SecretId: secretName })
    );
    const value = JSON.parse(response.SecretString);

    this.cache.set(secretName, { value, timestamp: now });
    return value;
  }
}

// 전역 캐시 인스턴스
const secretCache = new SecretCache();

// 사용
const dbCreds = await secretCache.getSecret("/ryuqqq/crawler/prod/db-master");
const pool = new Pool({
  host: dbCreds.host,
  port: dbCreds.port,
  user: dbCreds.username,
  password: dbCreds.password,
  database: dbCreds.dbname
});
```

## 로테이션

### 자동 로테이션

모든 시크릿은 90일마다 자동으로 로테이션됩니다:

```hcl
resource "aws_secretsmanager_secret_rotation" "example" {
  secret_id           = aws_secretsmanager_secret.example.id
  rotation_lambda_arn = data.terraform_remote_state.secrets.outputs.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

### 수동 로테이션

긴급 상황 시 수동으로 로테이션할 수 있습니다:

```bash
# 즉시 로테이션 실행
aws secretsmanager rotate-secret \
  --secret-id /ryuqqq/crawler/prod/db-master \
  --region ap-northeast-2

# 로테이션 상태 확인
aws secretsmanager describe-secret \
  --secret-id /ryuqqq/crawler/prod/db-master \
  --region ap-northeast-2
```

### 지원되는 시크릿 타입

Lambda 로테이션 함수는 다음 타입을 지원합니다:

1. **RDS 자격증명** (`SecretType: rds`)
   - 자동으로 RDS 마스터 패스워드 업데이트
   - 연결 테스트 수행

2. **API 키** (`SecretType: api_key`)
   - 새 랜덤 키 생성
   - 기본 검증 수행

3. **일반 시크릿** (`SecretType: generic`)
   - 새 랜덤 값 생성
   - 구조 검증 수행

## IAM 권한

### 애플리케이션 읽기 권한

서비스는 자신의 시크릿만 읽을 수 있습니다:

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
      "Resource": [
        "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/crawler/prod/*",
        "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/common/prod/*"
      ]
    }
  ]
}
```

### DevOps 관리 권한

운영팀은 모든 시크릿을 관리할 수 있습니다:

```bash
# DevOps 정책 적용
aws iam attach-user-policy \
  --user-name devops-user \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/devops-secrets-management-policy
```

## 모니터링

### CloudWatch 로그

Lambda 로테이션 함수의 로그는 CloudWatch에 기록됩니다:

```bash
# 로그 확인
aws logs tail /aws/lambda/secrets-manager-rotation --follow
```

### 알람

로테이션 실패 시 CloudWatch 알람이 트리거됩니다:

```hcl
resource "aws_cloudwatch_metric_alarm" "rotation_failures" {
  alarm_name          = "secrets-manager-rotation-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when secret rotation fails"
}
```

## 거버넌스

### 필수 태그

모든 시크릿은 다음 태그를 포함해야 합니다:

| 태그 | 설명 | 예시 |
|-----|------|------|
| Owner | 소유자 | platform-team |
| CostCenter | 비용 센터 | infrastructure |
| Environment | 환경 | prod, staging, dev |
| Service | 서비스명 | crawler, authhub |
| ManagedBy | 관리 방식 | terraform |
| Project | 프로젝트명 | infrastructure |
| DataClass | 데이터 분류 | highly-confidential |
| SecretType | 시크릿 유형 | rds, api_key, generic |

### 네이밍 검증

OPA를 사용한 네이밍 규칙 검증:

```rego
package secretsmanager

deny[msg] {
  input.type == "aws_secretsmanager_secret"
  not regex.match(`^/ryuqqq/[a-z-]+/(dev|staging|prod)/[a-z0-9-]+$`, input.name)
  msg = sprintf("Secret name '%s' does not follow naming convention", [input.name])
}
```

## 배포

### 초기 배포

```bash
cd terraform/secrets

# 초기화
terraform init

# 계획 확인
terraform plan

# 적용
terraform apply
```

### 주의사항

1. **KMS 의존성**: KMS 모듈이 먼저 배포되어 있어야 합니다
2. **Lambda 빌드**: 배포 전 Lambda 함수를 빌드해야 합니다
   ```bash
   cd lambda
   ./build.sh
   ```
3. **시크릿 삭제**: 30일 복구 기간 후 영구 삭제됩니다

## 비용

**예상 월 비용**:
- Secrets Manager: $0.40/시크릿/월
- Lambda 실행: 무료 티어 내 (월 1회 로테이션 가정)
- KMS: $1/키/월 (공유 키 사용)

**예시**: 10개 시크릿 = $4/월

## 트러블슈팅

### Access Denied 에러

```bash
# IAM 정책 확인
aws iam get-role-policy \
  --role-name crawler-ecs-task-role \
  --policy-name secrets-read

# KMS 키 정책 확인
aws kms get-key-policy \
  --key-id alias/secrets-manager \
  --policy-name default
```

### 로테이션 실패

```bash
# Lambda 로그 확인
aws logs tail /aws/lambda/secrets-manager-rotation --follow

# 로테이션 상태 확인
aws secretsmanager describe-secret \
  --secret-id /ryuqqq/crawler/prod/db-master
```

## 참고 자료

- [Secrets Management Strategy Guide](../../claudedocs/secrets-management-strategy.md)
- [Infrastructure Governance](../../docs/infrastructure_governance.md)
- [KMS Strategy Guide](../kms/README.md)
- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)
