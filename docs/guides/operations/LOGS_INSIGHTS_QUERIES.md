# CloudWatch Logs Insights Query Templates

일반적인 로그 조회 패턴을 위한 CloudWatch Logs Insights 쿼리 모음

## 목차

1. [기본 쿼리](#기본-쿼리)
2. [에러 분석](#에러-분석)
3. [성능 분석](#성능-분석)
4. [보안 및 감사](#보안-및-감사)
5. [LLM 분석 (향후)](#llm-분석-향후)
6. [ECS/Lambda 특화](#ecslambda-특화)

## 기본 쿼리

### 최근 로그 조회 (시간순)
```
fields @timestamp, @message
| sort @timestamp desc
| limit 100
```

### 특정 시간 범위 로그
```
fields @timestamp, @message
| filter @timestamp >= "2025-01-14T00:00:00" and @timestamp < "2025-01-15T00:00:00"
| sort @timestamp desc
```

### 특정 문자열 포함 로그
```
fields @timestamp, @message
| filter @message like /ERROR/ or @message like /WARN/
| sort @timestamp desc
| limit 50
```

### Request ID로 추적
```
fields @timestamp, @message, request_id
| filter request_id = "req-abc123"
| sort @timestamp asc
```

### 로그 통계 (시간대별)
```
stats count() by bin(5m)
```

## 에러 분석

### 에러 로그만 조회
```
fields @timestamp, @message, @logStream
| filter @message like /ERROR/ or @message like /Exception/
| sort @timestamp desc
| limit 100
```

### 에러 유형별 집계
```
fields @timestamp, @message
| filter @message like /ERROR/
| parse @message /ERROR: (?<error_type>.*?):/
| stats count() by error_type
| sort count() desc
```

### 가장 빈번한 에러 Top 10
```
fields @message
| filter @message like /ERROR/
| stats count(*) as error_count by @message
| sort error_count desc
| limit 10
```

### 에러율 추이 (시간대별)
```
fields @timestamp
| filter @message like /ERROR/
| stats count() as errors by bin(5m)
```

### 특정 에러 스택 트레이스 조회
```
fields @timestamp, @message
| filter @message like /NullPointerException/
| sort @timestamp desc
| limit 20
```

## 성능 분석

### 응답 시간 분석
```
fields @timestamp, duration
| filter ispresent(duration)
| stats avg(duration) as avg_duration,
        max(duration) as max_duration,
        min(duration) as min_duration,
        pct(duration, 95) as p95_duration
  by bin(5m)
```

### 느린 요청 조회 (P95 초과)
```
fields @timestamp, @message, duration, request_id
| filter ispresent(duration) and duration > 1000
| sort duration desc
| limit 50
```

### API 엔드포인트별 평균 응답 시간
```
fields @timestamp, endpoint, duration
| filter ispresent(endpoint) and ispresent(duration)
| stats avg(duration) as avg_duration by endpoint
| sort avg_duration desc
```

### 처리량 분석 (RPS)
```
stats count(*) as requests by bin(1m)
| fields bin(1m) as minute, requests / 60 as rps
```

## 보안 및 감사

### 특정 사용자 활동 추적
```
fields @timestamp, @message, user_id, action
| filter user_id = "user-123"
| sort @timestamp desc
| limit 100
```

### 권한 거부 로그
```
fields @timestamp, @message, user_id, resource
| filter @message like /AccessDenied/ or @message like /Unauthorized/
| sort @timestamp desc
```

### IP 주소별 요청 집계
```
fields @timestamp, ip_address
| stats count() as request_count by ip_address
| sort request_count desc
| limit 20
```

### 의심스러운 활동 감지 (높은 에러율)
```
fields @timestamp, ip_address
| filter @message like /ERROR/ or @message like /40[13]/
| stats count() as error_count by ip_address
| filter error_count > 10
| sort error_count desc
```

## LLM 분석 (향후)

### LLM 호출 비용 분석
```
fields @timestamp, model, prompt_tokens, completion_tokens, total_cost
| filter ispresent(total_cost)
| stats sum(total_cost) as total_cost,
        sum(prompt_tokens + completion_tokens) as total_tokens,
        count() as calls
  by bin(1h)
```

### 모델별 비용 집계
```
fields model, total_cost
| filter ispresent(total_cost)
| stats sum(total_cost) as total_cost,
        avg(total_cost) as avg_cost,
        count() as calls
  by model
| sort total_cost desc
```

### 느린 LLM 호출 조회
```
fields @timestamp, model, latency_ms, prompt_tokens, completion_tokens
| filter ispresent(latency_ms) and latency_ms > 5000
| sort latency_ms desc
| limit 20
```

### 프롬프트 토큰 효율성 분석
```
fields model, prompt_tokens, completion_tokens
| filter ispresent(prompt_tokens)
| stats avg(prompt_tokens) as avg_prompt,
        avg(completion_tokens) as avg_completion,
        avg(prompt_tokens + completion_tokens) as avg_total
  by model
```

### LLM 에러 분석
```
fields @timestamp, model, @message
| filter @message like /ERROR/ and ispresent(model)
| stats count() as error_count by model
| sort error_count desc
```

## ECS/Lambda 특화

### ECS Task별 로그 조회
```
fields @timestamp, @message, @logStream
| filter @logStream like /ecs/atlantis/
| sort @timestamp desc
| limit 100
```

### Lambda Cold Start 조회
```
fields @timestamp, @message, @duration
| filter @message like /Init Duration/
| parse @message "Init Duration: * ms" as init_duration
| stats avg(init_duration) as avg_cold_start,
        count() as cold_starts
  by bin(1h)
```

### Lambda 메모리 사용량 분석
```
fields @timestamp, @memorySize, @maxMemoryUsed
| stats avg(@maxMemoryUsed / @memorySize * 100) as avg_memory_percent,
        max(@maxMemoryUsed) as max_memory
  by bin(5m)
```

### ECS 컨테이너 재시작 감지
```
fields @timestamp, @message
| filter @message like /Task stopped/ or @message like /Container stopped/
| sort @timestamp desc
```

### Lambda Timeout 조회
```
fields @timestamp, @message, @requestId
| filter @message like /Task timed out/
| sort @timestamp desc
| limit 50
```

## 고급 쿼리

### 다중 조건 필터링
```
fields @timestamp, @message, status_code, duration
| filter (status_code >= 400 or duration > 1000)
    and @message not like /health/
| sort @timestamp desc
```

### 정규표현식 파싱
```
fields @timestamp, @message
| parse @message /\[(?<level>.*?)\] \[(?<service>.*?)\] (?<msg>.*)/
| filter level = "ERROR"
| stats count() by service
```

### JSON 로그 파싱
```
fields @timestamp, @message
| filter @message like /^\{/
| parse @message '{"level":"*","msg":"*","service":"*"' as level, msg, service
| filter level = "error"
| stats count() by service
```

### 복합 통계
```
fields @timestamp, duration, status_code
| stats count() as total,
        avg(duration) as avg_duration,
        pct(duration, 95) as p95,
        sum(status_code >= 500) as errors_5xx,
        sum(status_code >= 400 and status_code < 500) as errors_4xx
  by bin(5m)
```

## 사용 팁

### 1. 쿼리 최적화
- 필요한 필드만 선택 (`fields`로 명시)
- 시간 범위를 최소화
- `limit`로 결과 개수 제한
- 인덱스 가능한 필드 활용 (`@timestamp`, `@logStream` 등)

### 2. 파싱 전략
- 구조화된 로그 (JSON) 권장
- 일관된 로그 포맷 사용
- 중요 필드는 명시적으로 로깅

### 3. 비용 절감
- 불필요한 DEBUG 로그 제외
- Retention 기간 최적화
- 쿼리 범위 최소화 (스캔 데이터 줄이기)

### 4. 쿼리 저장
CloudWatch Console에서 자주 사용하는 쿼리는 "Save"하여 재사용

### 5. 알람 설정
Metric Filter로 변환하여 CloudWatch Alarm 설정 가능

## 샘플 로그 포맷

### 권장 JSON 로그 구조
```json
{
  "timestamp": "2025-01-14T10:30:00Z",
  "level": "ERROR",
  "service": "api-server",
  "request_id": "req-abc123",
  "user_id": "user-456",
  "endpoint": "/api/v1/users",
  "method": "GET",
  "status_code": 500,
  "duration": 1234,
  "error": {
    "type": "DatabaseError",
    "message": "Connection timeout",
    "stack": "..."
  },
  "metadata": {
    "ip": "192.168.1.1",
    "user_agent": "..."
  }
}
```

### LLM 로그 구조 (향후)
```json
{
  "timestamp": "2025-01-14T10:30:00Z",
  "request_id": "req-abc123",
  "model": "gpt-4",
  "prompt_tokens": 150,
  "completion_tokens": 300,
  "total_tokens": 450,
  "total_cost": 0.015,
  "latency_ms": 1200,
  "prompt_hash": "sha256...",
  "user_id": "user-456"
}
```

## 참고 자료

- [CloudWatch Logs Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [Logs Insights Sample Queries](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax-examples.html)
- [로깅 네이밍 규칙](./LOGGING_NAMING_CONVENTION.md)
- [IN-116 설계 문서](../claudedocs/IN-116-logging-system-design.md)
