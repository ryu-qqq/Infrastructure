# 프로덕션 운영과 보안 관리 – Terraform (5)

## 🎯 프로덕션 인프라의 도전 과제

개발 환경에서는 잘 동작하던 인프라가 프로덕션에서는 다른 요구사항에 직면합니다:

```markdown
개발 환경:
- 빠른 실험과 반복
- 다운타임 허용
- 보안 요구사항 낮음
- 비용 최적화 낮은 우선순위

프로덕션 환경:
- 안정성과 가용성 최우선
- 무중단 배포 필수
- 엄격한 보안 요구사항
- 비용 효율성 중요
- 규제 준수 필요
- 감사 추적 필수
```

## 🔐 1. KMS 암호화 전략

### 문제: 모든 데이터를 하나의 키로 암호화

```hcl
# ❌ Bad Practice: 단일 KMS 키 사용
resource "aws_kms_key" "main" {
  description = "Main encryption key"
}

# 모든 리소스가 같은 키 사용
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn  # ← 같은 키
    }
  }
}

resource "aws_db_instance" "main" {
  kms_key_id = aws_kms_key.main.arn  # ← 같은 키
}

resource "aws_cloudwatch_log_group" "app" {
  kms_key_id = aws_kms_key.main.arn  # ← 같은 키
}
```

**문제점:**
- 🔴 한 키가 유출되면 모든 데이터 위험
- 🔴 세밀한 접근 제어 불가능
- 🔴 규제 준수 어려움 (데이터 클래스별 분리 요구)
- 🔴 키 교체 시 모든 데이터 재암호화 필요

### 해결: 데이터 클래스별 KMS 키 분리

```hcl
# ✅ Good Practice: 데이터 클래스별 키 분리
# terraform/kms/main.tf

# 1. RDS 데이터베이스 암호화 (Highly Confidential)
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS instance encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-encryption"
      DataClass = "highly-confidential"
      Component = "database"
    }
  )
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds-encryption"
  target_key_id = aws_kms_key.rds.key_id
}

# 2. Secrets Manager (Highly Confidential)
resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "secrets-encryption"
      DataClass = "highly-confidential"
      Component = "secrets"
    }
  )
}

# 3. S3 데이터 버킷 (Confidential)
resource "aws_kms_key" "s3_data" {
  description             = "KMS key for S3 data buckets"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "s3-data-encryption"
      DataClass = "confidential"
      Component = "storage"
    }
  )
}

# 4. CloudWatch Logs (Internal)
resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs"
  deletion_window_in_days = 7  # 로그는 짧은 삭제 기간
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "logs-encryption"
      DataClass = "internal"
      Component = "logging"
    }
  )
}

# 5. ECR 이미지 (Internal)
resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR repositories"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "ecr-encryption"
      DataClass = "internal"
      Component = "container-registry"
    }
  )
}

# 6. EFS (Confidential)
resource "aws_kms_key" "efs" {
  description             = "KMS key for EFS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "efs-encryption"
      DataClass = "confidential"
      Component = "file-storage"
    }
  )
}

# 7. SNS/SQS (Internal)
resource "aws_kms_key" "messaging" {
  description             = "KMS key for SNS and SQS"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "messaging-encryption"
      DataClass = "internal"
      Component = "messaging"
    }
  )
}

# 8. Terraform State (Highly Confidential)
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state files"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "terraform-state-encryption"
      DataClass = "highly-confidential"
      Component = "terraform"
    }
  )
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# 9. EBS 볼륨 (Confidential)
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS volume encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    local.required_tags,
    {
      Name      = "ebs-encryption"
      DataClass = "confidential"
      Component = "compute-storage"
    }
  )
}
```

### KMS 키 정책 (세밀한 접근 제어)

```hcl
# RDS KMS 키 정책 - DBA와 애플리케이션만 접근 가능
resource "aws_kms_key_policy" "rds" {
  key_id = aws_kms_key.rds.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow DBA team to manage the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/DBARole"
        }
        Action = [
          "kms:Describe*",
          "kms:List*",
          "kms:Get*"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### 사용 예시

```hcl
# terraform/database/main.tf
module "main_db" {
  source = "../../modules/rds"

  # RDS 전용 KMS 키 사용
  kms_key_id = data.aws_kms_key.rds.arn

  # ... 다른 설정
}

# terraform/services/api-server/logs.tf
module "app_logs" {
  source = "../../modules/cloudwatch-log-group"

  # Logs 전용 KMS 키 사용
  kms_key_id = data.aws_kms_key.logs.arn

  # ... 다른 설정
}
```

**장점:**
- ✅ 데이터 유출 시 영향 범위 제한
- ✅ 세밀한 접근 제어 (팀별, 서비스별)
- ✅ 규제 준수 용이 (데이터 클래스별 분리)
- ✅ 감사 추적 명확 (어떤 키가 어떤 데이터에 사용되는지)
- ✅ 키 교체 영향 최소화

## 🔑 2. Secrets Manager 운영 전략

### 문제: 하드코딩된 비밀번호

```hcl
# ❌ 절대 금지!
resource "aws_db_instance" "main" {
  username = "admin"
  password = "MyP@ssw0rd123"  # ← Git에 기록됨!
}
```

### 해결: Secrets Manager + 자동 교체

```hcl
# 1. Secrets Manager에 비밀번호 생성
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "rds/prod/master-password"
  description             = "Master password for production RDS"
  recovery_window_in_days = 30

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-master-password"
      Component = "database"
    }
  )
}

# 2. 랜덤 비밀번호 생성
resource "random_password" "db_master" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_master.result
  })
}

# 3. RDS에서 사용
resource "aws_db_instance" "main" {
  username = jsondecode(aws_secretsmanager_secret_version.db_password.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.db_password.secret_string)["password"]

  # ... 다른 설정
}

# 4. 자동 교체 설정 (90일마다)
resource "aws_secretsmanager_secret_rotation" "db_password" {
  secret_id           = aws_secretsmanager_secret.db_password.id
  rotation_lambda_arn = aws_lambda_function.rotate_db_password.arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

### Secrets 접근 제어

```hcl
# Lambda 함수만 Secrets Manager 접근 가능
resource "aws_iam_role_policy" "lambda_secrets" {
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn
        ]
      }
    ]
  })
}
```

## 📊 3. 모니터링 아키텍처

### 3계층 모니터링 전략

```
┌─────────────────────────────────────────────────────┐
│               1. CloudWatch (기본 메트릭)             │
│                                                      │
│  ├─ ECS: CPU, Memory, Network                       │
│  ├─ RDS: CPU, Connections, IOPS                     │
│  ├─ ALB: Request Count, Latency, 5xx               │
│  └─ Lambda: Invocations, Errors, Duration          │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│         2. Prometheus (커스텀 메트릭)                 │
│                                                      │
│  ├─ Application Metrics: API latency, throughput    │
│  ├─ Business Metrics: Orders, payments, users       │
│  └─ Custom Alerts: SLO violations                   │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│              3. Grafana (시각화)                      │
│                                                      │
│  ├─ Unified Dashboards                              │
│  ├─ Alert Management                                │
│  └─ SLO Tracking                                    │
└─────────────────────────────────────────────────────┘
```

### CloudWatch Alarms (Standard Metrics)

```hcl
# terraform/monitoring/cloudwatch-alarms.tf

# 1. ECS CPU 사용률 알람
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "api-server-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS CPU usage is above 80%"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.api.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "ecs-cpu-high"
      Severity  = "high"
      Component = "compute"
    }
  )
}

# 2. RDS 연결 수 알람
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"  # 최대 연결의 80%

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "rds-connections-high"
      Severity  = "critical"
      Component = "database"
    }
  )
}

# 3. ALB 5xx 에러 알람
resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "alb-5xx-errors-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"  # 1분에 10개 이상 5xx
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "alb-5xx-high"
      Severity  = "critical"
      Component = "loadbalancer"
    }
  )
}

# 4. Latency 알람 (P95)
resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "alb-latency-p95-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  extended_statistic  = "p95"  # 95 percentile
  threshold           = "1.0"  # 1초

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    local.required_tags,
    {
      Name      = "alb-latency-p95-high"
      Severity  = "medium"
      Component = "loadbalancer"
    }
  )
}
```

### SNS 알림 설정

```hcl
# SNS Topic (알람 수신)
resource "aws_sns_topic" "alerts" {
  name = "infrastructure-alerts-prod"
  kms_master_key_id = aws_kms_key.sns.id

  tags = local.required_tags
}

# Slack Webhook 구독
resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}

# PagerDuty 구독 (Critical만)
resource "aws_sns_topic_subscription" "pagerduty" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.pagerduty_endpoint

  filter_policy = jsonencode({
    severity = ["critical"]
  })
}
```

## 🚨 4. 장애 대응 전략

### Runbook 연결

```hcl
# CloudWatch Alarm에 Runbook 링크 추가
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  # ... 다른 설정

  alarm_description = <<-EOT
    ECS CPU usage is above 80%

    Runbook: https://wiki.company.com/runbooks/ecs-cpu-high

    Quick Actions:
    1. Check application logs for errors
    2. Review recent deployments
    3. Consider scaling up ECS tasks
    4. Check for resource-intensive queries
  EOT
}
```

### 롤백 절차

```bash
#!/bin/bash
# scripts/rollback.sh

set -e

ENVIRONMENT=$1
PREVIOUS_VERSION=$2

echo "🔄 Starting rollback for $ENVIRONMENT to version $PREVIOUS_VERSION"

# 1. Git에서 이전 버전 체크아웃
git checkout tags/$PREVIOUS_VERSION

# 2. Terraform plan 확인
cd terraform/services/api-server
terraform init
terraform plan -var="environment=$ENVIRONMENT" -out=rollback.tfplan

# 3. 리뷰어 확인 요청
echo "📋 Please review the rollback plan:"
terraform show rollback.tfplan
read -p "Continue with rollback? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "❌ Rollback cancelled"
  exit 1
fi

# 4. Apply 실행
terraform apply rollback.tfplan

# 5. 헬스체크
echo "🏥 Running health checks..."
for i in {1..30}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://api.example.com/health)
  if [ "$STATUS" = "200" ]; then
    echo "✅ Health check passed"
    break
  fi
  echo "⏳ Waiting for service to be healthy... ($i/30)"
  sleep 10
done

echo "✅ Rollback completed successfully"
```

### 재해 복구 (DR) 전략

```hcl
# terraform/disaster-recovery/main.tf

# 1. S3 Cross-Region Replication (DR)
resource "aws_s3_bucket_replication_configuration" "dr" {
  bucket = aws_s3_bucket.data.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-dr-region"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.data_dr.arn
      storage_class = "STANDARD_IA"

      # DR 리전에서도 암호화
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.s3_dr.arn
      }
    }
  }
}

# 2. RDS Automated Backup
resource "aws_db_instance" "main" {
  # ... 다른 설정

  backup_retention_period = 7  # 7일간 백업 보존
  backup_window          = "03:00-04:00"  # 새벽 3~4시

  # 자동 스냅샷을 DR 리전으로 복사
  copy_tags_to_snapshot = true
}

# 3. DR 리전용 KMS 키
resource "aws_kms_key" "s3_dr" {
  provider = aws.dr_region

  description             = "KMS key for S3 DR replication"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = local.required_tags
}
```

## 📋 5. 운영 체크리스트

### 일일 체크리스트

```markdown
## Daily Operations Checklist

### 모니터링 확인
- [ ] CloudWatch 대시보드 검토
  - [ ] 지난 24시간 알람 검토
  - [ ] CPU/Memory 사용률 트렌드 확인
  - [ ] 5xx 에러율 확인
- [ ] Grafana 대시보드 검토
  - [ ] SLO 달성률 확인
  - [ ] 비즈니스 메트릭 트렌드

### 보안 확인
- [ ] CloudTrail 로그 리뷰
  - [ ] 비정상적인 API 호출
  - [ ] 실패한 인증 시도
- [ ] GuardDuty 알람 검토

### 비용 확인
- [ ] Cost Explorer 검토
  - [ ] 예상 외 비용 증가
  - [ ] 리소스 사용 최적화 기회

### 백업 확인
- [ ] RDS 자동 백업 성공 확인
- [ ] S3 replication lag 확인
```

### 주간 체크리스트

```markdown
## Weekly Operations Checklist

### 보안 업데이트
- [ ] Secrets Manager 교체 일정 확인
- [ ] KMS 키 사용 현황 검토
- [ ] IAM Access Analyzer 권장사항 검토

### 성능 최적화
- [ ] RDS Performance Insights 검토
  - [ ] 느린 쿼리 분석
  - [ ] 인덱스 최적화 기회
- [ ] CloudWatch Insights 쿼리 분석

### 비용 최적화
- [ ] 미사용 리소스 정리
- [ ] Reserved Instance 사용률 검토
- [ ] Savings Plan 추천 검토

### 문서화
- [ ] Runbook 업데이트
- [ ] 아키텍처 다이어그램 최신화
- [ ] 장애 대응 기록 문서화
```

### 월간 체크리스트

```markdown
## Monthly Operations Checklist

### 재해 복구 테스트
- [ ] DR 리전에서 복구 테스트
- [ ] RDS 스냅샷 복원 테스트
- [ ] 백업 파일 무결성 검증

### 보안 감사
- [ ] IAM 정책 검토 및 정리
- [ ] Security Group 규칙 검토
- [ ] Secrets 교체 이력 확인

### 규제 준수
- [ ] 로그 보존 정책 준수 확인
- [ ] 암호화 정책 준수 확인
- [ ] 태그 정책 준수 확인

### 성능 리뷰
- [ ] 월간 성능 리포트 생성
- [ ] SLO 달성률 분석
- [ ] 개선 과제 도출
```

## 🎯 SLO (Service Level Objectives)

### SLO 정의 및 측정

```yaml
# SLO 정의
service_level_objectives:
  availability:
    target: 99.9%
    measurement: "uptime / total_time"
    window: "30 days"

  latency_p95:
    target: "< 500ms"
    measurement: "95th percentile response time"
    window: "7 days"

  error_rate:
    target: "< 0.1%"
    measurement: "5xx errors / total requests"
    window: "24 hours"

  data_durability:
    target: 99.999999999%  # 11 nines
    measurement: "S3 + RDS backup"
```

### Grafana 대시보드 설정

```hcl
# terraform/monitoring/grafana.tf
resource "grafana_dashboard" "slo" {
  config_json = jsonencode({
    title = "SLO Dashboard"
    panels = [
      {
        title = "Availability SLO"
        targets = [{
          expr = "sum(rate(http_requests_total{status!~'5..'}[30d])) / sum(rate(http_requests_total[30d]))"
        }]
        thresholds = {
          mode = "absolute"
          steps = [
            { value = 0.999, color = "green" },
            { value = 0.995, color = "yellow" },
            { value = 0,     color = "red" }
          ]
        }
      },
      {
        title = "P95 Latency SLO"
        targets = [{
          expr = "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[7d]))"
        }]
        thresholds = {
          steps = [
            { value = 0.5,  color = "green" },
            { value = 1.0,  color = "yellow" },
            { value = 2.0,  color = "red" }
          ]
        }
      }
    ]
  })
}
```

## 🚀 배포 전략

### Blue/Green 배포

```hcl
# terraform/services/api-server/blue-green.tf

# Blue 환경 (현재 프로덕션)
resource "aws_ecs_service" "api_blue" {
  name            = "api-server-blue"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_blue.arn
  desired_count   = 3

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "api-server"
    container_port   = 8080
  }
}

# Green 환경 (새 버전)
resource "aws_ecs_service" "api_green" {
  name            = "api-server-green"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_green.arn
  desired_count   = 0  # 처음에는 0

  load_balancer {
    target_group_arn = aws_lb_target_group.green.arn
    container_name   = "api-server"
    container_port   = 8080
  }
}

# ALB Listener Rule (트래픽 전환)
resource "aws_lb_listener_rule" "production" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = var.active_environment == "blue" ?
                       aws_lb_target_group.blue.arn :
                       aws_lb_target_group.green.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
```

### 배포 스크립트

```bash
#!/bin/bash
# scripts/deploy-blue-green.sh

set -e

CURRENT=$(aws elbv2 describe-rules --listener-arn $LISTENER_ARN | jq -r '.Rules[0].Actions[0].TargetGroupArn')

if [[ $CURRENT == *"blue"* ]]; then
  ACTIVE="blue"
  STANDBY="green"
else
  ACTIVE="green"
  STANDBY="blue"
fi

echo "📍 Current active: $ACTIVE"
echo "🚀 Deploying to: $STANDBY"

# 1. Green 환경에 새 버전 배포
aws ecs update-service \
  --cluster main \
  --service api-server-$STANDBY \
  --desired-count 3 \
  --task-definition api-server:$NEW_VERSION

# 2. 헬스체크 대기
echo "⏳ Waiting for healthy tasks..."
aws ecs wait services-stable \
  --cluster main \
  --services api-server-$STANDBY

# 3. Smoke 테스트
echo "🧪 Running smoke tests..."
./scripts/smoke-test.sh http://$STANDBY_TARGET_GROUP

# 4. 트래픽 전환 (10% → 50% → 100%)
echo "🔄 Switching traffic: 10%"
aws elbv2 modify-rule \
  --rule-arn $RULE_ARN \
  --actions Type=forward,ForwardConfig='{
    "TargetGroups":[
      {"TargetGroupArn":"'$BLUE_TG'","Weight":90},
      {"TargetGroupArn":"'$GREEN_TG'","Weight":10}
    ]
  }'
sleep 300

echo "🔄 Switching traffic: 50%"
aws elbv2 modify-rule --rule-arn $RULE_ARN --actions Type=forward,ForwardConfig='{
  "TargetGroups":[
    {"TargetGroupArn":"'$BLUE_TG'","Weight":50},
    {"TargetGroupArn":"'$GREEN_TG'","Weight":50}
  ]
}'
sleep 300

echo "🔄 Switching traffic: 100%"
aws elbv2 modify-rule --rule-arn $RULE_ARN --actions Type=forward,TargetGroupArn=$GREEN_TG

# 5. Blue 환경 스케일 다운
echo "📉 Scaling down old environment"
aws ecs update-service \
  --cluster main \
  --service api-server-$ACTIVE \
  --desired-count 0

echo "✅ Deployment completed successfully"
```

## 📚 요약

프로덕션 인프라 운영의 핵심 원칙:

1. **보안 최우선**
   - 데이터 클래스별 KMS 키 분리
   - Secrets Manager + 자동 교체
   - 최소 권한 원칙 (IAM)

2. **관찰 가능성**
   - 3계층 모니터링 (CloudWatch, Prometheus, Grafana)
   - Runbook 연결된 알람
   - SLO 추적 및 대시보드

3. **복원력**
   - 자동 백업 및 DR 전략
   - Blue/Green 배포
   - 빠른 롤백 절차

4. **지속적 개선**
   - 일일/주간/월간 체크리스트
   - 장애 대응 기록 문서화
   - 성능 최적화 사이클

## 📚 참고 자료

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [프로젝트의 KMS 설정](../../terraform/kms/)
- [프로젝트의 모니터링 가이드](../guides/atlantis-operations-guide.md)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)

---

**이전 글:** [PR 기반 자동화 파이프라인 구축 (4편)](./04-automated-validation-pipeline.md)

---

## 🎉 시리즈 완결

이제 AWS Console 클릭에서 벗어나 PR 기반의 안전하고 자동화된 인프라 관리 시스템을 구축하는 전체 여정을 완료했습니다!

**전체 시리즈:**
1. [AWS Console 클릭 대신 PR로 끝내는 루틴](./01-from-console-to-pr.md)
2. [PR에서 인프라 관리하기 - Atlantis](./02-atlantis-pr-automation.md)
3. [Terraform으로 인프라 코드화하기](./03-terraform-modules.md)
4. [PR 기반 자동화 파이프라인 구축](./04-automated-validation-pipeline.md)
5. [프로덕션 운영과 보안 관리](./05-production-operations-security.md) (현재)

Happy Infrastructure Coding! 🚀
