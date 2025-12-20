# Alert Enrichment Lambda

Lambda function that enriches alerts with contextual information before sending to Slack.

## Architecture

```
Grafana (AMG) / CloudWatch Alarms
           │
           ▼
       SNS Topic
           │
           ▼
   Lambda (Enrichment)
           │
           ├─→ CloudWatch Logs (에러 로그)
           ├─→ X-Ray (트레이스 샘플)
           ├─→ AMP (메트릭 조회)
           ├─→ ECS (배포 정보)
           └─→ DynamoDB (Runbook 매핑)
           │
           ▼
     Slack Webhook
```

## Features

- **Error Log Collection**: Recent error logs from CloudWatch Logs
- **Deployment Tracking**: Recent ECS deployments
- **Trace Sampling**: Failed request traces from X-Ray
- **Runbook Integration**: Links to runbooks from DynamoDB
- **Rich Slack Messages**: Block Kit formatted messages with context

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| SLACK_WEBHOOK_URL | Slack Incoming Webhook URL | Yes |
| AMP_ENDPOINT | Amazon Managed Prometheus endpoint | No |
| RUNBOOK_TABLE_NAME | DynamoDB table for runbooks | No |
| GRAFANA_URL | Grafana dashboard base URL | No |
| CLOUDWATCH_BASE_URL | CloudWatch console base URL | No |
| AWS_REGION | AWS region | No (default: ap-northeast-2) |

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:FilterLogEvents",
        "logs:GetLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/ecs/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "xray:GetTraceSummaries",
        "xray:BatchGetTraces"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:ListServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/connectly-alert-runbooks"
    },
    {
      "Effect": "Allow",
      "Action": [
        "aps:QueryMetrics"
      ],
      "Resource": "*"
    }
  ]
}
```

## Deployment

The Lambda is deployed via Terraform. See `terraform/environments/prod/monitoring/alert-enrichment.tf`.

### Building the Deployment Package

```bash
cd lambda/alert-enrichment
zip -r ../alert-enrichment.zip .
```

Or use the Terraform `archive_file` data source for automatic packaging.

## Slack Message Format

### Critical Alert Example

```
🚨 [CRITICAL] Gateway High Error Rate

📊 현재 상태
├─ Error Rate: 7.5% (임계값: 5%)
├─ 영향 시간: 2024-01-15 14:32 KST ~ 현재 (3분 경과)
└─ 영향 범위: 전체 트래픽

🔍 원인 분석 (자동 수집)
├─ 에러 집중 라우트: authhub (89%), commerce (11%)
├─ 주요 에러 코드: 503 Service Unavailable (92%)
├─ 최근 로그: "Connection refused to authhub-web-api-prod"
└─ 연관 알람: AuthHub Instance Down (14:30 발생)

📋 최근 변경사항
├─ 14:25 - authhub-web-api 배포 (commit: a3f2d1)
└─ 14:20 - gateway 설정 변경 없음

🔗 바로가기
[대시보드] [로그] [Runbook]
```

## DynamoDB Runbook Table Schema

```
Table: connectly-alert-runbooks
Primary Key: alert_name (String)
Sort Key: service (String)

Attributes:
- runbook_url (String): URL to the runbook
- description (String): Brief description
- updated_at (Number): Last update timestamp
```

## Testing

### Local Testing

```python
# Test event
event = {
    "Records": [{
        "EventSource": "aws:sns",
        "Sns": {
            "Message": json.dumps({
                "alertname": "HighErrorRate",
                "severity": "critical",
                "labels": {"service": "gateway"},
                "annotations": {"description": "Error rate > 5%"}
            })
        }
    }]
}
```

### Invoke via AWS CLI

```bash
aws lambda invoke \
  --function-name connectly-alert-enrichment \
  --payload '{"test": true}' \
  response.json
```
