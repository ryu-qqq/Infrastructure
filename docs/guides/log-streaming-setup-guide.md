# Log Streaming 설정 가이드

ECS 서비스의 CloudWatch Logs를 OpenSearch로 스트리밍하는 방법을 안내합니다.

## 목차

1. [개요](#개요)
2. [사전 조건](#사전-조건)
3. [설정 방법](#설정-방법)
4. [필터 패턴 예시](#필터-패턴-예시)
5. [확인 방법](#확인-방법)
6. [문제 해결](#문제-해결)

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
│  │  /aws/ecs/...   │     │ log-subscription-filter 모듈 사용          │  │
│  └─────────────────┘     └──────────────────────────────────────────┘  │
│                                           │                            │
└───────────────────────────────────────────┼────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Infrastructure 레포 (중앙 관리)                                          │
│                                                                         │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │ Kinesis Firehose │────▶│ Lambda Transform │────▶│   OpenSearch    │   │
│  │                 │     │ (로그 포맷 변환)   │     │   Dashboard     │   │
│  └─────────────────┘     └─────────────────┘     └─────────────────┘   │
│           │                                              │              │
│           ▼                                              ▼              │
│  ┌─────────────────┐                           ┌─────────────────┐     │
│  │   S3 Backup     │                           │    Alerting     │     │
│  │ (실패 로그 저장)  │                           │   → n8n → Slack │     │
│  └─────────────────┘                           └─────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

### 데이터 흐름

1. **ECS 서비스** → 애플리케이션 로그 출력
2. **CloudWatch Logs** → 로그 수집 및 저장
3. **Subscription Filter** → 로그 필터링 및 전송 (이 가이드에서 설정)
4. **Kinesis Firehose** → 버퍼링 및 배치 전송
5. **Lambda** → 로그 포맷 변환 (CloudWatch → OpenSearch 형식)
6. **OpenSearch** → 로그 저장, 검색, 대시보드, 알림

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
- `/shared/logging/firehose-arn`
- `/shared/logging/cloudwatch-to-firehose-role-arn`

```bash
# AWS CLI로 확인
aws ssm get-parameter --name "/shared/logging/firehose-arn" --query "Parameter.Value" --output text
aws ssm get-parameter --name "/shared/logging/cloudwatch-to-firehose-role-arn" --query "Parameter.Value" --output text
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
# Log Streaming to OpenSearch
# ========================================

module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

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

## 프로젝트별 설정 예시

### CrawlingHub

`crawlinghub/terraform/ecs-web-api/main.tf`:

```hcl
# 기존 로그 그룹 모듈 아래에 추가

# ========================================
# Log Streaming to OpenSearch
# ========================================

module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
}
```

`crawlinghub/terraform/ecs-scheduler/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.scheduler_logs.log_group_name
  service_name   = "crawlinghub-scheduler"
}
```

`crawlinghub/terraform/ecs-crawl-worker/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.worker_logs.log_group_name
  service_name   = "crawlinghub-worker"
}
```

### AuthHub

`AuthHub/terraform/ecs-web-api/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "authhub-web-api"
}
```

### Fileflow

`fileflow/terraform/ecs-web-api/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "fileflow-web-api"
}
```

`fileflow/terraform/ecs-scheduler/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.scheduler_logs.log_group_name
  service_name   = "fileflow-scheduler"
}
```

`fileflow/terraform/ecs-resizing-worker/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.resizing_worker_logs.log_group_name
  service_name   = "fileflow-resizing-worker"
}
```

`fileflow/terraform/ecs-download-worker/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.download_worker_logs.log_group_name
  service_name   = "fileflow-download-worker"
}
```

### Gateway

`connectly-gateway/terraform/ecs-gateway/main.tf`:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.gateway_logs.log_group_name
  service_name   = "gateway"
}
```

---

## 필터 패턴 예시

### 모든 로그 스트리밍 (기본값)

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
  # filter_pattern 미지정 = 모든 로그
}
```

### 에러 로그만 스트리밍

```hcl
module "error_log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

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

# 복합 조건
filter_pattern = "{ $.level = \"ERROR\" && $.thread_name = \"*http*\" }"
```

### Exception 포함 로그만

```hcl
filter_pattern = "Exception"
# 또는
filter_pattern = "{ $.stack_trace = \"*\" }"
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
#       "filterName": "crawlinghub-web-api-to-opensearch",
#       "logGroupName": "/aws/ecs/crawlinghub-web-api-prod/application",
#       "destinationArn": "arn:aws:firehose:ap-northeast-2:...:deliverystream/prod-logs-to-opensearch",
#       ...
#     }
#   ]
# }
```

### 2. Kinesis Firehose 상태 확인

```bash
aws firehose describe-delivery-stream \
  --delivery-stream-name "prod-logs-to-opensearch" \
  --query "DeliveryStreamDescription.DeliveryStreamStatus"
# 출력: "ACTIVE"
```

### 3. OpenSearch에서 로그 확인

1. OpenSearch Dashboards 접속
2. **Discover** 메뉴로 이동
3. 인덱스 패턴: `logs-*`
4. 시간 범위 설정 후 로그 검색

### 4. 실패 로그 확인 (S3)

```bash
# 실패한 로그가 있는지 확인
aws s3 ls s3://prod-log-firehose-backup-{account-id}/failed-logs/ --recursive
```

---

## 문제 해결

### SSM Parameter를 찾을 수 없음

```
Error: Error reading SSM Parameter /shared/logging/firehose-arn: ParameterNotFound
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

2. **Firehose 상태 확인**
   ```bash
   aws firehose describe-delivery-stream --delivery-stream-name "prod-logs-to-opensearch"
   ```

3. **Lambda 로그 확인**
   ```bash
   aws logs tail "/aws/lambda/prod-log-transformer" --follow
   ```

4. **S3 백업에서 실패 로그 확인**
   ```bash
   aws s3 ls s3://prod-log-firehose-backup-{account-id}/failed-logs/
   ```

5. **OpenSearch 클러스터 상태 확인**
   - OpenSearch Dashboards → Management → Cluster settings

### 특정 로그만 누락됨

**원인**: filter_pattern이 너무 제한적

**해결**:
- filter_pattern을 임시로 빈 문자열(`""`)로 설정
- 모든 로그가 들어오는지 확인
- filter_pattern 문법 재검토

---

## 체크리스트

각 서비스에 로그 스트리밍을 추가할 때 다음을 확인하세요:

- [ ] Infrastructure 레포의 `enable_log_streaming = true` 확인
- [ ] SSM Parameters 존재 확인
- [ ] CloudWatch Log Group 이름 확인
- [ ] `log-subscription-filter` 모듈 추가
- [ ] `terraform plan`으로 변경사항 확인
- [ ] `terraform apply` 실행
- [ ] 구독 필터 생성 확인
- [ ] OpenSearch에서 로그 조회 확인

---

## 관련 문서

- [CloudWatch Logs Filter Pattern Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [Kinesis Firehose 문서](https://docs.aws.amazon.com/firehose/latest/dev/what-is-this-service.html)
- [OpenSearch 문서](https://opensearch.org/docs/latest/)
