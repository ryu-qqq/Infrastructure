# Log Streaming 설정 가이드

ECS 서비스의 CloudWatch Logs를 OpenSearch로 스트리밍하는 방법을 안내합니다.

## 목차

1. [개요](#개요)
2. [사전 조건](#사전-조건)
3. [설정 방법](#설정-방법)
4. [인덱스 패턴](#인덱스-패턴)
5. [필터 패턴 예시](#필터-패턴-예시)
6. [확인 방법](#확인-방법)
7. [문제 해결](#문제-해결)

---

## 개요

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│  각 서비스 레포 (CrawlingHub, AuthHub, Fileflow, Gateway 등)              │
│                                                                         │
│  ┌─────────────────┐                                                    │
│  │   ECS Service   │                                                    │
│  │  (Spring Boot)  │                                                    │
│  └────────┬────────┘                                                    │
│           │ 로그 출력                                                    │
│           ▼                                                             │
│  ┌─────────────────┐     ┌──────────────────────────────────────────┐  │
│  │ CloudWatch Logs │────▶│ Subscription Filter (모듈로 생성)           │  │
│  │  /aws/ecs/...   │     │ log-subscription-filter-v2 모듈 사용       │  │
│  └─────────────────┘     └──────────────────────────────────────────┘  │
│                                           │                            │
└───────────────────────────────────────────┼────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Infrastructure 레포 (중앙 관리)                                          │
│                                                                         │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │ Kinesis Data    │────▶│ Lambda          │────▶│   OpenSearch    │   │
│  │ Streams         │     │ (log-router)    │     │   Dashboard     │   │
│  │                 │     │ 개별 문서 전송    │     │                 │   │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘   │
│                                   │                      │              │
│                                   ▼                      ▼              │
│                          ┌─────────────────┐    ┌─────────────────┐    │
│                          │   DLQ (SQS)     │    │    Alerting     │    │
│                          │  (실패 레코드)    │    │   → n8n → Slack │    │
│                          └─────────────────┘    └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 데이터 흐름

1. **ECS 서비스** → 애플리케이션 로그 출력
2. **CloudWatch Logs** → 로그 수집 및 저장
3. **Subscription Filter** → 로그 필터링 및 Kinesis 전송 (이 가이드에서 설정)
4. **Kinesis Data Streams** → 버퍼링 및 Lambda 트리거
5. **Lambda (log-router)** → 로그 파싱, 서비스별 인덱스 라우팅, 개별 문서 변환
6. **OpenSearch** → 로그 저장, 검색, 대시보드, 알림

### 주요 특징

- **개별 문서 저장**: 각 로그 이벤트가 개별 OpenSearch 문서로 저장됨
- **서비스별 인덱스**: `logs-{service}-YYYY-MM-DD` 형식으로 자동 라우팅
- **자동 스케일링**: Kinesis ON_DEMAND 모드로 샤드 관리 불필요
- **실패 처리**: DLQ로 실패 레코드 보관 (14일)

---

## 사전 조건

### 1. Infrastructure 레포의 중앙 로그 스트리밍이 활성화되어 있어야 함

```bash
# Infrastructure 레포에서 확인
cat terraform/environments/prod/logging/terraform.tfvars

# 다음 내용이 있어야 함:
# enable_log_streaming = true
```

### 2. SSM Parameters가 존재해야 함

다음 SSM 파라미터들이 AWS에 존재해야 합니다:
- `/shared/logging/kinesis-stream-arn`
- `/shared/logging/cloudwatch-to-kinesis-role-arn`

```bash
# AWS CLI로 확인
aws ssm get-parameter --name "/shared/logging/kinesis-stream-arn" --query "Parameter.Value" --output text
aws ssm get-parameter --name "/shared/logging/cloudwatch-to-kinesis-role-arn" --query "Parameter.Value" --output text
```

### 3. CloudWatch Log Group이 이미 생성되어 있어야 함

대부분의 서비스는 이미 `cloudwatch-log-group` 모듈을 사용하고 있습니다:

```hcl
module "web_api_logs" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/cloudwatch-log-group?ref=main"

  name              = "/aws/ecs/${var.project_name}-web-api-${var.environment}/application"
  retention_in_days = 30
  # ... tags
}
```

---

## 설정 방법

### Step 1: 모듈 추가

서비스의 `main.tf` 파일에 다음을 추가합니다:

```hcl
# ========================================
# Log Streaming to OpenSearch (V2 - Kinesis)
# ========================================

module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter-v2?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "${var.project_name}-web-api"
}
```

### Step 2: Terraform 실행

```bash
# 초기화 (새 모듈 다운로드)
terraform init

# 변경사항 확인
terraform plan

# 적용
terraform apply
```

### Step 3: 확인

```bash
# 구독 필터 생성 확인
aws logs describe-subscription-filters \
  --log-group-name "/aws/ecs/crawlinghub-web-api-prod/application"
```

---

## 인덱스 패턴

로그는 서비스별로 분리된 인덱스에 저장됩니다:

```
logs-{service}-YYYY-MM-DD
```

### 예시

| 서비스 | 인덱스 패턴 |
|--------|------------|
| Atlantis | `logs-atlantis-2024-01-15` |
| Gateway | `logs-gateway-2024-01-15` |
| AuthHub | `logs-authhub-2024-01-15` |
| CrawlingHub | `logs-crawlinghub-2024-01-15` |
| Fileflow | `logs-fileflow-2024-01-15` |

### OpenSearch에서 인덱스 패턴 생성

1. OpenSearch Dashboards 접속
2. **Management** → **Index Patterns** 이동
3. `logs-*` 또는 `logs-{service}-*` 패턴 생성
4. `@timestamp` 필드를 시간 필드로 선택

---

## 프로젝트별 설정 예시

### CrawlingHub

`crawlinghub/terraform/ecs-web-api/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter-v2?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
}
```

### AuthHub

`AuthHub/terraform/ecs-web-api/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter-v2?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "authhub-web-api"
}
```

### Gateway

`connectly-gateway/terraform/ecs-gateway/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter-v2?ref=main"

  log_group_name = module.gateway_logs.log_group_name
  service_name   = "gateway"
}
```

---

## 필터 패턴 예시

### 모든 로그 스트리밍 (기본값)

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter-v2?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
  # filter_pattern 미지정 = 모든 로그
}
```

### 에러 로그만 스트리밍

```hcl
module "error_log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter-v2?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api-errors"
  filter_pattern = "ERROR"
}
```

### JSON 로그 필터링 (Spring Boot Logback JSON)

```hcl
# ERROR 레벨만
filter_pattern = "{ $.level = \"ERROR\" }"

# ERROR 또는 WARN
filter_pattern = "{ $.level = \"ERROR\" || $.level = \"WARN\" }"

# 특정 logger
filter_pattern = "{ $.logger_name = \"*PaymentService*\" }"
```

---

## 확인 방법

### 1. 구독 필터 확인

```bash
# 구독 필터 목록
aws logs describe-subscription-filters \
  --log-group-name "/aws/ecs/crawlinghub-web-api-prod/application"

# 출력 예시:
# {
#   "subscriptionFilters": [
#     {
#       "filterName": "crawlinghub-web-api-to-kinesis",
#       "logGroupName": "/aws/ecs/crawlinghub-web-api-prod/application",
#       "destinationArn": "arn:aws:kinesis:ap-northeast-2:...:stream/prod-cloudwatch-logs",
#       ...
#     }
#   ]
# }
```

### 2. Kinesis 상태 확인

```bash
aws kinesis describe-stream-summary \
  --stream-name "prod-cloudwatch-logs"
# StreamStatus: ACTIVE
```

### 3. Lambda 로그 확인

```bash
aws logs tail "/aws/lambda/prod-log-router" --follow
```

### 4. OpenSearch에서 로그 확인

1. OpenSearch Dashboards 접속
2. **Discover** 메뉴로 이동
3. 인덱스 패턴: `logs-*` 또는 `logs-{service}-*`
4. 시간 범위 설정 후 로그 검색

### 5. DLQ 확인 (실패 레코드)

```bash
# DLQ 메시지 수 확인
aws sqs get-queue-attributes \
  --queue-url "https://sqs.ap-northeast-2.amazonaws.com/{account}/prod-log-router-dlq" \
  --attribute-names ApproximateNumberOfMessages
```

---

## 문제 해결

### SSM Parameter를 찾을 수 없음

```
Error: Error reading SSM Parameter /shared/logging/kinesis-stream-arn: ParameterNotFound
```

**원인**: 중앙 로그 스트리밍 인프라가 활성화되지 않음

**해결**:
1. Infrastructure 레포에서 `enable_log_streaming = true` 설정
2. `terraform apply` 실행
3. SSM 파라미터 생성 확인

### 구독 필터 생성 실패 - LimitExceededException

```
Error: Creating CloudWatch Logs Subscription Filter failed: LimitExceededException
```

**원인**: 하나의 로그 그룹에 최대 2개의 구독 필터만 허용됨

**해결**:
```bash
# 기존 구독 필터 확인
aws logs describe-subscription-filters --log-group-name "YOUR_LOG_GROUP"

# 불필요한 구독 필터 삭제
aws logs delete-subscription-filter \
  --log-group-name "YOUR_LOG_GROUP" \
  --filter-name "OLD_FILTER_NAME"
```

### 로그가 OpenSearch에 나타나지 않음

**점검 순서**:

1. **구독 필터 확인**
   ```bash
   aws logs describe-subscription-filters --log-group-name "YOUR_LOG_GROUP"
   ```

2. **Kinesis 상태 확인**
   ```bash
   aws kinesis describe-stream-summary --stream-name "prod-cloudwatch-logs"
   ```

3. **Lambda 로그 확인**
   ```bash
   aws logs tail "/aws/lambda/prod-log-router" --follow
   ```

4. **DLQ 확인**
   ```bash
   aws sqs get-queue-attributes \
     --queue-url "https://sqs.ap-northeast-2.amazonaws.com/{account}/prod-log-router-dlq" \
     --attribute-names ApproximateNumberOfMessages
   ```

5. **OpenSearch 클러스터 상태 확인**
   - OpenSearch Dashboards → Management → Cluster settings

### Lambda 에러: OpenSearch 연결 실패

**원인**: Lambda가 OpenSearch에 접근할 수 없음

**확인**:
- Lambda가 VPC 내에 있는지 확인
- Security Group 설정 확인
- OpenSearch 도메인 접근 정책 확인

---

## 체크리스트

각 서비스에 로그 스트리밍을 추가할 때 다음을 확인하세요:

- [ ] Infrastructure 레포의 `enable_log_streaming = true` 확인
- [ ] SSM Parameters 존재 확인
- [ ] CloudWatch Log Group 이름 확인
- [ ] `log-subscription-filter-v2` 모듈 추가
- [ ] `terraform plan`으로 변경사항 확인
- [ ] `terraform apply` 실행
- [ ] 구독 필터 생성 확인
- [ ] OpenSearch에서 로그 조회 확인

---

## Migration from V1 (Firehose)

기존 `log-subscription-filter` 모듈(Firehose)을 사용하고 있다면:

```hcl
# Before (V1 - Firehose)
module "log_streaming" {
  source = ".../log-subscription-filter"
  ...
}

# After (V2 - Kinesis)
module "log_streaming" {
  source = ".../log-subscription-filter-v2"
  ...
}
```

**주요 변경 사항**:
- 각 로그 이벤트가 개별 OpenSearch 문서로 저장됨
- 서비스별 인덱스 자동 라우팅 (`logs-{service}-*`)
- DLQ로 실패 레코드 보관

---

## 관련 문서

- [CloudWatch Logs Filter Pattern Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [Kinesis Data Streams 문서](https://docs.aws.amazon.com/streams/latest/dev/what-is-this-service.html)
- [OpenSearch 문서](https://opensearch.org/docs/latest/)
