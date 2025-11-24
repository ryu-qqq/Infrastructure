# CloudWatch Log Group Terraform Module

재사용 가능한 CloudWatch Log Group 모듈로, KMS 암호화, Retention 정책, 표준 태그를 자동으로 적용합니다.

## Features

- ✅ CloudWatch Log Group 생성
- ✅ KMS 암호화 지원
- ✅ Retention 정책 적용
- ✅ 표준화된 태그 자동 적용
- ✅ Sentry 통합 준비 (Subscription Filter)
- ✅ Langfuse 통합 준비 (Subscription Filter)
- ✅ 에러율 모니터링 Metric Filter
- ✅ 네이밍 규칙 검증

## Usage

### Basic Example

```hcl
module "application_logs" {
  source = "../../modules/cloudwatch-log-group"

  name               = "/aws/ecs/api-server/application"
  retention_in_days  = 14
  kms_key_id         = aws_kms_key.cloudwatch_logs.arn
  log_type           = "application"

  # Required tagging variables
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

### Error Logs with Sentry Integration (Future)

```hcl
module "error_logs" {
  source = "../../modules/cloudwatch-log-group"

  name               = "/aws/ecs/api-server/errors"
  retention_in_days  = 90
  kms_key_id         = aws_kms_key.cloudwatch_logs.arn
  log_type           = "errors"

  # Required tagging variables
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  # Sentry integration (future)
  sentry_sync_status    = "pending"  # "enabled" when Lambda is ready
  sentry_filter_pattern = "[timestamp, request_id, level=ERROR*, ...]"
  sentry_lambda_arn     = null       # Add Lambda ARN when ready

  # Error rate monitoring
  enable_error_rate_metric = true
  error_metric_pattern     = "[timestamp, request_id, level=ERROR*, ...]"
  metric_namespace         = "CustomLogs/APIServer"
}
```

### LLM Logs with Langfuse Integration (Future)

```hcl
module "llm_logs" {
  source = "../../modules/cloudwatch-log-group"

  name               = "/aws/ecs/api-server/llm"
  retention_in_days  = 60
  kms_key_id         = aws_kms_key.cloudwatch_logs.arn
  log_type           = "llm"

  # Required tagging variables
  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"

  # Langfuse integration (future)
  langfuse_sync_status    = "pending"
  langfuse_filter_pattern = "[timestamp, request_id, model, ...]"
  langfuse_lambda_arn     = null
}
```

### Lambda Function Logs

```hcl
module "lambda_logs" {
  source = "../../modules/cloudwatch-log-group"

  name               = "/aws/lambda/secrets-manager-rotation"
  retention_in_days  = 14
  kms_key_id         = aws_kms_key.cloudwatch_logs.arn
  log_type           = "application"

  # Required tagging variables
  environment  = "prod"
  service_name = "secrets-rotation"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

## Inputs

### Required Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `name` | CloudWatch Log Group name (must follow naming convention) | `string` | - | yes |
| `retention_in_days` | Number of days to retain logs | `number` | - | yes |

### Required Variables - Tagging

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | 환경 이름 (dev, staging, prod) | `string` | - | yes |
| `service_name` | 서비스 이름 (kebab-case) | `string` | - | yes |
| `team` | 담당 팀 (kebab-case) | `string` | - | yes |
| `owner` | 리소스 소유자 (이메일 또는 kebab-case) | `string` | - | yes |
| `cost_center` | 비용 센터 (kebab-case) | `string` | - | yes |

### Optional Variables - Tagging

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `project` | 프로젝트 이름 | `string` | `"infrastructure"` | no |
| `data_class` | 데이터 분류 (confidential, internal, public) | `string` | `"confidential"` | no |
| `additional_tags` | 추가 태그 | `map(string)` | `{}` | no |

### Optional Variables - Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `kms_key_id` | ARN of KMS key for encryption | `string` | `null` | no |
| `log_type` | Type of logs (application, errors, llm, etc.) | `string` | `"application"` | no |
| `export_to_s3_enabled` | Whether S3 export is enabled | `bool` | `false` | no |
| `sentry_sync_status` | Sentry sync status (pending/enabled/disabled) | `string` | `"disabled"` | no |
| `langfuse_sync_status` | Langfuse sync status (pending/enabled/disabled) | `string` | `"disabled"` | no |
| `sentry_filter_pattern` | Filter pattern for Sentry subscription | `string` | `"[timestamp, request_id, level=ERROR*, ...]"` | no |
| `sentry_lambda_arn` | Lambda ARN for Sentry integration | `string` | `null` | no |
| `langfuse_filter_pattern` | Filter pattern for Langfuse subscription | `string` | `"[timestamp, request_id, model, ...]"` | no |
| `langfuse_lambda_arn` | Lambda ARN for Langfuse integration | `string` | `null` | no |
| `enable_error_rate_metric` | Create metric filter for error rate | `bool` | `false` | no |
| `error_metric_pattern` | Pattern for error metric filter | `string` | `"[timestamp, request_id, level=ERROR*, ...]"` | no |
| `metric_namespace` | CloudWatch metric namespace | `string` | `"CustomLogs"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `log_group_name` | Name of the created log group |
| `log_group_arn` | ARN of the created log group |
| `log_group_id` | ID of the created log group |
| `retention_in_days` | Retention period in days |
| `kms_key_id` | KMS key ID used for encryption |
| `tags` | Tags applied to the log group |
| `sentry_subscription_filter_name` | Name of Sentry subscription filter (if enabled) |
| `langfuse_subscription_filter_name` | Name of Langfuse subscription filter (if enabled) |

## Log Type and Retention Guidelines

| Log Type | Retention | Use Case |
|----------|-----------|----------|
| `application` | 14 days | General application logs |
| `errors` | 90 days | Error logs for Sentry integration |
| `llm` | 60 days | LLM calls for Langfuse integration |
| `access` | 7 days | ALB/API Gateway access logs |
| `audit` | 365 days | Audit trail for compliance |
| `slowquery` | 30 days | RDS slow query logs |
| `general` | 14 days | General purpose logs |

## Naming Convention

Log group names must follow the pattern:
```
/aws/{service}/{resource-name}/{log-type}
```

Examples:
- `/aws/ecs/api-server/application`
- `/aws/ecs/api-server/errors`
- `/aws/lambda/secrets-manager-rotation`
- `/aws/rds/production-postgres/slowquery`

See [LOGGING_NAMING_CONVENTION.md](../../../docs/LOGGING_NAMING_CONVENTION.md) for details.

## Validation

The module includes automatic validation for:

- ✅ Naming convention compliance
- ✅ Valid retention period values
- ✅ Valid log type values
- ✅ Valid sync status values

Invalid inputs will fail at `terraform plan` stage with clear error messages.

## Tags Applied

All log groups automatically receive:

**공통 태그 (common-tags 모듈에서):**
- `Environment` - 환경 이름
- `Service` - 서비스 이름
- `Team` - 담당 팀
- `Owner` - 리소스 소유자
- `CostCenter` - 비용 센터
- `ManagedBy` - 관리 방법 (항상 "Terraform")
- `Project` - 프로젝트 이름
- `DataClass` - 데이터 분류

**모듈별 태그:**
- `Name` - Log group name
- `LogType` - Type of logs (application, errors, llm, etc.)
- `RetentionDays` - Retention period
- `KMSEncrypted` - Whether KMS encryption is enabled
- `ExportToS3` - S3 export status
- `SentrySync` - Sentry integration status
- `LangfuseSync` - Langfuse integration status
- `Component` - 컴포넌트 타입 (log-group)

## Future Enhancements

### Phase 2: Sentry Integration
- Lambda function for error log transformation
- Subscription filter activation
- Sentry API integration

### Phase 3: Langfuse Integration
- Lambda function for LLM log transformation
- Subscription filter activation
- Langfuse API integration

### Phase 4: S3 Export
- Automated S3 export for long-term archival
- Lifecycle policies for cost optimization

## Related Documentation

- [Logging System Design](../../../claudedocs/IN-116-logging-system-design.md)
- [Logging Naming Convention](../../../docs/LOGGING_NAMING_CONVENTION.md)
- [Tagging Standards](../../../docs/TAGGING_STANDARDS.md)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## License

Internal use only - Infrastructure Team
