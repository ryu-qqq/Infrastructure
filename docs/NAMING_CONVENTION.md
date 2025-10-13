# AWS 리소스 네이밍 규약

## 개요

AWS 인프라의 일관성과 관리 효율성을 위한 표준 네이밍 규약입니다. 모든 리소스는 kebab-case를 사용하며, 환경, 서비스, 목적을 명확히 식별할 수 있어야 합니다.

## 기본 원칙

1. **kebab-case 사용**: 소문자와 하이픈(`-`)만 사용
2. **명확성**: 리소스 목적과 기능이 이름에서 명확히 드러나야 함
3. **일관성**: 같은 유형의 리소스는 동일한 패턴 적용
4. **길이 제한**: AWS 서비스별 이름 길이 제한 준수

## 네이밍 패턴

### 기본 패턴

```
{environment}-{service}-{resource-type}-{identifier}
```

**예시**:
- `prod-api-alb-main`
- `dev-database-rds-primary`
- `staging-web-s3-assets`

### 환경별 Prefix

| 환경 | Prefix | 설명 |
|------|--------|------|
| Production | `prod` | 운영 환경 |
| Staging | `staging` | 스테이징 환경 |
| Development | `dev` | 개발 환경 |

### 리소스 유형별 네이밍 규칙

#### VPC 및 네트워크

**VPC**
```
{environment}-{purpose}-vpc
예: prod-server-vpc, dev-client-vpc
```

**Subnet**
```
{environment}-{visibility}-{az}-subnet
예: prod-public-a-subnet, prod-private-b-subnet
```

**Route Table**
```
{environment}-{visibility}-{purpose}-rt
예: prod-public-main-rt, prod-private-app-rt
```

**Internet Gateway / NAT Gateway**
```
{environment}-{type}-{purpose}-gw
예: prod-internet-main-gw, prod-nat-a-gw
```

**Security Group**
```
{environment}-{service}-{purpose}-sg
예: prod-api-alb-sg, prod-database-rds-sg
```

#### Compute (EC2, ECS)

**EC2 Instance**
```
{environment}-{service}-{role}-{number}
예: prod-api-web-01, dev-bastion-host-01
```

**ECS Cluster**
```
{environment}-{service}-cluster
예: prod-api-cluster, staging-worker-cluster
```

**ECS Task Definition**
```
{environment}-{service}-{task-name}
예: prod-api-backend, dev-worker-email
```

**Auto Scaling Group**
```
{environment}-{service}-asg
예: prod-api-asg, staging-worker-asg
```

#### Database

**RDS Instance**
```
{environment}-{service}-{database-type}
예: prod-api-postgres, dev-analytics-mysql
```

**DynamoDB Table**
```
{environment}-{service}-{table-name}
예: prod-api-sessions, dev-cache-users
```

**ElastiCache**
```
{environment}-{service}-{cache-type}
예: prod-api-redis, staging-session-memcached
```

#### Storage

**S3 Bucket**
```
{organization}-{environment}-{service}-{purpose}-{account-id}
예: myorg-prod-api-assets-123456789012
예: myorg-dev-logs-cloudtrail-123456789012
```

**EBS Volume**
```
{environment}-{service}-{purpose}-vol
예: prod-database-data-vol, dev-api-backup-vol
```

#### Security

**KMS Key Alias**
```
alias/{service}-{purpose}
예: alias/rds-encryption, alias/s3-data-encryption
```

**IAM Role**
```
{service}-{purpose}-role
예: ecs-task-execution-role, lambda-processing-role
```

**IAM Policy**
```
{service}-{purpose}-policy
예: s3-read-only-policy, cloudwatch-logs-policy
```

**Secrets Manager Secret**
```
{environment}/{service}/{secret-name}
예: prod/api/database-password, dev/worker/api-key
```

#### Load Balancing

**ALB/NLB**
```
{environment}-{service}-{type}
예: prod-api-alb, staging-tcp-nlb
```

**Target Group**
```
{environment}-{service}-{port}-tg
예: prod-api-8080-tg, dev-web-3000-tg
```

#### Monitoring & Logging

**CloudWatch Log Group**
```
/aws/{service}/{environment}/{component}
예: /aws/ecs/prod/api
예: /aws/lambda/dev/processor
```

**CloudWatch Alarm**
```
{environment}-{service}-{metric}-alarm
예: prod-api-cpu-high-alarm, dev-rds-storage-low-alarm
```

**SNS Topic**
```
{environment}-{purpose}-notifications
예: prod-security-alerts-notifications
예: dev-deployment-status-notifications
```

#### Lambda

**Lambda Function**
```
{environment}-{service}-{function-name}
예: prod-api-image-processor, dev-data-transformer
```

#### Container Registry

**ECR Repository**
```
{service}/{component}
예: api/backend, web/frontend, worker/email
```

## 특수 케이스

### 공유 리소스

조직 전체에서 공유되는 리소스는 `shared` prefix 사용:

```
shared-{purpose}-{resource-type}
예: shared-artifacts-s3, shared-terraform-state-bucket
```

### Multi-Region 리소스

여러 리전에 배포되는 리소스는 리전 코드 포함:

```
{environment}-{region}-{service}-{resource-type}
예: prod-us-east-1-api-alb, prod-ap-northeast-2-web-s3
```

### 계정 ID 포함

글로벌하게 고유해야 하는 리소스(S3, ECR 등)는 계정 ID 포함:

```
{organization}-{environment}-{service}-{purpose}-{account-id}
예: mycompany-prod-logs-cloudtrail-123456789012
```

## 금지 사항

❌ **하지 말아야 할 것**:
- camelCase: `myApiServer` (X)
- snake_case: `my_api_server` (X)
- UPPER_CASE: `MY_API_SERVER` (X)
- 특수문자: `my.api@server` (X)
- 공백: `my api server` (X)
- 숫자로 시작: `1-api-server` (X)
- 연속 하이픈: `my--api--server` (X)
- 마지막 하이픈: `my-api-server-` (X)

## 검증 규칙

모든 리소스 이름은 다음 정규식 패턴을 준수해야 합니다:

```regex
^[a-z][a-z0-9-]*[a-z0-9]$
```

**규칙 설명**:
- 소문자로 시작
- 소문자, 숫자, 하이픈만 포함
- 숫자 또는 소문자로 끝남
- 최소 2자 이상

## 예외 사항

AWS 서비스별 특정 제약사항이 있는 경우 해당 서비스의 제약사항을 우선 적용:

- S3 버킷: 글로벌 고유성, 63자 이하, 점(`.`) 포함 가능하나 권장하지 않음
- Lambda 함수: 64자 이하
- RDS 식별자: 63자 이하
- IAM 역할: 64자 이하

## 적용 방법

### Terraform에서 사용

```hcl
resource "aws_instance" "api" {
  # ...

  tags = {
    Name = "${var.environment}-${var.service}-web-01"
  }
}
```

### 검증

OPA(Open Policy Agent) 정책을 통해 자동으로 네이밍 규약 준수 여부를 검증합니다.

```bash
# OPA 정책 테스트
opa test policies/
```

## 문의

네이밍 규약 관련 문의사항이나 예외 승인이 필요한 경우 Platform Team에 문의하세요.
