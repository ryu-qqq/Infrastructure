# EventBridge Module

EventBridge Rule과 Target을 생성하는 모듈입니다.

## 지원 Target 타입

- **ECS**: 스케줄 기반 ECS Task 실행
- **Lambda**: Lambda 함수 트리거
- **SNS**: SNS Topic으로 메시지 전송
- **SQS**: SQS Queue로 메시지 전송

## 사용 예시

### 스케줄 기반 ECS Task 실행

```hcl
module "scheduler" {
  source = "../../modules/eventbridge"

  name        = "crawler-scheduler"
  description = "Run crawler task every hour"
  target_type = "ecs"

  # 매시간 실행
  schedule_expression = "rate(1 hour)"

  # ECS 설정
  ecs_cluster_arn         = data.aws_ecs_cluster.main.arn
  ecs_task_definition_arn = aws_ecs_task_definition.scheduler.arn
  ecs_task_count          = 1
  ecs_launch_type         = "FARGATE"

  ecs_network_configuration = {
    subnets          = local.private_subnets
    security_groups  = [aws_security_group.scheduler.id]
    assign_public_ip = false
  }

  ecs_task_role_arns = [
    aws_iam_role.ecs_task_execution.arn,
    aws_iam_role.ecs_task.arn
  ]

  common_tags = {
    Environment = "prod"
    Service     = "crawler-scheduler"
  }
}
```

### Cron 표현식 사용

```hcl
module "daily_report" {
  source = "../../modules/eventbridge"

  name        = "daily-report"
  description = "Generate daily report at 9 AM KST"
  target_type = "lambda"

  # 매일 오전 9시 (KST = UTC+9, so 0 AM UTC)
  schedule_expression = "cron(0 0 * * ? *)"

  lambda_function_arn  = aws_lambda_function.report.arn
  lambda_function_name = aws_lambda_function.report.function_name

  common_tags = local.common_tags
}
```

### 이벤트 패턴 기반 (S3 이벤트)

```hcl
module "s3_trigger" {
  source = "../../modules/eventbridge"

  name        = "s3-upload-trigger"
  description = "Trigger on S3 object upload"
  target_type = "lambda"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = ["my-bucket"]
      }
    }
  })

  lambda_function_arn  = aws_lambda_function.processor.arn
  lambda_function_name = aws_lambda_function.processor.function_name

  common_tags = local.common_tags
}
```

### SNS 알림

```hcl
module "alarm_notification" {
  source = "../../modules/eventbridge"

  name        = "cloudwatch-alarm-to-sns"
  description = "Forward CloudWatch alarms to SNS"
  target_type = "sns"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    detail = {
      state = {
        value = ["ALARM"]
      }
    }
  })

  sns_topic_arn = aws_sns_topic.alerts.arn

  common_tags = local.common_tags
}
```

## 입력 변수

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | EventBridge rule 이름 | `string` | n/a | yes |
| target_type | Target 타입 (ecs, lambda, sns, sqs) | `string` | n/a | yes |
| description | Rule 설명 | `string` | `""` | no |
| schedule_expression | 스케줄 표현식 | `string` | `null` | no |
| event_pattern | 이벤트 패턴 JSON | `string` | `null` | no |
| enabled | Rule 활성화 여부 | `bool` | `true` | no |
| ecs_cluster_arn | ECS 클러스터 ARN | `string` | `null` | no |
| ecs_task_definition_arn | ECS Task Definition ARN | `string` | `null` | no |
| ecs_task_count | 실행할 Task 수 | `number` | `1` | no |
| ecs_launch_type | ECS 실행 타입 | `string` | `"FARGATE"` | no |
| ecs_network_configuration | ECS 네트워크 설정 | `object` | `null` | no |
| ecs_task_role_arns | ECS Task Role ARN 목록 | `list(string)` | `[]` | no |
| lambda_function_arn | Lambda 함수 ARN | `string` | `null` | no |
| lambda_function_name | Lambda 함수 이름 | `string` | `null` | no |
| sns_topic_arn | SNS Topic ARN | `string` | `null` | no |
| sqs_queue_arn | SQS Queue ARN | `string` | `null` | no |
| common_tags | 공통 태그 | `map(string)` | `{}` | no |

## 출력 값

| Name | Description |
|------|-------------|
| rule_arn | EventBridge rule ARN |
| rule_name | EventBridge rule 이름 |
| eventbridge_role_arn | EventBridge IAM role ARN (ECS target만) |
| eventbridge_role_name | EventBridge IAM role 이름 (ECS target만) |

## Schedule Expression 예시

### Rate 표현식

```
rate(5 minutes)    # 5분마다
rate(1 hour)       # 1시간마다
rate(1 day)        # 1일마다
```

### Cron 표현식

```
cron(분 시 일 월 요일 년)

cron(0 12 * * ? *)        # 매일 12:00 UTC
cron(0 0 * * ? *)         # 매일 00:00 UTC (한국 09:00)
cron(0/15 * * * ? *)      # 15분마다
cron(0 9 ? * MON-FRI *)   # 평일 09:00 UTC
```

## 보안 고려사항

- ECS Target 사용 시 IAM Role이 자동 생성됨
- IAM 권한은 최소 권한 원칙을 따름 (특정 Task Definition, Cluster만 허용)
- Lambda Target 사용 시 Lambda Permission이 자동 생성됨
