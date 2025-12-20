# 모니터링 시스템 구축 요청서

> Part 1: 알람 시스템 | Part 2: 로그 시스템 (OpenSearch)

---

# Part 1: 알람 시스템

## 1. 개요

### 목적
- 서비스 장애 발생 시 빠르고 디테일한 Slack 알람 전송
- 알람만 보고 원인 파악이 가능하도록 컨텍스트 자동 수집

### 적용 대상 서비스
| 서비스 | 클러스터 | Job Name |
|--------|----------|----------|
| Gateway | gateway-cluster-prod | gateway-metrics |
| AuthHub | authhub-cluster-prod | authhub-web-api-metrics |
| Commerce | setof-commerce-cluster-prod | setof-commerce-web-api-metrics, setof-commerce-admin-metrics |
| CrawlingHub | crawlinghub-cluster-prod | crawlinghub-web-api-metrics, crawlinghub-scheduler-metrics, crawlinghub-worker-metrics |
| FileFlow | fileflow-cluster-prod | fileflow-web-api-metrics, fileflow-scheduler-metrics, fileflow-worker-metrics, fileflow-resizing-worker-metrics |

---

## 2. 아키텍처

```
Grafana (AMG) → SNS Topic → Lambda (Enrichment) → Slack Webhook
                                │
                                ├─→ CloudWatch Logs (에러 로그 조회)
                                ├─→ X-Ray (트레이스 샘플)
                                ├─→ AMP (연관 메트릭 조회)
                                ├─→ ECS (최근 배포 정보)
                                └─→ DynamoDB (Runbook 매핑)
```

---

## 3. 필요 AWS 리소스

### 3.1 SNS Topic
```yaml
Name: connectly-alerts-prod
Purpose: Grafana 알람 수신 및 Lambda 트리거
```

### 3.2 Lambda Function
```yaml
Name: connectly-alert-enrichment
Runtime: Python 3.11
Memory: 256MB
Timeout: 30s
Environment Variables:
  - SLACK_WEBHOOK_URL: (Slack Incoming Webhook URL)
  - AMP_ENDPOINT: (AMP Query Endpoint)
  - AWS_REGION: ap-northeast-2
```

### 3.3 DynamoDB Table (선택)
```yaml
Name: connectly-alert-runbooks
Purpose: 서비스별 Runbook URL 매핑, 알람 히스토리
Primary Key: alert_name (String)
Sort Key: service (String)
```

### 3.4 IAM Role (Lambda용)
```yaml
필요 권한:
  - logs:FilterLogEvents (CloudWatch Logs 조회)
  - logs:GetLogEvents
  - xray:GetTraceSummaries (X-Ray 트레이스 조회)
  - xray:BatchGetTraces
  - aps:QueryMetrics (AMP 메트릭 조회)
  - ecs:DescribeServices (ECS 배포 정보)
  - ecs:ListTasks
  - ecs:DescribeTasks
  - dynamodb:GetItem (Runbook 조회)
  - dynamodb:PutItem (알람 히스토리 저장)
```

---

## 4. Lambda Enrichment 로직

### 4.1 수집할 컨텍스트 정보

| 정보 | 소스 | 용도 |
|------|------|------|
| 에러 집중 라우트 | AMP | 어떤 서비스에서 에러 발생 중인지 |
| 주요 에러 코드 | AMP | 503, 500 등 에러 유형 파악 |
| 최근 에러 로그 | CloudWatch Logs | 실제 에러 메시지 확인 |
| 연관 알람 | Grafana API | 동시 발생 알람 확인 |
| 최근 배포 정보 | ECS | 배포 직후 장애인지 확인 |
| 트레이스 샘플 | X-Ray | 실패 요청 흐름 추적 |
| Runbook URL | DynamoDB | 대응 가이드 링크 |

### 4.2 AMP 쿼리 예시

```promql
# 에러 집중 라우트 (Gateway)
topk(3, sum by (routeId) (
  rate(spring_cloud_gateway_requests_seconds_count{job="gateway-metrics",outcome="SERVER_ERROR"}[5m])
))

# 주요 에러 코드
topk(3, sum by (status) (
  rate(http_server_requests_seconds_count{job=~".*-metrics",status=~"5.."}[5m])
))

# 서비스별 에러율
sum by (job) (rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
/
sum by (job) (rate(http_server_requests_seconds_count[5m]))
* 100
```

---

## 5. Slack 메시지 포맷

### 5.1 Critical 알람 예시

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
[대시보드] [로그] [트레이스] [Runbook]
```

### 5.2 Slack Block Kit 구조

```json
{
  "blocks": [
    {
      "type": "header",
      "text": {"type": "plain_text", "text": "🚨 [CRITICAL] Gateway High Error Rate"}
    },
    {
      "type": "section",
      "fields": [
        {"type": "mrkdwn", "text": "*Error Rate:*\n7.5%"},
        {"type": "mrkdwn", "text": "*임계값:*\n5%"},
        {"type": "mrkdwn", "text": "*영향 시간:*\n3분 경과"},
        {"type": "mrkdwn", "text": "*심각도:*\n🔴 Critical"}
      ]
    },
    {
      "type": "section",
      "text": {"type": "mrkdwn", "text": "*🔍 원인 분석*\n• 에러 집중: authhub (89%)\n• 에러 코드: 503 (92%)\n• 최근 로그: Connection refused"}
    },
    {
      "type": "actions",
      "elements": [
        {"type": "button", "text": {"type": "plain_text", "text": "📊 대시보드"}, "url": "..."},
        {"type": "button", "text": {"type": "plain_text", "text": "📋 로그"}, "url": "..."},
        {"type": "button", "text": {"type": "plain_text", "text": "🔗 트레이스"}, "url": "..."},
        {"type": "button", "text": {"type": "plain_text", "text": "📖 Runbook"}, "url": "..."}
      ]
    }
  ]
}
```

---

## 6. Grafana Alert Rules 정의

### 6.1 공통 알람 (모든 서비스)

| 알람명 | 조건 | 심각도 | for |
|--------|------|--------|-----|
| InstanceDown | `up == 0` | Critical | 1m |
| HighErrorRate | `error_rate > 5%` | Critical | 5m |
| HighLatencyP99 | `p99 > 2s` | Warning | 5m |
| HighHeapUsage | `heap_usage > 85%` | Warning | 10m |
| HighGCTime | `gc_pause_avg > 500ms` | Warning | 5m |

### 6.2 서비스별 추가 알람

**Gateway 전용**
| 알람명 | 조건 | 심각도 |
|--------|------|--------|
| RouteHighErrorRate | `route_error_rate > 10%` | Warning |
| HighClientError | `4xx_rate > 20%` | Warning |

**Scheduler 전용 (CrawlingHub, FileFlow)**
| 알람명 | 조건 | 심각도 |
|--------|------|--------|
| JobExecutionFailed | `job_failure_count > 0` | Warning |
| JobExecutionDelayed | `job_delay > 5m` | Warning |

**Worker 전용**
| 알람명 | 조건 | 심각도 |
|--------|------|--------|
| QueueBacklog | `queue_size > 1000` | Warning |
| ProcessingTimeout | `processing_time > 30s` | Warning |

### 6.3 Alert Rule PromQL 예시

```yaml
# Instance Down
alert: InstanceDown
expr: up{job=~".*-metrics"} == 0
for: 1m
labels:
  severity: critical
annotations:
  summary: "{{ $labels.job }} Instance Down"
  description: "{{ $labels.instance }} is down"

# High Error Rate
alert: HighErrorRate
expr: |
  (
    sum by (job) (rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
    /
    sum by (job) (rate(http_server_requests_seconds_count[5m]))
  ) * 100 > 5
for: 5m
labels:
  severity: critical
annotations:
  summary: "{{ $labels.job }} Error Rate > 5%"
  description: "현재 에러율: {{ $value | printf \"%.2f\" }}%"

# High P99 Latency
alert: HighLatencyP99
expr: |
  histogram_quantile(0.99,
    sum by (job, le) (rate(http_server_requests_seconds_bucket[5m]))
  ) > 2
for: 5m
labels:
  severity: warning
annotations:
  summary: "{{ $labels.job }} P99 Latency > 2s"
  description: "현재 P99: {{ $value | printf \"%.2f\" }}s"

# High Heap Usage
alert: HighHeapUsage
expr: |
  (
    jvm_memory_used_bytes{area="heap"}
    /
    jvm_memory_max_bytes{area="heap"}
  ) * 100 > 85
for: 10m
labels:
  severity: warning
annotations:
  summary: "{{ $labels.job }} Heap Usage > 85%"
  description: "현재 Heap: {{ $value | printf \"%.1f\" }}%"
```

---

## 7. Slack 채널 구성 (권장)

| 채널 | 용도 | 알람 심각도 |
|------|------|------------|
| #alerts-critical | 즉시 대응 필요 | Critical |
| #alerts-warning | 모니터링 필요 | Warning |
| #alerts-info | 정보성 알람 | Info |

---

## 8. 체크리스트

### 인프라팀 작업
- [ ] SNS Topic 생성
- [ ] Lambda Function 배포
- [ ] IAM Role 생성 및 권한 부여
- [ ] DynamoDB Table 생성 (선택)
- [ ] Slack Webhook URL 발급 및 연동
- [ ] Grafana에 SNS Contact Point 설정

### 개발팀 작업
- [ ] 서비스별 Runbook 작성
- [ ] Alert Rules 검토 및 임계값 조정
- [ ] 테스트 알람 발송 확인

---

## 9. 참고 링크

- [Grafana Alerting Documentation](https://grafana.com/docs/grafana/latest/alerting/)
- [AWS SNS + Lambda Integration](https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html)
- [Slack Block Kit Builder](https://app.slack.com/block-kit-builder)
- [PromQL Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

---

---
---

# Part 2: 로그 시스템 (OpenSearch)

## 11. 개요

### 목적
- 모든 서비스 로그를 OpenSearch로 중앙 집중화
- Kibana를 통한 강력한 로그 검색/분석 기능 제공
- 장애 발생 시 빠른 로그 추적 및 원인 분석

### 현재 상태 → 목표

```
현재: ECS → CloudWatch Logs (검색 제한적)

목표: ECS → CloudWatch Logs → Subscription Filter → OpenSearch
                           ↓
                    S3 (장기 보관)
```

---

## 12. 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                     로그 파이프라인                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ECS Tasks (모든 서비스)                                         │
│      │                                                          │
│      ▼                                                          │
│  CloudWatch Logs                                                │
│      │                                                          │
│      ├──→ Subscription Filter ──→ Lambda ──→ OpenSearch         │
│      │                              │                           │
│      │                              └──→ 로그 변환/필터링         │
│      │                                                          │
│      └──→ S3 (장기 보관, 90일+)                                  │
│                                                                 │
│  OpenSearch                                                     │
│      │                                                          │
│      └──→ Kibana (로그 검색/대시보드)                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 13. 필요 AWS 리소스

### 13.1 OpenSearch Domain

```yaml
Domain Name: connectly-logs-prod
Engine Version: OpenSearch 2.11 (또는 최신)

# 클러스터 구성 (권장)
Instance Type: t3.medium.search (운영) 또는 t3.small.search (비용 절약)
Instance Count: 2 (고가용성)
Storage: 100GB EBS (gp3) per node

# 또는 Serverless (사용량 기반 과금)
OpenSearch Serverless Collection 사용 가능

# 네트워크
VPC 내부 배포 권장 (보안)
또는 Public + Fine-grained access control

# 접근 제어
Fine-grained access control 활성화
SAML 또는 Cognito 연동 (Kibana 접근용)
```

### 13.2 Lambda Function (로그 변환)

```yaml
Name: connectly-logs-to-opensearch
Runtime: Python 3.11 또는 Node.js 18.x
Memory: 256MB
Timeout: 60s
VPC: OpenSearch와 동일 VPC (VPC 내부 배포 시)

Environment Variables:
  - OPENSEARCH_ENDPOINT: (OpenSearch 도메인 엔드포인트)
  - INDEX_PREFIX: connectly-logs
```

### 13.3 CloudWatch Subscription Filters

```yaml
# 각 서비스 로그 그룹에 Subscription Filter 생성
Log Groups:
  - /ecs/gateway-prod
  - /ecs/authhub-web-api-prod
  - /ecs/setof-commerce-web-api-prod
  - /ecs/setof-commerce-admin-prod
  - /ecs/crawlinghub-web-api-prod
  - /ecs/crawlinghub-scheduler-prod
  - /ecs/crawlinghub-worker-prod
  - /ecs/fileflow-web-api-prod
  - /ecs/fileflow-scheduler-prod
  - /ecs/fileflow-worker-prod
  - /ecs/fileflow-resizing-worker-prod

Filter Pattern: "" (모든 로그) 또는 특정 패턴
Destination: Lambda Function (connectly-logs-to-opensearch)
```

### 13.4 S3 Bucket (장기 보관)

```yaml
Bucket Name: connectly-logs-archive-prod
Lifecycle Rules:
  - 90일 후 → Glacier
  - 365일 후 → Glacier Deep Archive
  - 730일 후 → 삭제

# CloudWatch Logs Export
CloudWatch Logs → S3 Export Task (일일 배치)
또는 Kinesis Firehose → S3 (실시간)
```

### 13.5 IAM Roles

```yaml
# Lambda Role
필요 권한:
  - logs:CreateLogGroup
  - logs:CreateLogStream
  - logs:PutLogEvents
  - es:ESHttpPost
  - es:ESHttpPut
  - ec2:CreateNetworkInterface (VPC Lambda 시)
  - ec2:DescribeNetworkInterfaces
  - ec2:DeleteNetworkInterface

# CloudWatch to Lambda
Lambda 리소스 기반 정책:
  - logs.amazonaws.com에서 호출 허용
```

---

## 14. OpenSearch 인덱스 설계

### 14.1 인덱스 패턴

```yaml
# 일별 인덱스 (롤오버)
Index Pattern: connectly-logs-{service}-{YYYY.MM.DD}

예시:
  - connectly-logs-gateway-2024.01.15
  - connectly-logs-authhub-2024.01.15
  - connectly-logs-commerce-2024.01.15
```

### 14.2 인덱스 매핑

```json
{
  "mappings": {
    "properties": {
      "@timestamp": { "type": "date" },
      "service": { "type": "keyword" },
      "environment": { "type": "keyword" },
      "level": { "type": "keyword" },
      "logger": { "type": "keyword" },
      "message": { "type": "text" },
      "traceId": { "type": "keyword" },
      "spanId": { "type": "keyword" },
      "userId": { "type": "keyword" },
      "requestId": { "type": "keyword" },
      "method": { "type": "keyword" },
      "path": { "type": "keyword" },
      "statusCode": { "type": "integer" },
      "duration": { "type": "long" },
      "exception": {
        "type": "object",
        "properties": {
          "class": { "type": "keyword" },
          "message": { "type": "text" },
          "stackTrace": { "type": "text" }
        }
      },
      "ecs": {
        "type": "object",
        "properties": {
          "taskId": { "type": "keyword" },
          "cluster": { "type": "keyword" },
          "containerName": { "type": "keyword" }
        }
      }
    }
  }
}
```

### 14.3 인덱스 수명 관리 (ISM Policy)

```json
{
  "policy": {
    "policy_id": "connectly-logs-policy",
    "description": "로그 인덱스 수명 관리",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [],
        "transitions": [
          { "state_name": "warm", "conditions": { "min_index_age": "7d" } }
        ]
      },
      {
        "name": "warm",
        "actions": [
          { "replica_count": { "number_of_replicas": 0 } }
        ],
        "transitions": [
          { "state_name": "delete", "conditions": { "min_index_age": "30d" } }
        ]
      },
      {
        "name": "delete",
        "actions": [
          { "delete": {} }
        ]
      }
    ]
  }
}
```

---

## 15. Lambda 변환 로직

### 15.1 로그 파싱 및 변환

```python
import json
import gzip
import base64
import boto3
from datetime import datetime
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

def lambda_handler(event, context):
    # CloudWatch Logs 데이터 디코딩
    payload = base64.b64decode(event['awslogs']['data'])
    log_data = json.loads(gzip.decompress(payload))

    log_group = log_data['logGroup']
    log_stream = log_data['logStream']
    service = extract_service_name(log_group)

    documents = []
    for log_event in log_data['logEvents']:
        doc = parse_log_event(log_event, service, log_group, log_stream)
        documents.append(doc)

    # OpenSearch로 벌크 인덱싱
    bulk_index_to_opensearch(documents, service)

def extract_service_name(log_group):
    # /ecs/gateway-prod → gateway
    # /ecs/authhub-web-api-prod → authhub
    parts = log_group.split('/')
    if len(parts) >= 3:
        service_part = parts[2].replace('-prod', '').replace('-web-api', '')
        return service_part
    return 'unknown'

def parse_log_event(log_event, service, log_group, log_stream):
    message = log_event['message']
    timestamp = log_event['timestamp']

    doc = {
        '@timestamp': datetime.utcfromtimestamp(timestamp / 1000).isoformat(),
        'service': service,
        'environment': 'prod',
        'raw_message': message
    }

    # JSON 로그 파싱 시도
    try:
        parsed = json.loads(message)
        doc.update({
            'level': parsed.get('level', 'INFO'),
            'logger': parsed.get('logger'),
            'message': parsed.get('message'),
            'traceId': parsed.get('traceId'),
            'spanId': parsed.get('spanId'),
            'exception': parsed.get('exception')
        })
    except json.JSONDecodeError:
        # 일반 텍스트 로그
        doc['message'] = message
        doc['level'] = detect_log_level(message)

    return doc

def detect_log_level(message):
    if 'ERROR' in message or 'Exception' in message:
        return 'ERROR'
    elif 'WARN' in message:
        return 'WARN'
    elif 'DEBUG' in message:
        return 'DEBUG'
    return 'INFO'
```

---

## 16. Kibana 대시보드 구성

### 16.1 기본 대시보드

| 대시보드 | 용도 | 주요 시각화 |
|----------|------|------------|
| **Overview** | 전체 로그 현황 | 서비스별 로그 볼륨, 에러율 |
| **Error Analysis** | 에러 분석 | 에러 타임라인, 예외 유형별 집계 |
| **Request Tracing** | 요청 추적 | traceId 기반 검색, 요청 흐름 |
| **Service Deep Dive** | 서비스별 상세 | 특정 서비스 로그 분석 |

### 16.2 저장된 검색 (Saved Searches)

```yaml
# 최근 에러 로그
Name: Recent Errors
Query: level:ERROR
Time: Last 1 hour
Columns: @timestamp, service, message, exception.class

# 특정 사용자 요청
Name: User Request Trace
Query: userId:{userId} OR traceId:{traceId}
Time: Last 24 hours

# 느린 요청
Name: Slow Requests
Query: duration:>1000
Time: Last 1 hour

# 특정 서비스 에러
Name: Service Errors
Query: service:{service} AND level:ERROR
Time: Last 6 hours
```

### 16.3 알람 연동

```yaml
# Kibana에서 OpenSearch Alerting 설정
# 특정 조건 시 Slack/SNS로 알람

Monitor: High Error Rate
Trigger: count() of logs where level:ERROR > 100 in 5 minutes
Action: SNS → Lambda → Slack
```

---

## 17. 로그 포맷 표준화 (개발팀 작업)

### 17.1 권장 로그 포맷 (JSON)

```json
{
  "timestamp": "2024-01-15T14:32:15.123Z",
  "level": "ERROR",
  "logger": "com.ryuqq.gateway.filter.AuthFilter",
  "message": "JWT validation failed",
  "traceId": "abc123def456",
  "spanId": "span789",
  "service": "gateway",
  "environment": "prod",
  "userId": "12345",
  "requestId": "req-uuid-here",
  "method": "POST",
  "path": "/api/v1/auth/validate",
  "statusCode": 401,
  "duration": 45,
  "exception": {
    "class": "io.jsonwebtoken.ExpiredJwtException",
    "message": "JWT expired at 2024-01-15T14:30:00Z",
    "stackTrace": "..."
  }
}
```

### 17.2 Spring Boot Logback 설정

```xml
<!-- logback-spring.xml -->
<configuration>
  <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder">
      <includeMdcKeyName>traceId</includeMdcKeyName>
      <includeMdcKeyName>spanId</includeMdcKeyName>
      <includeMdcKeyName>userId</includeMdcKeyName>
      <includeMdcKeyName>requestId</includeMdcKeyName>
    </encoder>
  </appender>

  <root level="INFO">
    <appender-ref ref="JSON" />
  </root>
</configuration>
```

### 17.3 MDC 설정 (Request Filter)

```java
@Component
public class LoggingFilter implements WebFilter {
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        String traceId = exchange.getRequest().getHeaders()
            .getFirst("X-Trace-Id");
        String requestId = UUID.randomUUID().toString();

        return chain.filter(exchange)
            .contextWrite(Context.of(
                "traceId", traceId,
                "requestId", requestId
            ));
    }
}
```

---

## 18. 비용 예상

### 18.1 OpenSearch 비용 (월 기준)

| 구성 | 예상 비용 |
|------|----------|
| t3.small.search x 2 | ~$80 |
| t3.medium.search x 2 | ~$150 |
| Storage 200GB (gp3) | ~$20 |
| **합계** | **$100 ~ $170/월** |

### 18.2 OpenSearch Serverless (대안)

```yaml
# 사용량 기반 과금
Indexing: $0.24 per OCU-hour
Search: $0.24 per OCU-hour
Storage: $0.024 per GB-month

# 예상 (로그 100GB/월, 중간 사용량)
약 $150~300/월 (사용 패턴에 따라 변동)
```

### 18.3 기타 비용

| 항목 | 예상 비용 |
|------|----------|
| Lambda 실행 | ~$5/월 |
| CloudWatch Subscription | ~$0.5/GB |
| S3 장기 보관 | ~$2/월 |

---

## 19. 체크리스트

### 인프라팀 작업
- [ ] OpenSearch Domain 생성 (또는 Serverless Collection)
- [ ] Lambda Function 배포 (로그 변환)
- [ ] IAM Roles 생성
- [ ] CloudWatch Subscription Filters 설정 (각 서비스별)
- [ ] S3 Bucket 생성 (장기 보관)
- [ ] Kibana 접근 설정 (Cognito 또는 SAML)
- [ ] ISM Policy 적용 (인덱스 수명 관리)
- [ ] VPC 설정 (필요 시)

### 개발팀 작업
- [ ] 로그 포맷 JSON 표준화
- [ ] Logback 설정 업데이트
- [ ] MDC 필터 추가 (traceId, requestId)
- [ ] Kibana 대시보드 구성
- [ ] 저장된 검색 쿼리 작성

---

## 20. 참고 링크

- [Amazon OpenSearch Service Documentation](https://docs.aws.amazon.com/opensearch-service/)
- [CloudWatch Logs Subscription Filters](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/SubscriptionFilters.html)
- [Logstash Logback Encoder](https://github.com/logfellow/logstash-logback-encoder)
- [OpenSearch Dashboards](https://opensearch.org/docs/latest/dashboards/)
- [Index State Management](https://opensearch.org/docs/latest/im-plugin/ism/index/)

---

## 21. 문의

- 작성자: [이름]
- 작성일: 2024-XX-XX
- 관련 서비스: Gateway, AuthHub, Commerce, CrawlingHub, FileFlow
