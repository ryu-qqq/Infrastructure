# Secrets Manager 전략 가이드

## 개요

이 문서는 공통 플랫폼 인프라를 위한 AWS Secrets Manager 전략 및 사용 가이드를 제공합니다.

## 아키텍처

### 설계 원칙

1. **Centralized Secret Management**: 모든 애플리케이션 시크릿을 중앙 집중 관리
2. **Automatic Rotation**: 정기적인 자동 로테이션으로 보안 강화
3. **Least Privilege Access**: 서비스별 최소 권한 원칙 적용
4. **Encryption at Rest**: KMS 키를 사용한 저장 데이터 암호화
5. **Audit Trail**: CloudTrail을 통한 모든 접근 기록

### 시크릿 분류

| 유형 | 설명 | 로테이션 주기 | 예시 |
|-----|------|------------|------|
| Database Credentials | RDS, Aurora 등 데이터베이스 자격증명 | 90일 | /ryuqqq/crawler/prod/db-master |
| API Keys | 외부 서비스 API 키 | 90일 | /ryuqqq/crawler/prod/api-openai |
| Service Credentials | 서비스 간 인증 토큰 | 90일 | /ryuqqq/crawler/prod/service-auth |
| Application Secrets | JWT 시크릿 등 애플리케이션 설정 | 180일 | /ryuqqq/authhub/prod/jwt-secret |

## 네이밍 규칙

### 표준 패턴

```
/org/{service}/{env}/{name}
```

**구성 요소**:
- `org`: 조직명 (고정값: `ryuqqq`)
- `service`: 서비스명 (예: `crawler`, `authhub`, `common`)
- `env`: 환경 (예: `dev`, `staging`, `prod`)
- `name`: 시크릿 이름 (kebab-case)

### 네이밍 예시

```
# 데이터베이스 자격증명
/ryuqqq/crawler/prod/db-master
/ryuqqq/crawler/prod/db-readonly
/ryuqqq/authhub/prod/db-master

# API 키
/ryuqqq/crawler/prod/api-openai
/ryuqqq/crawler/prod/api-serpapi
/ryuqqq/common/prod/api-sendgrid

# 애플리케이션 시크릿
/ryuqqq/authhub/prod/jwt-secret
/ryuqqq/authhub/prod/session-secret
/ryuqqq/crawler/prod/encryption-key

# 서비스 간 인증
/ryuqqq/common/prod/service-to-service-token
/ryuqqq/crawler/prod/internal-api-key
```

## KMS 통합

### 암호화 키

모든 Secrets Manager 시크릿은 전용 KMS 키로 암호화됩니다.

**KMS 키**: `alias/secrets-manager`

**DataClass**: highly-confidential

**사용 방법**:
```hcl
resource "aws_secretsmanager_secret" "example" {
  name       = "/ryuqqq/crawler/prod/db-password"
  kms_key_id = data.terraform_remote_state.kms.outputs.secrets_manager_key_id
}
```

### KMS 키 권한

- Secrets Manager 서비스: Decrypt, DescribeKey, GenerateDataKey, CreateGrant
- 애플리케이션 역할: Decrypt, DescribeKey (via Secrets Manager)
- GitHub Actions Role: Encrypt, Decrypt, DescribeKey, GenerateDataKey

## 로테이션 전략

### 자동 로테이션

**기본 정책**:
- 로테이션 주기: 90일
- 만료 알림: 30일 전
- 즉시 로테이션: 보안 사고 발생 시

### 지원되는 로테이션 타입

#### 1. RDS/Aurora 자동 로테이션

AWS에서 제공하는 Lambda 함수 사용:

```hcl
resource "aws_secretsmanager_secret_rotation" "rds" {
  secret_id           = aws_secretsmanager_secret.db_master.id
  rotation_lambda_arn = aws_lambda_function.rds_rotation.arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

**특징**:
- RDS 마스터 자격증명 자동 업데이트
- 다운타임 없는 로테이션
- 이전 버전 자동 무효화

#### 2. 커스텀 로테이션 (API 키, 토큰 등)

커스텀 Lambda 함수 작성 필요:

```hcl
resource "aws_secretsmanager_secret_rotation" "api_key" {
  secret_id           = aws_secretsmanager_secret.api_key.id
  rotation_lambda_arn = aws_lambda_function.custom_rotation.arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

**Lambda 함수 요구사항**:
1. `createSecret`: 새 시크릿 생성
2. `setSecret`: 새 시크릿 설정
3. `testSecret`: 새 시크릿 검증
4. `finishSecret`: 로테이션 완료

### 수동 로테이션

긴급 상황 시 수동 로테이션:

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

## 접근 제어

### IAM 정책 패턴

#### 애플리케이션 읽기 권한

서비스별로 필요한 시크릿에만 접근:

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
        "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/crawler/prod/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:ap-northeast-2:*:key/*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": "secretsmanager.ap-northeast-2.amazonaws.com"
        }
      }
    }
  ]
}
```

#### 운영자 관리 권한

DevOps 팀은 시크릿 생성/수정/삭제 가능:

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
        "secretsmanager:DescribeSecret",
        "secretsmanager:RotateSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/*"
    }
  ]
}
```

### 서비스별 권한 분리

```hcl
# Crawler 서비스 역할
resource "aws_iam_role_policy" "crawler_secrets" {
  name = "crawler-secrets-access"
  role = aws_iam_role.crawler_ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/crawler/prod/*",
          "arn:aws:secretsmanager:ap-northeast-2:*:secret:/ryuqqq/common/prod/*"
        ]
      }
    ]
  })
}
```

## 서비스 레포 사용 가이드

### Terraform에서 시크릿 생성

```hcl
# Remote state로 KMS 키 참조
data "terraform_remote_state" "kms" {
  backend = "s3"
  config = {
    bucket = "prod-connectly"
    key    = "kms/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 시크릿 생성
resource "aws_secretsmanager_secret" "db_password" {
  name        = "/ryuqqq/crawler/prod/db-master"
  description = "RDS master database credentials"
  kms_key_id  = data.terraform_remote_state.kms.outputs.secrets_manager_key_id

  tags = {
    Owner       = "platform-team"
    CostCenter  = "infrastructure"
    Environment = "prod"
    Service     = "crawler"
    ManagedBy   = "terraform"
  }
}

# 초기값 설정 (옵션)
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_master.result
    engine   = "postgres"
    host     = aws_db_instance.main.endpoint
    port     = 5432
    dbname   = "crawler"
  })
}

# 로테이션 설정
resource "aws_secretsmanager_secret_rotation" "db_password" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.rds_rotation.arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

### ECS Task Definition에서 시크릿 참조

```hcl
resource "aws_ecs_task_definition" "crawler" {
  family = "crawler"

  container_definitions = jsonencode([{
    name  = "crawler"
    image = "crawler:latest"

    # 환경 변수로 시크릿 주입
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
      },
      {
        name      = "OPENAI_API_KEY"
        valueFrom = aws_secretsmanager_secret.openai_key.arn
      }
    ]
  }])

  # Task 역할에 시크릿 접근 권한 필요
  task_role_arn = aws_iam_role.crawler_task.arn
}
```

### 애플리케이션 코드에서 접근

#### Python (boto3)

```python
import boto3
import json
from botocore.exceptions import ClientError

def get_secret(secret_name: str, region_name: str = "ap-northeast-2") -> dict:
    """Secrets Manager에서 시크릿을 가져옵니다."""
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        response = client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except ClientError as e:
        raise Exception(f"Failed to retrieve secret: {e}")

# 사용 예시
db_credentials = get_secret("/ryuqqq/crawler/prod/db-master")
connection = psycopg2.connect(
    host=db_credentials['host'],
    port=db_credentials['port'],
    user=db_credentials['username'],
    password=db_credentials['password'],
    database=db_credentials['dbname']
)
```

#### Node.js (AWS SDK v3)

```javascript
import {
  SecretsManagerClient,
  GetSecretValueCommand
} from "@aws-sdk/client-secrets-manager";

async function getSecret(secretName, region = "ap-northeast-2") {
  const client = new SecretsManagerClient({ region });

  try {
    const response = await client.send(
      new GetSecretValueCommand({ SecretId: secretName })
    );
    return JSON.parse(response.SecretString);
  } catch (error) {
    throw new Error(`Failed to retrieve secret: ${error.message}`);
  }
}

// 사용 예시
const dbCredentials = await getSecret("/ryuqqq/crawler/prod/db-master");
const pool = new Pool({
  host: dbCredentials.host,
  port: dbCredentials.port,
  user: dbCredentials.username,
  password: dbCredentials.password,
  database: dbCredentials.dbname
});
```

#### Go

```go
import (
    "context"
    "encoding/json"
    "fmt"

    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/secretsmanager"
)

type DBCredentials struct {
    Username string `json:"username"`
    Password string `json:"password"`
    Host     string `json:"host"`
    Port     int    `json:"port"`
    DBName   string `json:"dbname"`
}

func GetSecret(ctx context.Context, secretName string) (*DBCredentials, error) {
    cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("ap-northeast-2"))
    if err != nil {
        return nil, fmt.Errorf("unable to load SDK config: %w", err)
    }

    client := secretsmanager.NewFromConfig(cfg)

    result, err := client.GetSecretValue(ctx, &secretsmanager.GetSecretValueInput{
        SecretId: &secretName,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to retrieve secret: %w", err)
    }

    var creds DBCredentials
    if err := json.Unmarshal([]byte(*result.SecretString), &creds); err != nil {
        return nil, fmt.Errorf("failed to unmarshal secret: %w", err)
    }

    return &creds, nil
}

// 사용 예시
creds, err := GetSecret(context.Background(), "/ryuqqq/crawler/prod/db-master")
if err != nil {
    log.Fatal(err)
}

dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s",
    creds.Host, creds.Port, creds.Username, creds.Password, creds.DBName)
```

### 시크릿 캐싱 권장사항

성능 및 비용 최적화를 위해 시크릿 캐싱 사용:

```python
from functools import lru_cache
from datetime import datetime, timedelta

class SecretCache:
    def __init__(self, ttl_seconds: int = 3600):
        self.ttl = ttl_seconds
        self.cache = {}

    def get_secret(self, secret_name: str) -> dict:
        now = datetime.now()

        if secret_name in self.cache:
            cached_time, cached_value = self.cache[secret_name]
            if now - cached_time < timedelta(seconds=self.ttl):
                return cached_value

        # 캐시 미스: Secrets Manager에서 가져오기
        value = get_secret(secret_name)
        self.cache[secret_name] = (now, value)
        return value

# 전역 캐시 인스턴스
secret_cache = SecretCache(ttl_seconds=3600)

# 사용
db_credentials = secret_cache.get_secret("/ryuqqq/crawler/prod/db-master")
```

## 모니터링 및 감사

### CloudTrail 로깅

모든 Secrets Manager 작업은 CloudTrail에 자동으로 기록됩니다:

**추적 이벤트**:
- `GetSecretValue`: 시크릿 읽기 (누가, 언제, 어떤 시크릿)
- `PutSecretValue`: 시크릿 업데이트
- `CreateSecret`: 시크릿 생성
- `DeleteSecret`: 시크릿 삭제
- `RotateSecret`: 로테이션 실행

### 만료 알림

CloudWatch Events + SNS로 만료 알림 설정:

```hcl
resource "aws_cloudwatch_event_rule" "secret_rotation_needed" {
  name        = "secrets-rotation-needed"
  description = "Notify when secrets need rotation"

  event_pattern = jsonencode({
    source      = ["aws.secretsmanager"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventName = ["RotateSecret"]
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.secret_rotation_needed.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}
```

### 비용 모니터링

**Secrets Manager 비용**:
- 시크릿 저장: $0.40/월/시크릿
- API 요청: $0.05/10,000 API 호출

**비용 최적화**:
1. 사용하지 않는 시크릿 정기 삭제
2. 시크릿 캐싱으로 API 호출 감소
3. 로테이션 주기 적절히 조정

## 거버넌스 준수

### 필수 태그

모든 시크릿은 다음 태그를 포함해야 합니다:

```hcl
locals {
  required_tags = {
    Owner       = "platform-team"
    CostCenter  = "infrastructure"
    Environment = var.environment  # dev, staging, prod
    Service     = var.service_name
    ManagedBy   = "terraform"
    Project     = "infrastructure"
    DataClass   = "highly-confidential"
  }
}
```

### 네이밍 규칙 검증

OPA (Open Policy Agent)를 사용한 네이밍 규칙 검증:

```rego
package secretsmanager

deny[msg] {
  input.type == "aws_secretsmanager_secret"
  not regex.match(`^/ryuqqq/[a-z-]+/(dev|staging|prod)/[a-z0-9-]+$`, input.name)
  msg = sprintf("Secret name '%s' does not follow naming convention", [input.name])
}
```

### 보안 체크리스트

- [ ] KMS 키 암호화 활성화
- [ ] 90일 자동 로테이션 설정
- [ ] 최소 권한 IAM 정책 적용
- [ ] CloudTrail 로깅 활성화
- [ ] 필수 태그 모두 설정
- [ ] 네이밍 규칙 준수
- [ ] 만료 알림 설정
- [ ] DR 계획 수립

## 재해 복구

### 백업 전략

Secrets Manager는 자동으로 다중 AZ에 복제되지만, 추가 백업 권장:

```hcl
# Secrets를 SSM Parameter Store에 백업
resource "aws_ssm_parameter" "secret_backup" {
  for_each = aws_secretsmanager_secret.secrets

  name  = "/backup${each.value.name}"
  type  = "SecureString"
  value = data.aws_secretsmanager_secret_version.current[each.key].secret_string

  lifecycle {
    ignore_changes = [value]
  }
}
```

### 복구 절차

1. **시크릿 삭제 취소** (30일 이내):
```bash
aws secretsmanager restore-secret \
  --secret-id /ryuqqq/crawler/prod/db-master \
  --region ap-northeast-2
```

2. **이전 버전 복구**:
```bash
# 모든 버전 확인
aws secretsmanager list-secret-version-ids \
  --secret-id /ryuqqq/crawler/prod/db-master

# 특정 버전으로 복구
aws secretsmanager update-secret-version-stage \
  --secret-id /ryuqqq/crawler/prod/db-master \
  --version-stage AWSCURRENT \
  --move-to-version-id [VERSION_ID]
```

## 트러블슈팅

### 문제: Access Denied 에러

**원인**: IAM 역할에 시크릿 또는 KMS 키 접근 권한 없음

**해결**:
1. IAM 정책에 `secretsmanager:GetSecretValue` 권한 추가
2. KMS 키 정책에서 ViaService condition 확인
3. 리소스 ARN이 정확한지 확인

### 문제: 로테이션 실패

**원인**: Lambda 함수 오류 또는 권한 문제

**해결**:
```bash
# Lambda 로그 확인
aws logs tail /aws/lambda/rotation-function --follow

# 로테이션 상태 확인
aws secretsmanager describe-secret \
  --secret-id /ryuqqq/crawler/prod/db-master
```

### 문제: 시크릿 버전 충돌

**원인**: 동시 업데이트로 인한 버전 충돌

**해결**:
- Terraform에서 `lifecycle.ignore_changes = [secret_string]` 사용
- 수동 업데이트는 AWS Console이나 CLI로만 수행

## 베스트 프랙티스

1. **시크릿 구조화**: JSON 형식으로 관련 정보 함께 저장
2. **버전 관리**: 배포 시 특정 버전 사용, `AWSCURRENT` 의존 지양
3. **캐싱**: 애플리케이션 레벨에서 1시간 TTL 캐싱
4. **에러 핸들링**: 시크릿 읽기 실패 시 적절한 재시도 로직
5. **로테이션 테스트**: 프로덕션 배포 전 staging에서 로테이션 검증
6. **감사 로그 검토**: 주기적으로 CloudTrail 로그 분석
7. **비용 최적화**: 미사용 시크릿 정기 정리

## 참고 자료

- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [Terraform AWS Secrets Manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret)
- [Infrastructure Governance Guide](../docs/infrastructure_governance.md)
- [KMS Strategy Guide](kms-strategy.md)
