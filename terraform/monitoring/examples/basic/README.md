# Monitoring Basic Example

Amazon Managed Prometheus (AMP) 및 Grafana (AMG) 기반 모니터링 스택 예제입니다.

## 개요

이 예제에서는 다음 리소스를 생성합니다:

- **AMP Workspace**: Prometheus 메트릭 저장소
- **AMG Workspace**: Grafana 대시보드
- **ADOT Collector**: ECS에서 메트릭 수집
- **CloudWatch Alarms**: 핵심 메트릭 알람
- **SNS Topic**: 알람 알림

## 아키텍처

```
Application (ECS)
  ↓ (metrics)
ADOT Collector (ECS Sidecar)
  ↓ (remote write)
Amazon Managed Prometheus (AMP)
  ↓ (query)
Amazon Managed Grafana (AMG)
  ↓ (alerts)
SNS → Slack/Email
```

## 사용 방법

### terraform.tfvars

```hcl
environment = "dev"
aws_region  = "ap-northeast-2"

# AMP 설정
amp_alias = "dev-monitoring"

# AMG 설정
grafana_version        = "9.4"
grafana_authentication = "SAML"  # 또는 "AWS_SSO"

# 알람 설정
alarm_email = "team@example.com"
alarm_slack_webhook_url = "https://hooks.slack.com/services/..."

# ADOT Collector CPU/Memory
adot_cpu    = "256"
adot_memory = "512"
```

### 배포

```bash
terraform init
terraform plan
terraform apply
```

## 메트릭 수집 설정

### ECS Task에 ADOT Collector 추가

```hcl
container_definitions = jsonencode([
  {
    name  = "app"
    image = "your-app:latest"
    # ... app configuration
  },
  {
    name  = "aws-otel-collector"
    image = "public.ecr.aws/aws-observability/aws-otel-collector:latest"

    environment = [
      {
        name  = "AOT_CONFIG_CONTENT"
        value = file("otel-config.yaml")
      }
    ]
  }
])
```

### ADOT Config (otel-config.yaml)

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'app-metrics'
          scrape_interval: 30s
          static_configs:
            - targets: ['localhost:8080']

exporters:
  prometheusremotewrite:
    endpoint: ${AMP_ENDPOINT}/api/v1/remote_write
    auth:
      authenticator: sigv4auth

service:
  pipelines:
    metrics:
      receivers: [prometheus]
      exporters: [prometheusremotewrite]
```

## Grafana 대시보드 설정

### AMG 접속

1. AWS Console → Amazon Managed Grafana
2. Workspace URL 확인: `https://g-xxx.grafana-workspace.ap-northeast-2.amazonaws.com`
3. SAML/SSO로 로그인

### AMP 데이터소스 추가

Grafana에서:
1. Configuration → Data Sources
2. Add data source → Prometheus
3. URL: `${AMP_ENDPOINT}`
4. Auth: SigV4

### 대시보드 임포트

```bash
# Grafana UI에서 Import
Dashboard ID: 3119  # Kubernetes/Container Monitoring
```

## CloudWatch Alarms

자동 생성되는 알람:

### Application Alarms
- **High CPU**: ECS Task CPU > 80%
- **High Memory**: ECS Task Memory > 85%
- **5xx Errors**: ALB 5xx > 1%
- **High Latency**: ALB Target Response Time > 1s

### Infrastructure Alarms
- **AMP Metrics Delay**: 메트릭 수집 지연 > 5분
- **ADOT Collector Down**: Collector unhealthy

## 비용 예상

서울 리전 기준 월 비용:

| 항목 | 사양 | 비용 (USD) |
|------|------|------------|
| AMP | 메트릭 저장 | ~$10 (1천만 샘플 기준) |
| AMG | Workspace | ~$9 (Editor 1명) |
| CloudWatch Alarms | 10개 | ~$1 |
| SNS | 알림 | ~$0.5 |
| ADOT Collector | ECS 0.25 vCPU | ~$5 |
| **총 예상** | | **~$26** |

## 메트릭 쿼리 예시

### PromQL Queries

```promql
# CPU 사용률
100 * (1 - avg(rate(container_cpu_usage_seconds_total[5m])))

# 메모리 사용률
100 * container_memory_working_set_bytes / container_spec_memory_limit_bytes

# 요청 비율
rate(http_requests_total[5m])

# 에러율
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])

# P95 레이턴시
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

## Slack 알림 설정

### SNS → Slack Webhook

1. Slack에서 Incoming Webhook 생성
2. Lambda Function으로 SNS → Slack 변환

```python
# Lambda function
import json
import urllib3

def lambda_handler(event, context):
    message = event['Records'][0]['Sns']['Message']

    slack_message = {
        'text': f"🚨 Alarm: {message}"
    }

    http = urllib3.PoolManager()
    response = http.request('POST',
        os.environ['SLACK_WEBHOOK_URL'],
        body=json.dumps(slack_message),
        headers={'Content-Type': 'application/json'})
```

## Outputs

```bash
terraform output amp_workspace_id
terraform output amp_endpoint
terraform output grafana_workspace_url
terraform output sns_topic_arn
```

## 모니터링 Best Practices

### 1. 메트릭 수집
- 30초 스크랩 간격 권장
- 불필요한 메트릭 필터링 (비용 절감)
- 고카디널리티 라벨 제한

### 2. 대시보드
- 서비스별 대시보드 분리
- Golden Signals 우선 표시 (Latency, Traffic, Errors, Saturation)
- 시간 범위 선택 기능 추가

### 3. 알람
- 임계값은 히스토리 기반 설정
- False Positive 최소화
- 액션 가능한 알람만 설정

## 정리

```bash
terraform destroy
```

## 참고 자료

- [Monitoring 패키지 문서](../../README.md)
- [AMP 문서](https://docs.aws.amazon.com/prometheus/)
- [AMG 문서](https://docs.aws.amazon.com/grafana/)
- [ADOT 문서](https://aws-otel.github.io/)
