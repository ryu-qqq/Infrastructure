# CloudWatch Log Subscription Filter Module

CloudWatch Logs를 중앙 OpenSearch로 스트리밍하기 위한 구독 필터를 생성합니다.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  각 서비스 레포 (CrawlingHub, AuthHub, Fileflow, Gateway 등)              │
│                                                                         │
│  ┌─────────────────┐     ┌──────────────────────────────────────────┐  │
│  │ CloudWatch Logs │────▶│ Subscription Filter (이 모듈이 생성)        │  │
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
│  └─────────────────┘     └─────────────────┘     └─────────────────┘   │
│                                                                         │
│  SSM Parameters:                                                        │
│  - /shared/logging/firehose-arn                                         │
│  - /shared/logging/cloudwatch-to-firehose-role-arn                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **중앙 로그 스트리밍 인프라 활성화 필요**
   ```hcl
   # terraform/environments/prod/logging/terraform.tfvars
   enable_log_streaming = true
   ```

2. **SSM Parameters가 존재해야 함**
   - `/shared/logging/firehose-arn`
   - `/shared/logging/cloudwatch-to-firehose-role-arn`

## Usage

### Basic Usage (모든 로그 스트리밍)

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
}
```

### Error Logs Only (에러 로그만 스트리밍)

```hcl
module "error_log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api-errors"
  filter_pattern = "ERROR"
}
```

### JSON Logs with Level Filter

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
  filter_pattern = "{ $.level = \"ERROR\" || $.level = \"WARN\" }"
}
```

### Multiple Log Groups

```hcl
# Application logs
module "app_log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
}

# Scheduler logs
module "scheduler_log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.scheduler_logs.log_group_name
  service_name   = "crawlinghub-scheduler"
}

# Worker logs
module "worker_log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.worker_logs.log_group_name
  service_name   = "crawlinghub-worker"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `log_group_name` | CloudWatch Log Group 이름 | `string` | - | yes |
| `service_name` | 서비스 이름 (구독 필터 명명에 사용) | `string` | - | yes |
| `filter_name` | 커스텀 구독 필터 이름 | `string` | `""` | no |
| `filter_pattern` | 로그 필터 패턴 (빈 문자열 = 모든 로그) | `string` | `""` | no |
| `distribution` | 로그 분배 방법 (`Random` or `ByLogStream`) | `string` | `"Random"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `subscription_filter_name` | 생성된 구독 필터 이름 |
| `log_group_name` | 스트리밍되는 로그 그룹 이름 |
| `firehose_arn` | Kinesis Firehose ARN |
| `filter_pattern` | 적용된 필터 패턴 |

## Filter Pattern Examples

### 모든 로그
```hcl
filter_pattern = ""
```

### 특정 텍스트 포함
```hcl
filter_pattern = "ERROR"
filter_pattern = "Exception"
filter_pattern = "WARN ERROR FATAL"  # OR 조건
```

### JSON 로그 필터링
```hcl
# 특정 레벨
filter_pattern = "{ $.level = \"ERROR\" }"

# 여러 레벨 (OR)
filter_pattern = "{ $.level = \"ERROR\" || $.level = \"WARN\" }"

# 특정 필드 값
filter_pattern = "{ $.statusCode >= 400 }"

# 복합 조건
filter_pattern = "{ $.level = \"ERROR\" && $.service = \"payment\" }"
```

### 공백 구분 로그 필터링
```hcl
# Apache/Nginx 액세스 로그에서 4xx/5xx 에러만
filter_pattern = "[ip, user, timestamp, request, status_code>=400, size]"
```

## Notes

- 하나의 로그 그룹당 **최대 2개의 구독 필터**만 생성 가능 (AWS 제한)
- 구독 필터는 생성 후 약 1-2분 내에 활성화됨
- OpenSearch에서 인덱스 이름: `logs-YYYY.MM.DD` (일별 로테이션)
- 실패한 로그는 S3 백업 버킷에 저장됨

## Troubleshooting

### SSM Parameter를 찾을 수 없음
```
Error: Error reading SSM Parameter /shared/logging/firehose-arn: ParameterNotFound
```
→ 중앙 로그 스트리밍 인프라가 활성화되어 있는지 확인 (`enable_log_streaming = true`)

### 구독 필터 생성 실패
```
Error: Creating CloudWatch Logs Subscription Filter failed: LimitExceededException
```
→ 해당 로그 그룹에 이미 2개의 구독 필터가 존재함. 기존 필터 삭제 필요.

### 로그가 OpenSearch에 나타나지 않음
1. Kinesis Firehose 상태 확인
2. Lambda 변환 함수 로그 확인
3. OpenSearch 클러스터 상태 확인
4. S3 백업 버킷에서 실패한 로그 확인
