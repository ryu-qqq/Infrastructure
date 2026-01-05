# Log Subscription Filter V2 Module

CloudWatch Logs를 Kinesis Data Streams로 전송하는 구독 필터를 생성합니다.

## Architecture

```
CloudWatch Logs → Subscription Filter → Kinesis Data Streams → Lambda → OpenSearch
```

## Prerequisites

Infrastructure 레포의 중앙 로그 스트리밍 인프라가 활성화되어 있어야 합니다:

```bash
# SSM 파라미터 확인
aws ssm get-parameter --name "/shared/logging/kinesis-stream-arn"
aws ssm get-parameter --name "/shared/logging/cloudwatch-to-kinesis-role-arn"
```

## Usage

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter-v2?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
}
```

### With Filter Pattern

```hcl
module "error_log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter-v2?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api-errors"
  filter_pattern = "ERROR"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `log_group_name` | CloudWatch Log Group name | `string` | - | yes |
| `service_name` | Service name (kebab-case) | `string` | - | yes |
| `filter_pattern` | Log filter pattern | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| `subscription_filter_name` | Name of the subscription filter |
| `kinesis_stream_arn` | ARN of the Kinesis destination |

## Index Pattern

로그는 OpenSearch에서 서비스별로 분리된 인덱스에 저장됩니다:

```
logs-{service}-YYYY-MM-DD
```

예시:
- `logs-crawlinghub-2024-01-15`
- `logs-gateway-2024-01-15`
- `logs-authhub-2024-01-15`

## Migration from V1

기존 `log-subscription-filter` 모듈(Firehose 대상)에서 마이그레이션:

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

변경 사항:
- Firehose → Kinesis Data Streams
- 개별 로그 이벤트가 개별 OpenSearch 문서로 저장됨
- 서비스별 인덱스 자동 라우팅
