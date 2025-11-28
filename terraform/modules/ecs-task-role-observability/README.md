# ECS Task Role with Observability

ECS Task Role 모듈로 X-Ray, CloudWatch Logs, CloudWatch Metrics 권한을 포함한 Observability 설정을 제공합니다.

## 사용 목적

Spring Boot 3.x + Micrometer + OpenTelemetry (OTEL) + AWS X-Ray 통합 환경에서 ECS Task가 런타임에 필요한 IAM 권한을 제공합니다.

## 포함 권한

### X-Ray (Distributed Tracing)
- `xray:PutTraceSegments` - 트레이스 세그먼트 전송
- `xray:PutTelemetryRecords` - 텔레메트리 레코드 전송
- `xray:GetSamplingRules` - 샘플링 규칙 조회
- `xray:GetSamplingTargets` - 샘플링 대상 조회

### CloudWatch Logs (OTEL Collector)
- `logs:CreateLogGroup` - 로그 그룹 생성
- `logs:CreateLogStream` - 로그 스트림 생성
- `logs:PutLogEvents` - 로그 이벤트 전송
- `logs:DescribeLogStreams` - 로그 스트림 조회

### CloudWatch Metrics (Micrometer)
- `cloudwatch:PutMetricData` - 메트릭 데이터 전송 (namespace 조건부)

## 사용법

### 기본 사용 (Combined Policy)

```hcl
module "task_role" {
  source = "../../modules/ecs-task-role-observability"

  role_name    = "fileflow-web-api-task-role-prod"
  environment  = "prod"
  service_name = "web-api"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
  project      = "fileflow"

  # 단일 통합 정책 사용 (권장)
  enable_combined_observability_policy = true

  # CloudWatch Metrics namespace 제한
  cloudwatch_metric_namespaces = ["FileFlow"]

  # OTEL 로그 그룹
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/ecs/fileflow/otel"
  ]
}
```

### 개별 정책 사용

```hcl
module "task_role" {
  source = "../../modules/ecs-task-role-observability"

  role_name    = "myservice-task-role-prod"
  environment  = "prod"
  service_name = "myservice"
  team         = "backend-team"
  owner        = "backend@example.com"
  cost_center  = "engineering"
  project      = "myservice"

  # 개별 정책 활성화/비활성화
  enable_combined_observability_policy = false
  enable_xray_policy                   = true
  enable_cloudwatch_logs_policy        = true
  enable_cloudwatch_metrics_policy     = true

  # CloudWatch 설정
  cloudwatch_metric_namespaces = ["MyService"]
  cloudwatch_log_group_arns = [
    "arn:aws:logs:ap-northeast-2:123456789012:log-group:/ecs/myservice/otel"
  ]
}
```

### 커스텀 정책 추가

```hcl
module "task_role" {
  source = "../../modules/ecs-task-role-observability"

  role_name    = "myservice-task-role-prod"
  environment  = "prod"
  service_name = "myservice"
  team         = "backend-team"
  owner        = "backend@example.com"
  cost_center  = "engineering"

  enable_combined_observability_policy = true
  cloudwatch_metric_namespaces         = ["MyService"]

  # 추가 커스텀 정책
  custom_inline_policies = {
    "s3-access" = {
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject"]
          Resource = "arn:aws:s3:::my-bucket/*"
        }]
      })
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| role_name | IAM 역할 이름 (kebab-case) | `string` | n/a | yes |
| environment | 환경 (dev, staging, prod) | `string` | n/a | yes |
| service_name | 서비스 이름 (kebab-case) | `string` | n/a | yes |
| team | 담당 팀 (kebab-case) | `string` | n/a | yes |
| owner | 소유자 이메일 | `string` | n/a | yes |
| cost_center | 비용 센터 | `string` | n/a | yes |
| enable_combined_observability_policy | 통합 Observability 정책 사용 | `bool` | `false` | no |
| enable_xray_policy | X-Ray 정책 활성화 | `bool` | `true` | no |
| enable_cloudwatch_logs_policy | CloudWatch Logs 정책 활성화 | `bool` | `true` | no |
| enable_cloudwatch_metrics_policy | CloudWatch Metrics 정책 활성화 | `bool` | `true` | no |
| cloudwatch_metric_namespaces | 허용할 메트릭 네임스페이스 목록 | `list(string)` | `[]` | no |
| cloudwatch_log_group_arns | CloudWatch 로그 그룹 ARN 목록 | `list(string)` | `[]` | no |
| custom_inline_policies | 추가 인라인 정책 | `map(object)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| role_arn | IAM 역할 ARN |
| role_name | IAM 역할 이름 |
| role_id | IAM 역할 ID |
| inline_policy_names | 연결된 인라인 정책 이름 목록 |
| observability_enabled | 활성화된 Observability 기능 맵 |
| metric_namespaces | 허용된 메트릭 네임스페이스 |

## 관련 문서

- [Spring Boot Monitoring Guide](../../../spring-boot-monitoring-guide.md)
- [AWS X-Ray Documentation](https://docs.aws.amazon.com/xray/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
