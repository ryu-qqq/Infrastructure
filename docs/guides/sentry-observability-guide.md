# Sentry & Observability 통합 가이드

ECS 서비스에 Sentry를 통합하고, 기존 Observability 스택(ADOT, X-Ray, OpenSearch)과 연결하는 방법을 안내합니다.

## 목차

1. [전체 아키텍처](#전체-아키텍처)
2. [Phase 1: Log Streaming](#phase-1-log-streaming-완료)
3. [Phase 2: Sentry 통합](#phase-2-sentry-통합)
4. [Phase 3: Trace ID 연결](#phase-3-trace-id-연결)
5. [통합 검증](#통합-검증)
6. [알림 파이프라인](#알림-파이프라인)

---

## 전체 아키텍처

### Observability 3대 축

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ECS Service (Spring Boot)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────┐  │
│   │   METRICS   │     │   TRACES    │     │    LOGS     │     │  ERRORS │  │
│   │ (숫자 데이터) │     │ (요청 추적)  │     │ (텍스트 기록) │     │ (예외 추적)│  │
│   └──────┬──────┘     └──────┬──────┘     └──────┬──────┘     └────┬────┘  │
│          │                   │                   │                  │       │
│          ▼                   ▼                   ▼                  ▼       │
│   ┌──────────────────────────────┐       ┌───────────┐      ┌───────────┐  │
│   │   ADOT Collector (사이드카)    │       │CloudWatch │      │ Sentry SDK│  │
│   │ • Prometheus 메트릭 (PULL)    │       │   Logs    │      │           │  │
│   │ • X-Ray 트레이스 (PUSH)       │       └─────┬─────┘      └─────┬─────┘  │
│   └───────┬─────────────┬────────┘             │                  │        │
│           │             │                      │                  │        │
└───────────┼─────────────┼──────────────────────┼──────────────────┼────────┘
            │             │                      │                  │
            ▼             ▼                      ▼                  ▼
     ┌──────────┐  ┌──────────┐          ┌──────────────┐    ┌──────────┐
     │   AMP    │  │  X-Ray   │          │  OpenSearch  │    │  Sentry  │
     │(Prometheus)│  │(트레이싱) │          │  (로그 저장)  │    │ (에러 관리)│
     └─────┬────┘  └────┬─────┘          └───────┬──────┘    └────┬─────┘
           │            │                        │                │
           ▼            │                        ▼                │
     ┌──────────┐       │                 ┌──────────────┐        │
     │ Grafana  │◄──────┘                 │   Alerting   │        │
     │(대시보드) │                         │  → n8n/Slack │◄───────┘
     └──────────┘                         └──────────────┘
```

### Trace ID 연결 흐름

```
                         trace_id: abc-123-def
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
   ┌─────────┐           ┌─────────┐           ┌─────────┐
   │ X-Ray   │           │OpenSearch│           │ Sentry  │
   │ Traces  │◄─────────▶│  Logs   │◄─────────▶│ Errors  │
   └─────────┘           └─────────┘           └─────────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ 하나의 trace_id로    │
                    │ 모든 정보 연결 가능   │
                    └─────────────────────┘
```

---

## Phase 1: Log Streaming (완료)

> 상세 가이드: [log-streaming-setup-guide.md](./log-streaming-setup-guide.md)

### 요약

각 서비스에 `log-subscription-filter` 모듈 추가:

```hcl
module "log_streaming" {
  source = "git::https://github.com/ryu-qqq/Infrastructure.git//terraform/modules/log-subscription-filter?ref=main"

  log_group_name = module.web_api_logs.log_group_name
  service_name   = "crawlinghub-web-api"
}
```

### 결과

- CloudWatch Logs → OpenSearch 자동 스트리밍
- OpenSearch에서 로그 검색 및 분석 가능
- Alerting 설정으로 에러 감지 가능

---

## Phase 2: Sentry 통합

### Step 1: Sentry 프로젝트 생성

1. [Sentry.io](https://sentry.io) 접속 (또는 Self-hosted Sentry)
2. 새 프로젝트 생성: `Platform` → `Java` → `Spring Boot`
3. DSN 복사: `https://xxx@xxx.ingest.sentry.io/xxx`

### Step 2: Spring Boot 의존성 추가

`build.gradle`:

```groovy
dependencies {
    // Sentry Spring Boot Starter
    implementation 'io.sentry:sentry-spring-boot-starter-jakarta:7.3.0'

    // Sentry Logback (로그와 연동)
    implementation 'io.sentry:sentry-logback:7.3.0'

    // OpenTelemetry 연동 (선택 - Phase 3)
    implementation 'io.sentry:sentry-opentelemetry-agent:7.3.0'
}
```

`build.gradle.kts` (Kotlin DSL):

```kotlin
dependencies {
    implementation("io.sentry:sentry-spring-boot-starter-jakarta:7.3.0")
    implementation("io.sentry:sentry-logback:7.3.0")
    implementation("io.sentry:sentry-opentelemetry-agent:7.3.0")
}
```

### Step 3: application.yml 설정

```yaml
sentry:
  dsn: ${SENTRY_DSN}
  environment: ${SPRING_PROFILES_ACTIVE:local}
  release: ${APP_VERSION:unknown}

  # 성능 모니터링 (트랜잭션 샘플링)
  traces-sample-rate: 1.0  # 개발: 1.0, 프로덕션: 0.1~0.3 권장

  # 에러 필터링
  ignored-exceptions-for-type:
    - org.springframework.web.HttpRequestMethodNotSupportedException
    - org.springframework.web.servlet.NoHandlerFoundException

  # 민감 정보 필터링
  send-default-pii: false

  # 서버 이름 (ECS Task ID 사용)
  server-name: ${HOSTNAME:unknown}

  # 태그 추가
  tags:
    service: ${SERVICE_NAME:unknown}
    cluster: ${CLUSTER_NAME:unknown}

  # 로그 연동
  logging:
    minimum-event-level: error    # ERROR 이상만 Sentry로 전송
    minimum-breadcrumb-level: info # INFO 이상은 breadcrumb으로 저장
```

### Step 4: Logback 설정

`src/main/resources/logback-spring.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <!-- 기존 appender들 유지 -->
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>
    <include resource="org/springframework/boot/logging/logback/console-appender.xml"/>

    <!-- Sentry Appender 추가 -->
    <appender name="SENTRY" class="io.sentry.logback.SentryAppender">
        <options>
            <!-- DSN은 application.yml에서 설정 -->
        </options>
        <!-- ERROR 레벨 이상만 Sentry로 전송 -->
        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>ERROR</level>
        </filter>
    </appender>

    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="SENTRY"/>
    </root>
</configuration>
```

### Step 5: Terraform에 SENTRY_DSN 추가

**옵션 A: Secrets Manager 사용 (권장)**

`secrets.tf` 또는 해당 서비스의 terraform:

```hcl
# Secrets Manager에 SENTRY_DSN 저장 (수동으로 값 설정)
resource "aws_secretsmanager_secret" "sentry_dsn" {
  name        = "/${var.project_name}/sentry/dsn"
  description = "Sentry DSN for ${var.project_name}"

  tags = local.common_tags
}
```

ECS Task Definition에서 참조:

```hcl
container_secrets = [
  { name = "DB_PASSWORD", valueFrom = "${data.aws_secretsmanager_secret.rds.arn}:password::" },
  { name = "SENTRY_DSN", valueFrom = aws_secretsmanager_secret.sentry_dsn.arn }
]
```

**옵션 B: SSM Parameter 사용**

```hcl
resource "aws_ssm_parameter" "sentry_dsn" {
  name        = "/${var.project_name}/sentry/dsn"
  description = "Sentry DSN for ${var.project_name}"
  type        = "SecureString"
  value       = "placeholder"  # 수동으로 실제 값 설정

  lifecycle {
    ignore_changes = [value]
  }

  tags = local.common_tags
}
```

### Step 6: ECS Task Definition 환경변수 추가

```hcl
container_environment = [
  { name = "SPRING_PROFILES_ACTIVE", value = var.environment },
  # ... 기존 환경변수들 ...

  # Sentry 관련
  { name = "SERVICE_NAME", value = "${var.project_name}-web-api" },
  { name = "CLUSTER_NAME", value = data.aws_ecs_cluster.main.cluster_name },
  { name = "APP_VERSION", value = var.image_tag }
]

container_secrets = [
  # ... 기존 secrets ...
  { name = "SENTRY_DSN", valueFrom = aws_secretsmanager_secret.sentry_dsn.arn }
]
```

### Step 7: 커스텀 에러 핸들러 (선택)

`GlobalExceptionHandler.java`:

```java
import io.sentry.Sentry;
import io.sentry.SentryLevel;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleException(Exception e, HttpServletRequest request) {
        // Sentry에 추가 컨텍스트 전송
        Sentry.withScope(scope -> {
            scope.setTag("endpoint", request.getRequestURI());
            scope.setTag("method", request.getMethod());
            scope.setLevel(SentryLevel.ERROR);

            // 사용자 정보 (있는 경우)
            if (SecurityContextHolder.getContext().getAuthentication() != null) {
                scope.setTag("user", SecurityContextHolder.getContext()
                    .getAuthentication().getName());
            }

            Sentry.captureException(e);
        });

        return ResponseEntity.status(500)
            .body(new ErrorResponse("Internal Server Error", e.getMessage()));
    }
}
```

---

## Phase 3: Trace ID 연결

### 목표

하나의 `trace_id`로 X-Ray, OpenSearch Logs, Sentry 에러를 모두 연결합니다.

### 현재 상태

- **ADOT + X-Ray**: OpenTelemetry trace_id 사용
- **CloudWatch Logs**: trace_id가 로그에 포함되어야 함
- **Sentry**: 별도의 event_id 사용 중

### Step 1: MDC에 Trace ID 추가

`TraceIdFilter.java`:

```java
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanContext;
import org.slf4j.MDC;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;

@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class TraceIdFilter implements Filter {

    private static final String TRACE_ID = "traceId";
    private static final String SPAN_ID = "spanId";

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        try {
            // OpenTelemetry에서 현재 Span 가져오기
            SpanContext spanContext = Span.current().getSpanContext();

            if (spanContext.isValid()) {
                MDC.put(TRACE_ID, spanContext.getTraceId());
                MDC.put(SPAN_ID, spanContext.getSpanId());
            }

            chain.doFilter(request, response);
        } finally {
            MDC.remove(TRACE_ID);
            MDC.remove(SPAN_ID);
        }
    }
}
```

### Step 2: Logback에서 Trace ID 출력

`logback-spring.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>

    <!-- JSON 포맷 로그 (CloudWatch/OpenSearch 용) -->
    <appender name="JSON_CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeMdcKeyName>traceId</includeMdcKeyName>
            <includeMdcKeyName>spanId</includeMdcKeyName>
            <customFields>
                {"service":"${SERVICE_NAME:-unknown}","environment":"${SPRING_PROFILES_ACTIVE:-local}"}
            </customFields>
        </encoder>
    </appender>

    <!-- Sentry Appender -->
    <appender name="SENTRY" class="io.sentry.logback.SentryAppender">
        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>ERROR</level>
        </filter>
    </appender>

    <root level="INFO">
        <appender-ref ref="JSON_CONSOLE"/>
        <appender-ref ref="SENTRY"/>
    </root>
</configuration>
```

### Step 3: Sentry에 Trace ID 연결

`SentryConfiguration.java`:

```java
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanContext;
import io.sentry.Sentry;
import io.sentry.SentryOptions;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SentryConfiguration {

    @Bean
    public Sentry.OptionsConfiguration<SentryOptions> customOptionsConfiguration() {
        return options -> {
            options.setBeforeSend((event, hint) -> {
                // OpenTelemetry trace_id를 Sentry 이벤트에 추가
                SpanContext spanContext = Span.current().getSpanContext();
                if (spanContext.isValid()) {
                    event.setTag("trace_id", spanContext.getTraceId());
                    event.setTag("span_id", spanContext.getSpanId());

                    // Sentry의 trace 컨텍스트 설정
                    event.getContexts().setTrace(
                        new io.sentry.protocol.SentrySpan() {{
                            setTraceId(spanContext.getTraceId());
                            setSpanId(spanContext.getSpanId());
                        }}
                    );
                }
                return event;
            });
        };
    }
}
```

### Step 4: Gradle 의존성 추가 (JSON 로그용)

```groovy
dependencies {
    // Logstash Logback Encoder (JSON 로그 출력)
    implementation 'net.logstash.logback:logstash-logback-encoder:7.4'
}
```

### 결과: 통합된 Trace ID

**OpenSearch 로그**:
```json
{
  "@timestamp": "2024-01-15T10:30:00.000Z",
  "level": "ERROR",
  "message": "Payment failed",
  "traceId": "abc123def456",
  "spanId": "789xyz",
  "service": "crawlinghub-web-api"
}
```

**Sentry 이벤트**:
```
Tags:
  trace_id: abc123def456
  span_id: 789xyz
  service: crawlinghub-web-api
```

**X-Ray 콘솔에서 조회**:
```
Trace ID: abc123def456
→ 전체 요청 경로 시각화
```

---

## 통합 검증

### 1. 테스트 에러 발생시키기

```java
@RestController
@RequestMapping("/api/test")
public class TestController {

    @GetMapping("/error")
    public String testError() {
        throw new RuntimeException("Test error for observability verification");
    }
}
```

### 2. 확인 체크리스트

| 항목 | 확인 방법 | 기대 결과 |
|-----|---------|---------|
| **CloudWatch Logs** | AWS 콘솔 → CloudWatch → Log groups | 에러 로그에 traceId 포함 |
| **OpenSearch** | OpenSearch Dashboards → Discover | traceId로 검색 가능 |
| **X-Ray** | AWS 콘솔 → X-Ray → Traces | 해당 trace_id의 전체 경로 시각화 |
| **Sentry** | Sentry 대시보드 → Issues | trace_id 태그로 필터 가능 |
| **Grafana** | Grafana → X-Ray 데이터소스 | trace_id로 트레이스 조회 |

### 3. 통합 쿼리 예시

**OpenSearch에서 특정 trace의 모든 로그 조회**:
```
traceId: "abc123def456"
```

**Sentry에서 특정 trace의 에러 찾기**:
```
trace_id:abc123def456
```

**X-Ray에서 분석**:
1. X-Ray 콘솔 접속
2. Traces 메뉴
3. trace_id 검색
4. Service Map에서 요청 경로 확인

---

## 알림 파이프라인

### 최종 아키텍처

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           에러 감지 소스                                    │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                 │
│  │  OpenSearch │     │   Sentry    │     │  CloudWatch │                 │
│  │  Alerting   │     │  Webhooks   │     │   Alarms    │                 │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                 │
│         │                   │                   │                        │
└─────────┼───────────────────┼───────────────────┼────────────────────────┘
          │                   │                   │
          └───────────────────┼───────────────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │    n8n Workflow     │
                    │  • 에러 집계         │
                    │  • 중복 제거         │
                    │  • 심각도 분류       │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Slack 알림         │
                    │  • 에러 요약         │
                    │  • trace_id 링크     │
                    │  • 액션 버튼          │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   자동 수정 (선택)    │
                    │  • AI 코드 분석      │
                    │  • PR 자동 생성      │
                    └─────────────────────┘
```

### Sentry Webhook → n8n 연동

**Sentry 설정**:
1. Settings → Integrations → Webhooks
2. Callback URL: `https://your-n8n-domain/webhook/sentry-error`
3. 이벤트: `issue.created`, `issue.resolved`

**n8n Workflow 예시**:
```json
{
  "trigger": "Sentry Webhook",
  "steps": [
    {
      "name": "Parse Error",
      "action": "Extract trace_id, error message, stack trace"
    },
    {
      "name": "Enrich Data",
      "action": "Fetch related logs from OpenSearch using trace_id"
    },
    {
      "name": "Send Slack",
      "action": "Format and send to #alerts channel"
    }
  ]
}
```

---

## 서비스별 적용 순서

### 권장 순서

1. **Gateway** - 모든 요청의 진입점, 가장 영향력 큼
2. **AuthHub** - 인증 관련 에러는 중요도 높음
3. **CrawlingHub Web API** - 비즈니스 로직
4. **Fileflow Web API** - 파일 처리 관련
5. **Workers** (Scheduler, Crawl-Worker, etc.)

### 체크리스트

각 서비스마다:

- [ ] Phase 1: `log-subscription-filter` 모듈 추가
- [ ] Phase 2: Sentry SDK 추가
- [ ] Phase 2: SENTRY_DSN 환경변수 설정
- [ ] Phase 3: TraceIdFilter 추가
- [ ] Phase 3: Logback JSON 설정
- [ ] Phase 3: SentryConfiguration 추가
- [ ] 통합 테스트 수행
- [ ] 알림 파이프라인 연결

---

## 참고 자료

- [Sentry Spring Boot 문서](https://docs.sentry.io/platforms/java/guides/spring-boot/)
- [OpenTelemetry Java 문서](https://opentelemetry.io/docs/instrumentation/java/)
- [AWS X-Ray 문서](https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html)
- [Logstash Logback Encoder](https://github.com/logfellow/logstash-logback-encoder)
