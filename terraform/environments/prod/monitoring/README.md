# Prod Monitoring Stack

AWS 인프라의 중앙 집중식 모니터링 시스템입니다. Amazon Managed Prometheus (AMP), Amazon Managed Grafana (AMG), CloudWatch를 통합하여 메트릭 수집, 시각화, 알림 기능을 제공합니다.

## 개요

이 스택은 다음과 같은 모니터링 인프라를 구성합니다:

- **메트릭 수집 및 저장**: Amazon Managed Prometheus (AMP)
- **메트릭 시각화**: Amazon Managed Grafana (AMG)
- **알림 시스템**: SNS 기반 3단계 알림 (Critical, Warning, Info)
- **Slack 통합**: AWS Chatbot을 통한 실시간 알림
- **IAM 역할**: 서비스 간 안전한 통합을 위한 최소 권한 원칙 기반 역할

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring System                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  [ECS Tasks] ──ADOT──> [AMP Workspace]                      │
│                           │                                   │
│                           │ Query                            │
│                           ▼                                   │
│                    [AMG Workspace]                           │
│                           │                                   │
│  [CloudWatch]────────────┘                                   │
│      │                                                        │
│      │ Alarms                                                │
│      ▼                                                        │
│  [SNS Topics] ──> [AWS Chatbot] ──> [Slack]                 │
│   - Critical                                                 │
│   - Warning                                                  │
│   - Info                                                     │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 사용된 모듈

### SNS 모듈 (v1.0.0)

3개의 심각도 레벨별 SNS 토픽 생성:

```hcl
# Critical 알림 토픽
module "sns_critical" {
  source = "../../../modules/sns"

  name         = "prod-monitoring-critical"
  display_name = "Critical Alerts - prod"
  kms_key_id   = aws_kms_key.monitoring.id

  # CloudWatch 알림 발행 허용
  topic_policy = jsonencode({ ... })

  # 필수 태그
  environment = "prod"
  service     = "monitoring"
  team        = "platform-team"
  # ...
}

# Warning, Info 토픽도 동일한 패턴
```

**심각도 레벨**:
- **Critical** (P0): 즉각 대응 필요 (예: 전체 서비스 다운, 메모리 95% 초과)
- **Warning** (P1): 30분 이내 확인 필요 (예: CPU 80% 지속, 메모리 80% 초과)
- **Info** (P2): 모니터링 및 분석 목적 (예: 알림 해제, 정상 상태 복구)

### IAM Role Policy 모듈 (v1.0.0)

4개의 IAM 역할 생성:

#### 1. ECS AMP Writer Role
ECS 태스크가 AMP에 메트릭을 전송하기 위한 역할:

```hcl
module "iam_ecs_amp_writer" {
  source = "../../../modules/iam-role-policy"

  role_name = "prod-monitoring-ecs-amp-writer"

  # ECS 태스크 신뢰 정책
  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  # 커스텀 인라인 정책
  custom_inline_policies = {
    amp-remote-write = {
      # AMP 메트릭 작성 권한
      policy = jsonencode({ ... })
    }
    adot-ecs-metrics = {
      # ADOT Collector가 ECS 메타데이터 수집
      policy = jsonencode({ ... })
    }
  }
}
```

**주요 권한**:
- AMP 메트릭 작성 (`aps:RemoteWrite`, `aps:GetSeries`)
- ECS 태스크 조회 (클러스터 조건부)
- CloudWatch 메트릭 발행 (ECS/ContainerInsights 네임스페이스)

#### 2. Grafana AMP Reader Role
Grafana가 AMP 데이터를 조회하기 위한 역할:

```hcl
module "iam_grafana_amp_reader" {
  source = "../../../modules/iam-role-policy"

  role_name = "prod-monitoring-grafana-amp-reader"

  # Grafana 서비스 신뢰 정책
  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { Service = "grafana.amazonaws.com" }
      Condition = {
        StringEquals = { "aws:SourceAccount" = "..." }
      }
    }]
  })

  custom_inline_policies = {
    amp-query = {
      # AMP 쿼리 권한
    }
    cloudwatch-read = {
      # CloudWatch 메트릭 및 로그 읽기
    }
  }
}
```

**주요 권한**:
- AMP 쿼리 (`aps:QueryMetrics`, `aps:GetLabels`)
- CloudWatch 메트릭 조회 (AWS/ECS, AWS/RDS, AWS/ApplicationELB)
- CloudWatch Logs 쿼리 (`/aws/ecs/*`, `/aws/rds/*`, `/aws/lambda/*`)
- EC2 태그 조회 (리소스 메타데이터)

#### 3. Grafana Workspace Role
Grafana 워크스페이스 자체를 위한 기본 역할:

```hcl
module "iam_grafana_workspace" {
  source = "../../../modules/iam-role-policy"

  role_name = "prod-monitoring-grafana-workspace-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { Service = "grafana.amazonaws.com" }
    }]
  })

  # 기본 역할 - 추가 정책은 AMG 콘솔에서 관리
}
```

#### 4. Chatbot Role
AWS Chatbot이 Slack으로 알림을 전송하기 위한 역할:

```hcl
module "iam_chatbot" {
  source = "../../../modules/iam-role-policy"

  role_name = "prod-monitoring-chatbot-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Principal = { Service = "chatbot.amazonaws.com" }
    }]
  })

  custom_inline_policies = {
    cloudwatch-read = {
      # CloudWatch 메트릭 및 로그 읽기 (Slack 메시지 컨텍스트용)
      policy = jsonencode({ ... })
    }
  }
}
```

**주요 권한**:
- CloudWatch 알림 읽기 (`cloudwatch:Describe*`, `cloudwatch:Get*`)
- CloudWatch Logs 조회 (로그 컨텍스트 제공)

## 주요 리소스

### Amazon Managed Prometheus (AMP)
- **Workspace**: `prod-monitoring-infrastructure-metrics`
- **용도**: Prometheus 메트릭 중앙 저장소
- **데이터 소스**: ADOT Collector (ECS sidecar)
- **보안**: KMS 암호화, IAM 기반 인증

### Amazon Managed Grafana (AMG)
- **Workspace**: `prod-monitoring-infrastructure-observability`
- **인증**: AWS SSO
- **데이터 소스**: AMP, CloudWatch
- **권한 관리**: SERVICE_MANAGED

### CloudWatch 알림

현재 활성화된 알림 (ECS):

| 알림 이름 | 심각도 | 조건 | 평가 주기 |
|----------|--------|------|----------|
| ECS Task Count Zero | Critical | DesiredTaskCount ≤ 0 | 1분 |
| ECS High Memory Critical | Critical | MemoryUtilization > 95% | 5분 |
| ECS High CPU Warning | Warning | CPUUtilization > 80% (10분) | 5분 × 2 |
| ECS High Memory Warning | Warning | MemoryUtilization > 80% (10분) | 5분 × 2 |

향후 추가 예정:
- **RDS 알림**: Connection Failed, High CPU, High Latency, Low Memory
- **ALB 알림**: High 5xx Rate, No Healthy Targets, High Response Time, Elevated 4xx

### KMS 암호화
- **키**: `prod-monitoring-key`
- **암호화 대상**: CloudWatch Logs, SNS 토픽
- **Key Rotation**: 활성화 (자동 1년 주기)
- **삭제 유예**: 30일

## 배포 방법

### 1. 사전 준비

```bash
# Terraform 초기화
cd terraform/environments/prod/monitoring
terraform init

# Atlantis ECS 클러스터 상태 확인 (원격 상태 의존성)
terraform state list -state=s3://prod-tfstate/atlantis/terraform.tfstate
```

### 2. Slack 통합 설정 (선택사항)

AWS Chatbot을 활성화하려면:

```bash
# 1. Slack Workspace에서 AWS Chatbot 앱 설치
# https://slack.com/apps/A6L22LZNH-aws-chatbot

# 2. Workspace ID 및 Channel ID 확인
# Workspace ID: Slack 설정 > 워크스페이스 이름 클릭 > About에서 확인
# Channel ID: 채널 우클릭 > 채널 세부정보 > 하단에서 확인

# 3. terraform.tfvars 설정
cat <<EOF > terraform.tfvars
enable_chatbot     = true
slack_workspace_id = "T01234ABCDE"
slack_channel_id   = "C05678FGHIJ"
EOF
```

### 3. 배포 실행

```bash
# 변경 사항 미리보기
terraform plan

# 배포
terraform apply

# 출력값 확인
terraform output
```

### 4. Grafana 워크스페이스 설정

배포 후 AMG 콘솔에서 추가 설정:

```bash
# 1. AMG Console 접속
echo "https://console.aws.amazon.com/grafana/home?region=ap-northeast-2#/workspaces"

# 2. Data Source 추가
# - Prometheus: AMP workspace 연결 (IAM role 자동 설정됨)
# - CloudWatch: Region 선택, IAM role 자동 설정됨

# 3. 사용자 또는 그룹 추가 (AWS SSO)
# - Admin, Editor, Viewer 역할 할당

# 4. 대시보드 가져오기 (선택사항)
# - ECS Container Insights
# - RDS Performance Insights
```

## 설정 변수

### 필수 태그 변수

```hcl
environment = "prod"
service     = "monitoring"
team        = "platform-team"
owner       = "platform-team"
cost_center = "engineering"
```

### AMP 설정

```hcl
amp_workspace_alias  = "infrastructure-metrics"
amp_retention_period = 150  # 일
amp_enable_logging   = true
```

### AMG 설정

```hcl
amg_workspace_name           = "infrastructure-observability"
amg_account_access_type      = "CURRENT_ACCOUNT"
amg_authentication_providers = ["AWS_SSO"]
amg_permission_type          = "SERVICE_MANAGED"
amg_data_sources            = ["PROMETHEUS", "CLOUDWATCH"]
```

### 알림 설정

```hcl
enable_ecs_alarms            = true
enable_rds_alarms            = false  # RDS 배포 시 true
enable_alb_alarms            = false  # ALB 배포 시 true
enable_critical_email_alerts = false
critical_alert_email         = ""
enable_chatbot               = false  # Slack 설정 후 true
```

## 출력 값

```hcl
# AMP
amp_workspace_id       = "ws-abc12345-1234-5678-abcd-123456789012"
amp_workspace_endpoint = "https://aps-workspaces.ap-northeast-2.amazonaws.com/workspaces/ws-..."

# AMG
amg_workspace_id       = "g-abc12345"
amg_workspace_endpoint = "https://g-abc12345.grafana-workspace.ap-northeast-2.amazonaws.com"

# SNS Topics
sns_critical_arn = "arn:aws:sns:ap-northeast-2:...:prod-monitoring-critical"
sns_warning_arn  = "arn:aws:sns:ap-northeast-2:...:prod-monitoring-warning"
sns_info_arn     = "arn:aws:sns:ap-northeast-2:...:prod-monitoring-info"

# IAM Roles
iam_ecs_amp_writer_arn     = "arn:aws:iam::...:role/prod-monitoring-ecs-amp-writer"
iam_grafana_amp_reader_arn = "arn:aws:iam::...:role/prod-monitoring-grafana-amp-reader"
iam_grafana_workspace_arn  = "arn:aws:iam::...:role/prod-monitoring-grafana-workspace-role"
iam_chatbot_arn            = "arn:aws:iam::...:role/prod-monitoring-chatbot-role"
```

## 모니터링 통합 가이드

### ECS 서비스에 ADOT Collector 추가

```hcl
# ECS Task Definition에 ADOT sidecar 추가
resource "aws_ecs_task_definition" "app" {
  family             = "app-service"
  task_role_arn      = module.iam_ecs_amp_writer.role_arn  # AMP 쓰기 권한
  execution_role_arn = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name  = "app"
      image = "app:latest"
      # ... app container config
    },
    {
      name  = "adot-collector"
      image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.42.0"

      environment = [
        {
          name  = "AWS_PROMETHEUS_ENDPOINT"
          value = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
        }
      ]

      # ADOT config는 adot-ecs-integration.tf 참조
    }
  ])
}
```

### CloudWatch 알림 커스터마이징

```hcl
# 커스텀 알림 추가 예시
resource "aws_cloudwatch_metric_alarm" "custom_alarm" {
  alarm_name          = "prod-monitoring-custom-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ErrorCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 100

  alarm_description = "ALB error count exceeds threshold"

  # 심각도에 따라 적절한 SNS 토픽 선택
  alarm_actions = [module.sns_warning.topic_arn]
  ok_actions    = [module.sns_info.topic_arn]

  tags = merge(
    local.required_tags,
    {
      Component = "alerting"
      Severity  = "warning"
    }
  )
}
```

## 보안 고려사항

### 최소 권한 원칙
- 각 IAM 역할은 필요한 최소한의 권한만 부여
- 리소스 ARN 기반 권한 제한 (와일드카드 최소화)
- 조건부 정책 활용 (ECS 클러스터, CloudWatch 네임스페이스)

### 데이터 암호화
- **At-rest**: KMS 고객 관리형 키로 CloudWatch Logs, SNS 암호화
- **In-transit**: HTTPS/TLS를 통한 메트릭 전송 (AMP, AMG)

### 네트워크 보안
- AMG 워크스페이스: VPC 엔드포인트 지원 (선택사항)
- AMP: AWS PrivateLink 지원

### 감사 및 모니터링
- CloudTrail을 통한 API 호출 로깅
- IAM Access Analyzer로 외부 접근 검증

## 트러블슈팅

### AMP 메트릭이 수집되지 않음

```bash
# ADOT Collector 로그 확인
aws logs tail /aws/ecs/adot-collector --follow

# ECS 태스크 IAM 역할 확인
aws iam get-role --role-name prod-monitoring-ecs-amp-writer

# AMP 워크스페이스 상태 확인
aws amp describe-workspace --workspace-id ws-abc12345...
```

### Grafana 데이터 소스 연결 실패

```bash
# Grafana IAM 역할 권한 확인
aws iam get-role-policy --role-name prod-monitoring-grafana-amp-reader --policy-name amp-query

# AMP 엔드포인트 확인
terraform output amp_workspace_endpoint

# Grafana 워크스페이스 상태 확인
aws grafana describe-workspace --workspace-id g-abc12345
```

### CloudWatch 알림이 발송되지 않음

```bash
# SNS 토픽 구독 확인
aws sns list-subscriptions-by-topic --topic-arn arn:aws:sns:...

# CloudWatch 알림 히스토리 확인
aws cloudwatch describe-alarm-history --alarm-name prod-monitoring-ecs-task-count-zero

# SNS 토픽 정책 확인 (CloudWatch 발행 권한)
aws sns get-topic-attributes --topic-arn arn:aws:sns:...
```

### AWS Chatbot Slack 메시지 수신 안됨

```bash
# Chatbot 설정 확인
aws chatbot describe-slack-channel-configurations

# SNS 토픽 구독 확인
aws sns list-subscriptions --output table | grep chatbot

# Chatbot IAM 역할 권한 확인
aws iam get-role-policy --role-name prod-monitoring-chatbot-role --policy-name cloudwatch-read
```

## 비용 최적화

### AMP 비용
- **메트릭 수집**: $0.30 per million samples ingested
- **메트릭 저장**: $0.03 per GB-month
- **쿼리**: $0.01 per million samples scanned
- **최적화**: 불필요한 메트릭 필터링, 적절한 scrape interval 설정

### AMG 비용
- **Active Editor/Admin**: $9.00 per user-month
- **Active Viewer**: $5.00 per user-month
- **최적화**: 필요한 사용자만 Editor/Admin 권한 부여

### CloudWatch 비용
- **Metrics**: $0.30 per metric per month (first 10,000 free)
- **Alarms**: $0.10 per alarm per month (first 10 free)
- **Logs**: $0.50 per GB ingested
- **최적화**: 로그 보존 기간 단축 (7일), 불필요한 알림 비활성화

## 관련 문서

- [모듈: SNS](../../../modules/sns/README.md)
- [모듈: IAM Role Policy](../../../modules/iam-role-policy/README.md)
- [Governance: 태깅 표준](../../../../docs/governance/TAGGING_STANDARD.md)
- [Governance: KMS 암호화 전략](../../../../docs/governance/KMS_ENCRYPTION.md)
- [AWS AMP 공식 문서](https://docs.aws.amazon.com/prometheus/)
- [AWS AMG 공식 문서](https://docs.aws.amazon.com/grafana/)
- [ADOT Collector 설정 가이드](https://aws-otel.github.io/docs/introduction)

## 변경 이력

### v1.0.0 (Initial Release)
- AMP 워크스페이스 생성
- AMG 워크스페이스 생성
- 3단계 SNS 알림 시스템 (Critical, Warning, Info)
- 4개 IAM 역할 (ECS AMP Writer, Grafana AMP Reader, Grafana Workspace, Chatbot)
- ECS CloudWatch 알림 (Task Count, CPU, Memory)
- AWS Chatbot Slack 통합 지원
- KMS 암호화 (CloudWatch Logs, SNS)

## 라이선스

이 스택은 내부 인프라 관리 목적으로 사용됩니다.

## 지원

문제 또는 질문이 있는 경우:
- **Slack**: #platform-team
- **Owner**: platform-team
- **Email**: platform@example.com
