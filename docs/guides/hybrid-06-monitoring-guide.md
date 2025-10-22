# 하이브리드 Terraform 인프라: 모니터링 가이드

**작성일**: 2025-10-22
**버전**: 1.0
**대상 독자**: SRE, 운영팀, 모니터링 담당자
**소요 시간**: 30분
**선행 문서**: [배포 가이드](hybrid-05-deployment-guide.md)

---

## 📋 목차

1. [개요](#개요)
2. [CloudWatch Logs 통합](#cloudwatch-logs-통합)
3. [X-Ray 트레이싱 설정](#x-ray-트레이싱-설정)
4. [Application Insights 설정](#application-insights-설정)
5. [메트릭 및 알람 설정](#메트릭-및-알람-설정)
6. [로그 집계 및 분석](#로그-집계-및-분석)
7. [중앙 집중식 모니터링](#중앙-집중식-모니터링)
8. [대시보드 구성](#대시보드-구성)
9. [알람 대응 프로세스](#알람-대응-프로세스)
10. [다음 단계](#다음-단계)

---

## 개요

이 가이드는 **하이브리드 인프라 구조의 모니터링 및 로깅**을 다룹니다. CloudWatch, X-Ray, Application Insights를 활용한 통합 모니터링 전략을 설명합니다.

### 모니터링 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │   ECS    │  │  Lambda  │  │   API    │             │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘             │
└───────┼─────────────┼─────────────┼────────────────────┘
        │             │             │
        ▼             ▼             ▼
┌─────────────────────────────────────────────────────────┐
│              CloudWatch Observability                    │
│  ┌──────────────┐  ┌────────────┐  ┌────────────────┐ │
│  │     Logs     │  │  Metrics   │  │   Alarms       │ │
│  │   + Insights │  │  + X-Ray   │  │   + SNS        │ │
│  └──────────────┘  └────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────┘
        │                                      │
        ▼                                      ▼
┌─────────────────┐                  ┌─────────────────┐
│  S3 Archival    │                  │  Slack / Email  │
│  (Long-term)    │                  │  Notifications  │
└─────────────────┘                  └─────────────────┘
```

### 모니터링 레이어

1. **로그 레이어**: CloudWatch Logs + Insights
2. **메트릭 레이어**: CloudWatch Metrics + Custom Metrics
3. **트레이싱 레이어**: X-Ray
4. **알람 레이어**: CloudWatch Alarms + SNS
5. **분석 레이어**: Application Insights

---

## CloudWatch Logs 통합

### Log Group 구조

```
/ecs/[service]-[env]/application       # 애플리케이션 로그
/ecs/[service]-[env]/access           # 액세스 로그 (ALB)
/ecs/[service]-[env]/error            # 에러 로그
/aws/lambda/[service]-[env]           # Lambda 로그 (있는 경우)
/aws/rds/[service]/queries            # 데이터베이스 쿼리 로그
```

### Terraform 설정

**파일**: `infrastructure/terraform/cloudwatch-logs.tf`

```hcl
# ============================================================================
# CloudWatch Log Groups
# ============================================================================

# Application Log Group
resource "aws_cloudwatch_log_group" "application" {
  name              = "/ecs/${var.service_name}-${var.environment}/application"
  retention_in_days = var.environment == "prod" ? 14 : 7
  kms_key_id        = local.cloudwatch_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-app-logs"
      Component = "logging"
    }
  )
}

# Error Log Group (장기 보관)
resource "aws_cloudwatch_log_group" "error" {
  name              = "/ecs/${var.service_name}-${var.environment}/error"
  retention_in_days = var.environment == "prod" ? 30 : 14
  kms_key_id        = local.cloudwatch_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-error-logs"
      Component = "logging"
    }
  )
}

# Access Log Group (ALB)
resource "aws_cloudwatch_log_group" "access" {
  name              = "/ecs/${var.service_name}-${var.environment}/access"
  retention_in_days = var.environment == "prod" ? 7 : 3
  kms_key_id        = local.cloudwatch_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-access-logs"
      Component = "logging"
    }
  )
}

# Database Query Log Group (Optional)
resource "aws_cloudwatch_log_group" "database_queries" {
  count             = var.shared_rds_identifier != "" ? 1 : 0
  name              = "/aws/rds/${var.service_name}/queries"
  retention_in_days = 7
  kms_key_id        = local.cloudwatch_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-db-queries"
      Component = "logging"
    }
  )
}
```

### ECS Task Definition 로그 설정

```hcl
# ecs.tf
container_definitions = jsonencode([
  {
    name      = "${var.service_name}-app"
    image     = "${local.ecr_repository_url}:${var.image_tag}"
    essential = true

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.application.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    # 환경별 로그 레벨 설정
    environment = [
      {
        name  = "LOG_LEVEL"
        value = var.environment == "prod" ? "INFO" : "DEBUG"
      }
    ]
  }
])
```

### 로그 확인 명령어

```bash
# 실시간 로그 확인
aws logs tail \
  /ecs/${SERVICE_NAME}-${ENV}/application \
  --follow \
  --region ap-northeast-2

# 최근 1시간 에러 로그
aws logs filter-log-events \
  --log-group-name /ecs/${SERVICE_NAME}-${ENV}/error \
  --start-time $(date -u -d '1 hour ago' +%s)000 \
  --region ap-northeast-2

# 특정 패턴 필터링
aws logs filter-log-events \
  --log-group-name /ecs/${SERVICE_NAME}-${ENV}/application \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '5 minutes ago' +%s)000 \
  --region ap-northeast-2
```

---

## X-Ray 트레이싱 설정

### ECS Task Definition에 X-Ray 컨테이너 추가

**파일**: `infrastructure/terraform/ecs.tf`

```hcl
resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name_prefix}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.service_name}-app"
      image     = "${local.ecr_repository_url}:${var.image_tag}"
      essential = true

      environment = [
        {
          name  = "AWS_XRAY_DAEMON_ADDRESS"
          value = "xray-daemon:2000"
        },
        {
          name  = "AWS_XRAY_TRACING_NAME"
          value = "${var.service_name}-${var.environment}"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.application.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      portMappings = [
        {
          containerPort = var.ecs_container_port
          protocol      = "tcp"
        }
      ]
    },
    {
      name      = "xray-daemon"
      image     = "amazon/aws-xray-daemon:latest"
      essential = false
      cpu       = 32
      memory    = 256

      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.application.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "xray"
        }
      }
    }
  ])
}
```

### IAM 권한 추가

```hcl
# iam.tf - ECS Task Role에 X-Ray 권한 추가
resource "aws_iam_policy" "xray_access" {
  name_prefix = "${local.name_prefix}-xray-access-"
  description = "Policy for X-Ray tracing"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-xray-access"
      Component = "iam"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_xray" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.xray_access.arn
}
```

### X-Ray 트레이스 확인

```bash
# X-Ray 트레이스 조회
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression 'service("${SERVICE_NAME}-${ENV}")' \
  --region ap-northeast-2

# 특정 트레이스 상세 조회
aws xray get-trace-graph \
  --trace-ids <trace-id> \
  --region ap-northeast-2
```

---

## Application Insights 설정

### Resource Group 생성

**파일**: `infrastructure/terraform/application-insights.tf`

```hcl
# ============================================================================
# Application Insights Configuration
# ============================================================================

resource "aws_resourcegroups_group" "app" {
  name = "${local.name_prefix}-resources"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = [
        "AWS::ECS::Service",
        "AWS::RDS::DBInstance",
        "AWS::ElastiCache::ReplicationGroup",
        "AWS::ElasticLoadBalancingV2::LoadBalancer",
        "AWS::SQS::Queue",
        "AWS::S3::Bucket"
      ]
      TagFilters = [
        {
          Key    = "Service"
          Values = [var.service_name]
        },
        {
          Key    = "Environment"
          Values = [var.environment]
        }
      ]
    })
  }

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-resource-group"
      Component = "monitoring"
    }
  )
}

resource "aws_applicationinsights_application" "app" {
  resource_group_name = aws_resourcegroups_group.app.name
  auto_config_enabled = true
  auto_create         = true

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-insights"
      Component = "monitoring"
    }
  )
}
```

### Application Insights 확인

```bash
# Application Insights 상태 확인
aws application-insights describe-application \
  --resource-group-name ${SERVICE_NAME}-${ENV}-resources \
  --region ap-northeast-2

# 문제 감지 확인
aws application-insights list-problems \
  --resource-group-name ${SERVICE_NAME}-${ENV}-resources \
  --start-time $(date -u -d '1 day ago' +%s)000 \
  --end-time $(date -u +%s)000 \
  --region ap-northeast-2
```

---

## 메트릭 및 알람 설정

### 표준 메트릭 알람

**파일**: `infrastructure/terraform/cloudwatch-alarms.tf`

```hcl
# ============================================================================
# CloudWatch Alarms
# ============================================================================

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${local.name_prefix}-alerts"
  kms_master_key_id = local.secrets_key_arn

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-alerts"
      Component = "monitoring"
    }
  )
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ECS Service CPU Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300  # 5 minutes
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization is too high (>80%)"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = local.required_tags
}

# ECS Service Memory Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${local.name_prefix}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "ECS Memory utilization is too high (>85%)"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = local.required_tags
}

# ECS Task Count Zero (Critical)
resource "aws_cloudwatch_metric_alarm" "ecs_task_count_zero" {
  alarm_name          = "${local.name_prefix}-task-count-zero"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "CRITICAL: No running ECS tasks"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = local.required_tags
}

# ALB 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${local.name_prefix}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is returning too many 5xx errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.required_tags
}

# ALB Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_response_time_high" {
  alarm_name          = "${local.name_prefix}-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0  # 1 second
  alarm_description   = "ALB target response time is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.required_tags
}

# RDS CPU Utilization
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count               = var.shared_rds_identifier != "" ? 1 : 0
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.shared_rds_identifier
  }

  tags = local.required_tags
}

# Redis CPU Utilization
resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  alarm_name          = "${local.name_prefix}-redis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Redis CPU utilization is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.redis.id
  }

  tags = local.required_tags
}
```

### 알람 확인 명령어

```bash
# 모든 알람 상태 확인
aws cloudwatch describe-alarms \
  --alarm-name-prefix ${SERVICE_NAME}-${ENV} \
  --region ap-northeast-2 \
  --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' \
  --output table

# ALARM 상태인 알람만 확인
aws cloudwatch describe-alarms \
  --state-value ALARM \
  --alarm-name-prefix ${SERVICE_NAME}-${ENV} \
  --region ap-northeast-2
```

---

## 로그 집계 및 분석

### S3로 로그 Export

**스크립트**: `infrastructure/scripts/export-logs-to-s3.sh`

```bash
#!/bin/bash

# 설정
SERVICE_NAME="fileflow"
ENV="prod"
LOG_GROUP="/ecs/${SERVICE_NAME}-${ENV}/application"
BUCKET="${SERVICE_NAME}-${ENV}-logs-archive"
REGION="ap-northeast-2"

# 시간 범위 (최근 7일)
FROM_TIME=$(date -u -d '7 days ago' +%s)000
TO_TIME=$(date -u +%s)000

# S3 Prefix (날짜별 저장)
PREFIX="cloudwatch-logs/$(date -u +%Y/%m/%d)"

# Export Task 생성
echo "Exporting logs from $LOG_GROUP to s3://$BUCKET/$PREFIX"

TASK_ID=$(aws logs create-export-task \
  --log-group-name "$LOG_GROUP" \
  --from $FROM_TIME \
  --to $TO_TIME \
  --destination "$BUCKET" \
  --destination-prefix "$PREFIX" \
  --region $REGION \
  --query 'taskId' \
  --output text)

echo "Export task created: $TASK_ID"

# Task 상태 확인
aws logs describe-export-tasks \
  --task-id $TASK_ID \
  --region $REGION
```

### CloudWatch Insights 쿼리 예제

#### 최근 1시간 에러 로그

```
fields @timestamp, @message, level, error
| filter level = "ERROR"
| sort @timestamp desc
| limit 100
```

#### API 응답 시간 분석

```
fields @timestamp, method, path, responseTime
| filter @message like /API Request/
| stats avg(responseTime) as avg_response,
        max(responseTime) as max_response,
        min(responseTime) as min_response,
        pct(responseTime, 95) as p95_response
  by bin(5m)
```

#### 5xx 에러 패턴 분석

```
fields @timestamp, @message, statusCode, path, method
| filter statusCode >= 500 and statusCode < 600
| stats count() as error_count by statusCode, path
| sort error_count desc
```

#### 느린 SQL 쿼리 분석

```
fields @timestamp, query, duration
| filter @message like /SQL Query/ and duration > 1000
| sort duration desc
| limit 50
```

#### 사용자별 API 호출 통계

```
fields @timestamp, userId, path, method
| filter @message like /API Request/
| stats count() as request_count by userId, path
| sort request_count desc
| limit 20
```

### 로그 분석 자동화

**Lambda 함수**: 주기적으로 로그를 분석하여 이상 패턴 감지

```python
# lambda/log-analyzer/handler.py
import boto3
import json
from datetime import datetime, timedelta

logs_client = boto3.client('logs')
sns_client = boto3.client('sns')

def handler(event, context):
    log_group = "/ecs/fileflow-prod/application"

    # 최근 1시간 에러 로그 분석
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=1)

    query = """
    fields @timestamp, @message, level
    | filter level = "ERROR"
    | stats count() as error_count by bin(5m)
    """

    # CloudWatch Insights 쿼리 실행
    response = logs_client.start_query(
        logGroupName=log_group,
        startTime=int(start_time.timestamp()),
        endTime=int(end_time.timestamp()),
        queryString=query
    )

    query_id = response['queryId']

    # 결과 대기
    import time
    while True:
        result = logs_client.get_query_results(queryId=query_id)
        if result['status'] == 'Complete':
            break
        time.sleep(1)

    # 임계값 초과 시 알림
    for row in result['results']:
        error_count = int(row[0]['value'])
        if error_count > 100:
            sns_client.publish(
                TopicArn='arn:aws:sns:ap-northeast-2:ACCOUNT_ID:fileflow-prod-alerts',
                Subject='High Error Rate Detected',
                Message=f'Error count exceeded threshold: {error_count} errors in 5 minutes'
            )

    return {'statusCode': 200}
```

---

## 중앙 집중식 모니터링

### Amazon Managed Prometheus (AMP) + Grafana (AMG)

**옵션**: 고급 모니터링이 필요한 경우

#### AMP Workspace 생성

```hcl
# prometheus.tf
resource "aws_prometheus_workspace" "main" {
  alias = "${var.service_name}-${var.environment}"

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-prometheus"
      Component = "monitoring"
    }
  )
}
```

#### Grafana Workspace 생성

```hcl
# grafana.tf
resource "aws_grafana_workspace" "main" {
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  data_sources = ["PROMETHEUS", "CLOUDWATCH"]

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-grafana"
      Component = "monitoring"
    }
  )
}
```

---

## 대시보드 구성

### CloudWatch Dashboard

```hcl
# dashboard.tf
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            [".", "MemoryUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Performance"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", { stat = "Sum" }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Error Rates"
        }
      }
    ]
  })
}
```

---

## 알람 대응 프로세스

### 알람 심각도 분류

| 심각도 | 알람 | 대응 시간 | 대응자 |
|--------|------|----------|--------|
| **P0 - Critical** | Task Count Zero, RDS 다운 | 즉시 | On-Call Engineer |
| **P1 - High** | CPU/Memory > 85%, 5xx > 1% | 15분 이내 | Platform Team |
| **P2 - Medium** | CPU/Memory > 80%, Response Time > 1s | 1시간 이내 | Platform Team |
| **P3 - Low** | 기타 경고 | 업무 시간 내 | Platform Team |

### 알람 대응 체크리스트

```markdown
## P0 - Critical 대응

- [ ] Slack #incidents 채널에 알림
- [ ] On-Call Engineer 즉시 투입
- [ ] 현재 상태 확인 (ECS, RDS, ALB)
- [ ] 최근 배포 이력 확인
- [ ] 필요 시 Rollback 실행
- [ ] Root Cause 분석
- [ ] Post-mortem 문서 작성

## P1 - High 대응

- [ ] Slack #platform 채널에 알림
- [ ] 로그 확인 (CloudWatch Logs Insights)
- [ ] 메트릭 분석 (CPU, Memory, 5xx)
- [ ] 필요 시 스케일 아웃
- [ ] 15분 내 해결 안 되면 P0로 에스컬레이션
```

---

## 다음 단계

✅ **모니터링 가이드 완료**

**다음 가이드**: [운영 가이드 (hybrid-07-operations-guide.md)](hybrid-07-operations-guide.md)

**다음 단계 내용**:
1. Rollback 절차 (Terraform State, RDS, ECS)
2. 다중 리전 전략 (DR)
3. DR Failover 시나리오
4. 비용 예측 및 최적화
5. Infracost 통합
6. 환경별 예상 비용

---

## 참고 자료

### 관련 문서
- [배포 가이드](hybrid-05-deployment-guide.md)
- [운영 가이드](hybrid-07-operations-guide.md)
- [Runbooks](/docs/runbooks/)
- [Logs Insights Queries](/docs/guides/operations/LOGS_INSIGHTS_QUERIES.md)

### CloudWatch 문서
- [CloudWatch Logs Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [X-Ray Documentation](https://docs.aws.amazon.com/xray/)

---

**Last Updated**: 2025-10-22
**버전**: 1.0
