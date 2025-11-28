# Spring Boot 3.x Observability 구현 가이드

> **대상**: Spring Boot 3.x + Micrometer + OpenTelemetry 기반 마이크로서비스
> **목적**: Prometheus + Grafana + AWS X-Ray 기반 모니터링 구축

---

## 목차

1. [개요](#1-개요)
2. [의존성 설정](#2-의존성-설정)
3. [Prometheus 메트릭 설정](#3-prometheus-메트릭-설정)
4. [커스텀 비즈니스 메트릭](#4-커스텀-비즈니스-메트릭)
5. [Downstream Latency 메트릭](#5-downstream-latency-메트릭)
6. [Scheduler 메트릭](#6-scheduler-메트릭)
7. [구조화된 로깅](#7-구조화된-로깅)
8. [OpenTelemetry 통합](#8-opentelemetry-통합)
9. [Grafana 대시보드](#9-grafana-대시보드)
10. [체크리스트](#10-체크리스트)

---

## 1. 개요

### 1.1 모니터링 아키텍처

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Web API    │    │  Scheduler  │    │   Worker    │
│  Service    │    │   Service   │    │   Service   │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────┐
│              OpenTelemetry Collector                │
│  (Traces → X-Ray, Metrics → Prometheus)             │
└──────────────────────┬──────────────────────────────┘
                       │
       ┌───────────────┼───────────────┐
       ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   AWS X-Ray  │ │  Prometheus  │ │  CloudWatch  │
│   (Traces)   │ │  (Metrics)   │ │   (Logs)     │
└──────────────┘ └──────┬───────┘ └──────────────┘
                        │
                        ▼
                ┌──────────────┐
                │   Grafana    │
                │ (Dashboard)  │
                └──────────────┘
```

### 1.2 핵심 원칙

| 원칙 | 설명 |
|------|------|
| **서비스 구분** | 모든 메트릭에 `application` 태그로 서비스 식별 |
| **Trace 연동** | 로그에 `traceId`, `spanId` 포함하여 Trace-Log 연계 |
| **Downstream 추적** | 외부 의존성(Redis, DB, S3, API) 호출 latency 측정 |
| **비즈니스 메트릭** | 도메인 특화 메트릭 (처리 건수, 성공/실패율 등) |

---

## 2. 의존성 설정

### 2.1 Gradle (build.gradle.kts)

```kotlin
dependencies {
    // Spring Boot Actuator
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    // Micrometer Prometheus Registry
    implementation("io.micrometer:micrometer-registry-prometheus")

    // Micrometer Tracing (OpenTelemetry Bridge)
    implementation("io.micrometer:micrometer-tracing-bridge-otel")

    // OpenTelemetry (자동 계측용)
    implementation("io.opentelemetry:opentelemetry-api")

    // Logback JSON Encoder (구조화된 로그)
    implementation("net.logstash.logback:logstash-logback-encoder:7.4")
}
```

### 2.2 버전 호환성

| 구성요소 | 권장 버전 |
|----------|-----------|
| Spring Boot | 3.2+ |
| Micrometer | 1.12+ |
| OpenTelemetry Agent | 2.x |
| Logstash Encoder | 7.4+ |

---

## 3. Prometheus 메트릭 설정

### 3.1 application.yml 설정

**핵심**: 각 서비스별로 `application` 태그를 **반드시** 다르게 설정해야 Grafana에서 구분 가능

```yaml
# ============================================
# Actuator & Prometheus 설정
# ============================================
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
      base-path: /actuator
  endpoint:
    health:
      show-details: when_authorized
      probes:
        enabled: true
    prometheus:
      enabled: true

  # 핵심: 서비스 식별 태그
  metrics:
    tags:
      application: ${spring.application.name}  # 서비스별 고유값
      environment: ${SPRING_PROFILES_ACTIVE:prod}

    # HikariCP 메트릭 활성화
    enable:
      hikaricp: true
      jvm: true
      process: true
      system: true

    distribution:
      percentiles-histogram:
        http.server.requests: true
      percentiles:
        http.server.requests: 0.5, 0.95, 0.99
```

### 3.2 서비스별 설정 예시

```yaml
# web-api/application.yml
spring:
  application:
    name: fileflow-api

management:
  metrics:
    tags:
      application: fileflow-api

---
# scheduler/application.yml
spring:
  application:
    name: fileflow-scheduler

management:
  metrics:
    tags:
      application: fileflow-scheduler

---
# worker/application.yml
spring:
  application:
    name: fileflow-worker

management:
  metrics:
    tags:
      application: fileflow-worker
```

### 3.3 Security 설정 (Actuator 보호)

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .authorizeHttpRequests(auth -> auth
                // Health/Prometheus는 허용 (내부 네트워크에서만 접근)
                .requestMatchers("/actuator/health/**").permitAll()
                .requestMatchers("/actuator/prometheus").permitAll()
                .requestMatchers("/actuator/info").permitAll()
                // 나머지 actuator는 인증 필요
                .requestMatchers("/actuator/**").authenticated()
                .anyRequest().authenticated()
            )
            .build();
    }
}
```

---

## 4. 커스텀 비즈니스 메트릭

### 4.1 메트릭 클래스 구조

```java
@Component
public class BusinessMetrics {

    private static final String METRIC_PREFIX = "business";

    private final Counter totalCounter;
    private final Counter successCounter;
    private final Counter failureCounter;
    private final Timer processingTimer;

    public BusinessMetrics(MeterRegistry meterRegistry) {
        this.totalCounter = Counter.builder(METRIC_PREFIX + ".requests.total")
            .description("Total requests received")
            .tag("type", "all")
            .register(meterRegistry);

        this.successCounter = Counter.builder(METRIC_PREFIX + ".requests.success")
            .description("Successful requests")
            .register(meterRegistry);

        this.failureCounter = Counter.builder(METRIC_PREFIX + ".requests.failure")
            .description("Failed requests")
            .register(meterRegistry);

        this.processingTimer = Timer.builder(METRIC_PREFIX + ".processing.duration")
            .description("Request processing duration")
            .publishPercentiles(0.5, 0.95, 0.99)
            .publishPercentileHistogram()
            .register(meterRegistry);
    }

    public void recordRequest() {
        totalCounter.increment();
    }

    public void recordSuccess() {
        successCounter.increment();
    }

    public void recordFailure() {
        failureCounter.increment();
    }

    public void recordDuration(long durationMs) {
        processingTimer.record(durationMs, TimeUnit.MILLISECONDS);
    }

    public Timer.Sample startTimer(MeterRegistry registry) {
        return Timer.start(registry);
    }
}
```

### 4.2 사용 예시

```java
@Service
@RequiredArgsConstructor
public class DownloadService {

    private final BusinessMetrics metrics;
    private final MeterRegistry meterRegistry;

    public void processDownload(DownloadRequest request) {
        metrics.recordRequest();
        Timer.Sample sample = metrics.startTimer(meterRegistry);

        try {
            // 비즈니스 로직
            doDownload(request);
            metrics.recordSuccess();
        } catch (Exception e) {
            metrics.recordFailure();
            throw e;
        } finally {
            sample.stop(metrics.getProcessingTimer());
        }
    }
}
```

---

## 5. Downstream Latency 메트릭

### 5.1 통합 Downstream 메트릭 클래스

외부 의존성(Redis, DB, S3, 외부 API) 호출 latency를 측정하여 병목 감지

```java
@Component
public class DownstreamMetrics {

    private static final String METRIC_PREFIX = "downstream";

    private final MeterRegistry meterRegistry;

    public DownstreamMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }

    /**
     * Redis 작업 latency 기록
     */
    public void recordRedisLatency(String operation, long durationMs) {
        Timer.builder(METRIC_PREFIX + ".redis.latency")
            .description("Redis operation latency")
            .tag("operation", operation)  // get, set, delete, lock
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry)
            .record(durationMs, TimeUnit.MILLISECONDS);
    }

    /**
     * Database 쿼리 latency 기록
     */
    public void recordDbLatency(String operation, String table, long durationMs) {
        Timer.builder(METRIC_PREFIX + ".db.latency")
            .description("Database query latency")
            .tag("operation", operation)  // select, insert, update, delete
            .tag("table", table)
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry)
            .record(durationMs, TimeUnit.MILLISECONDS);
    }

    /**
     * S3 작업 latency 기록
     */
    public void recordS3Latency(String operation, long durationMs) {
        Timer.builder(METRIC_PREFIX + ".s3.latency")
            .description("S3 operation latency")
            .tag("operation", operation)  // upload, download, presign
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry)
            .record(durationMs, TimeUnit.MILLISECONDS);
    }

    /**
     * 외부 API 호출 latency 기록
     */
    public void recordExternalApiLatency(String service, String endpoint, long durationMs) {
        Timer.builder(METRIC_PREFIX + ".external.api.latency")
            .description("External API call latency")
            .tag("service", service)
            .tag("endpoint", endpoint)
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry)
            .record(durationMs, TimeUnit.MILLISECONDS);
    }

    /**
     * SQS 메시지 발행 latency 기록
     */
    public void recordSqsPublishLatency(String queue, long durationMs) {
        Timer.builder(METRIC_PREFIX + ".sqs.publish.latency")
            .description("SQS message publish latency")
            .tag("queue", queue)
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry)
            .record(durationMs, TimeUnit.MILLISECONDS);
    }
}
```

### 5.2 사용 예시 - Redis AOP

```java
@Aspect
@Component
@RequiredArgsConstructor
public class RedisMetricsAspect {

    private final DownstreamMetrics metrics;

    @Around("execution(* org.redisson.api.RBucket.get(..))")
    public Object measureRedisGet(ProceedingJoinPoint pjp) throws Throwable {
        long start = System.currentTimeMillis();
        try {
            return pjp.proceed();
        } finally {
            metrics.recordRedisLatency("get", System.currentTimeMillis() - start);
        }
    }
}
```

### 5.3 Grafana 쿼리 예시

```promql
# Redis 평균 latency
rate(downstream_redis_latency_seconds_sum[5m])
/ rate(downstream_redis_latency_seconds_count[5m])

# S3 업로드 p99 latency
histogram_quantile(0.99, rate(downstream_s3_latency_seconds_bucket{operation="upload"}[5m]))

# DB 쿼리 latency by table
sum by (table) (rate(downstream_db_latency_seconds_sum[5m]))
```

---

## 6. Scheduler 메트릭

### 6.1 Scheduler 메트릭 클래스

```java
@Component
public class SchedulerMetrics {

    private static final String METRIC_PREFIX = "scheduler";

    private final MeterRegistry meterRegistry;

    public SchedulerMetrics(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }

    /**
     * Job 실행 시작
     */
    public Timer.Sample startJob(String jobName) {
        Counter.builder(METRIC_PREFIX + ".job.runs.total")
            .description("Total job executions")
            .tag("job", jobName)
            .register(meterRegistry)
            .increment();

        return Timer.start(meterRegistry);
    }

    /**
     * Job 성공 완료
     */
    public void recordJobSuccess(String jobName, Timer.Sample sample) {
        Counter.builder(METRIC_PREFIX + ".job.success.total")
            .description("Successful job executions")
            .tag("job", jobName)
            .register(meterRegistry)
            .increment();

        sample.stop(Timer.builder(METRIC_PREFIX + ".job.duration")
            .description("Job execution duration")
            .tag("job", jobName)
            .tag("status", "success")
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry));
    }

    /**
     * Job 실패
     */
    public void recordJobFailure(String jobName, Timer.Sample sample, String errorType) {
        Counter.builder(METRIC_PREFIX + ".job.failure.total")
            .description("Failed job executions")
            .tag("job", jobName)
            .tag("error", errorType)
            .register(meterRegistry)
            .increment();

        sample.stop(Timer.builder(METRIC_PREFIX + ".job.duration")
            .description("Job execution duration")
            .tag("job", jobName)
            .tag("status", "failure")
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(meterRegistry));
    }

    /**
     * Job 처리 항목 수 기록
     */
    public void recordJobItemsProcessed(String jobName, int count) {
        Counter.builder(METRIC_PREFIX + ".job.items.processed")
            .description("Number of items processed by job")
            .tag("job", jobName)
            .register(meterRegistry)
            .increment(count);
    }
}
```

### 6.2 사용 예시

```java
@Component
@RequiredArgsConstructor
public class OutboxRetryScheduler {

    private static final String JOB_NAME = "outbox-retry";

    private final SchedulerMetrics metrics;
    private final MeterRegistry meterRegistry;

    @Scheduled(fixedRate = 300000)
    public void retryUnpublishedOutboxes() {
        Timer.Sample sample = metrics.startJob(JOB_NAME);

        try {
            int processed = doRetry();
            metrics.recordJobItemsProcessed(JOB_NAME, processed);
            metrics.recordJobSuccess(JOB_NAME, sample);

        } catch (Exception e) {
            metrics.recordJobFailure(JOB_NAME, sample, e.getClass().getSimpleName());
            throw e;
        }
    }
}
```

### 6.3 Grafana 쿼리 예시

```promql
# Job 성공률
sum(rate(scheduler_job_success_total[5m])) by (job)
/ sum(rate(scheduler_job_runs_total[5m])) by (job)

# Job 평균 실행 시간
rate(scheduler_job_duration_seconds_sum[5m])
/ rate(scheduler_job_duration_seconds_count[5m])

# Job 실패 알림 (5분간 3회 이상 실패)
sum(increase(scheduler_job_failure_total[5m])) by (job) > 3
```

---

## 7. 구조화된 로깅

### 7.1 Logback JSON 설정

**`src/main/resources/logback-spring.xml`**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

    <!-- JSON Encoder for Production -->
    <springProfile name="prod">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <!-- 기본 필드 -->
                <includeMdcKeyName>traceId</includeMdcKeyName>
                <includeMdcKeyName>spanId</includeMdcKeyName>
                <includeMdcKeyName>requestId</includeMdcKeyName>
                <includeMdcKeyName>userId</includeMdcKeyName>
                <includeMdcKeyName>organizationId</includeMdcKeyName>

                <!-- 커스텀 필드 -->
                <customFields>{"application":"${spring.application.name}","environment":"${SPRING_PROFILES_ACTIVE}"}</customFields>

                <!-- 타임스탬프 포맷 -->
                <timestampPattern>yyyy-MM-dd'T'HH:mm:ss.SSSZ</timestampPattern>
            </encoder>
        </appender>

        <root level="INFO">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>

    <!-- Console Pattern for Local/Dev -->
    <springProfile name="local,dev,test">
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss.SSS} [%thread] [%X{traceId:-}] %-5level %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>

        <root level="DEBUG">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>

</configuration>
```

### 7.2 MDC 설정 Filter

```java
public class TracingMdcFilter extends OncePerRequestFilter {

    private static final String TRACE_ID = "traceId";
    private static final String SPAN_ID = "spanId";
    private static final String REQUEST_ID = "requestId";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain chain) throws ServletException, IOException {

        try {
            // Request ID 설정 (X-Request-Id 헤더 또는 생성)
            String requestId = request.getHeader("X-Request-Id");
            if (requestId == null || requestId.isBlank()) {
                requestId = UUID.randomUUID().toString().substring(0, 8);
            }
            MDC.put(REQUEST_ID, requestId);

            // OpenTelemetry에서 traceId, spanId 자동 설정됨 (Agent 사용 시)
            // 수동 설정 필요 시:
            Span currentSpan = Span.current();
            if (currentSpan.getSpanContext().isValid()) {
                MDC.put(TRACE_ID, currentSpan.getSpanContext().getTraceId());
                MDC.put(SPAN_ID, currentSpan.getSpanContext().getSpanId());
            }

            chain.doFilter(request, response);

        } finally {
            MDC.remove(TRACE_ID);
            MDC.remove(SPAN_ID);
            MDC.remove(REQUEST_ID);
        }
    }
}
```

### 7.3 출력 예시 (JSON)

```json
{
  "@timestamp": "2024-01-15T10:30:45.123+0900",
  "level": "INFO",
  "logger_name": "c.r.f.service.DownloadService",
  "message": "Download completed successfully",
  "application": "fileflow-worker",
  "environment": "prod",
  "traceId": "abc123def456",
  "spanId": "789xyz",
  "requestId": "req-001",
  "userId": "user@example.com",
  "organizationId": "12345"
}
```

---

## 8. OpenTelemetry 통합

### 8.1 ADOT Agent vs ADOT Collector 이해

OpenTelemetry 기반 모니터링은 **Agent**와 **Collector** 두 가지 구성요소로 나뉩니다:

```
┌─────────────────────────────────────────────────────────────────────┐
│                           ECS Task                                   │
│  ┌─────────────────────┐         ┌─────────────────────┐           │
│  │   Application       │         │   ADOT Collector    │           │
│  │   Container         │         │   (Sidecar)         │           │
│  │                     │         │                     │           │
│  │  ┌───────────────┐  │  OTLP   │  ┌───────────────┐  │           │
│  │  │ Spring Boot   │  │  :4317  │  │  Receivers    │  │           │
│  │  │ Application   │──┼────────▶│  │  (OTLP)       │  │           │
│  │  └───────────────┘  │         │  └───────┬───────┘  │           │
│  │         │           │         │          │          │           │
│  │  ┌──────▼────────┐  │         │  ┌───────▼───────┐  │           │
│  │  │ ADOT Agent    │  │         │  │  Processors   │  │           │
│  │  │ (javaagent)   │  │         │  │  (Batch, etc) │  │           │
│  │  │               │  │         │  └───────┬───────┘  │           │
│  │  │ - 메트릭 수집 │  │         │          │          │           │
│  │  │ - 트레이스 수집│  │         │  ┌───────▼───────┐  │           │
│  │  │ - 자동 계측   │  │         │  │  Exporters    │──┼──────────▶│
│  │  └───────────────┘  │         │  │  - X-Ray      │  │    AWS    │
│  │                     │         │  │  - CloudWatch │  │  Services │
│  └─────────────────────┘         │  │               │  │           │
│                                   │  └───────────────┘  │           │
│                                   └─────────────────────┘           │
└─────────────────────────────────────────────────────────────────────┘
```

| 구성요소 | 역할 | 실행 방식 | 상태 |
|----------|------|-----------|------|
| **ADOT Agent** | 애플리케이션 계측 (데이터 수집) | `-javaagent` JVM 옵션 | ✅ 적용됨 |
| **ADOT Collector** | 데이터 수신/처리/AWS 전송 | Sidecar 컨테이너 | ✅ 적용됨 |

#### 현재 상태 (2024-11)

- **ADOT Agent**: ✅ 모든 서비스에 적용됨 (`aws-opentelemetry-agent.jar`)
- **ADOT Collector**: ✅ ECS Task Definition에 sidecar로 배포됨
- **OTLP Exporter**: ✅ 활성화 (`otlp` 설정)

```dockerfile
# 현재 Dockerfile 설정 (OTLP 활성화)
ENV OTEL_METRICS_EXPORTER="otlp"   # Collector로 메트릭 전송
ENV OTEL_TRACES_EXPORTER="otlp"    # Collector로 트레이스 전송
ENV OTEL_LOGS_EXPORTER="none"      # 로그는 CloudWatch Logs 직접 사용
```

#### Collector 설정 (ECS Task Definition)

```yaml
# otel-collector 컨테이너 설정
receivers:
  otlp:
    protocols:
      grpc: 0.0.0.0:4317
      http: 0.0.0.0:4318

exporters:
  awsxray:      # Traces → AWS X-Ray
  awsemf:       # Metrics → CloudWatch EMF
```

> **참고**: 컨테이너 시작 순서에 따라 초기 timeout이 발생할 수 있습니다.
> `dependsOn` 설정으로 otel-collector가 먼저 시작되도록 하면 해결됩니다.

### 8.2 Dockerfile 설정 (현재)

```dockerfile
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# AWS ADOT Agent 다운로드
ADD https://github.com/aws-observability/aws-otel-java-instrumentation/releases/latest/download/aws-opentelemetry-agent.jar /app/aws-opentelemetry-agent.jar

COPY app.jar app.jar

# JVM 옵션
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
ENV OTEL_AGENT_OPTS="-javaagent:/app/aws-opentelemetry-agent.jar"

# OpenTelemetry 환경변수
ENV OTEL_SERVICE_NAME="my-service"
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"

# OTLP Exporters - ECS Task에 otel-collector sidecar 배포됨
ENV OTEL_METRICS_EXPORTER="otlp"
ENV OTEL_TRACES_EXPORTER="otlp"
ENV OTEL_LOGS_EXPORTER="none"

ENV OTEL_PROPAGATORS="xray,tracecontext,baggage"
ENV OTEL_RESOURCE_ATTRIBUTES="service.namespace=fileflow"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS $OTEL_AGENT_OPTS -jar app.jar"]
```

### 8.3 ADOT Collector 추가 방법 (향후 작업)

Collector를 추가하려면 ECS Task Definition에 sidecar 컨테이너를 추가해야 합니다:

#### Step 1: ECS Task Definition에 ADOT Collector Sidecar 추가

```json
{
  "containerDefinitions": [
    {
      "name": "app",
      "image": "your-ecr-repo/fileflow-api:latest",
      "essential": true,
      "environment": [
        { "name": "OTEL_SERVICE_NAME", "value": "fileflow-api" },
        { "name": "OTEL_EXPORTER_OTLP_ENDPOINT", "value": "http://localhost:4317" },
        { "name": "OTEL_METRICS_EXPORTER", "value": "otlp" },
        { "name": "OTEL_TRACES_EXPORTER", "value": "otlp" },
        { "name": "OTEL_RESOURCE_ATTRIBUTES", "value": "service.namespace=fileflow,deployment.environment=prod" }
      ],
      "dependsOn": [
        { "containerName": "otel-collector", "condition": "START" }
      ]
    },
    {
      "name": "otel-collector",
      "image": "amazon/aws-otel-collector:latest",
      "essential": false,
      "command": ["--config=/etc/ecs/ecs-default-config.yaml"],
      "portMappings": [
        { "containerPort": 4317, "protocol": "tcp" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/fileflow-otel-collector",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "otel"
        }
      }
    }
  ]
}
```

#### Step 2: ADOT Collector 설정 파일

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

exporters:
  awsxray:
    region: ap-northeast-2

  prometheusremotewrite:
    endpoint: "https://aps-workspaces.ap-northeast-2.amazonaws.com/api/v1/remote_write"
    auth:
      authenticator: sigv4auth

extensions:
  sigv4auth:
    region: ap-northeast-2
    service: aps

service:
  extensions: [sigv4auth]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [awsxray]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheusremotewrite]
```

#### Step 3: Dockerfile OTLP 활성화

Collector 배포 후 Dockerfile에서 exporter를 활성화합니다:

```dockerfile
# OTLP Exporter 활성화 (Collector 배포 후)
ENV OTEL_METRICS_EXPORTER="otlp"
ENV OTEL_TRACES_EXPORTER="otlp"
ENV OTEL_LOGS_EXPORTER="none"
```

#### 데이터 흐름 (Collector 활성화 시)

```
Spring Boot App (ADOT Agent)
       │
       │ OTLP (gRPC :4317)
       ▼
ADOT Collector (Sidecar)
       │
       ├──▶ AWS X-Ray (Traces)
       ├──▶ Amazon Managed Prometheus (Metrics)
       └──▶ CloudWatch Logs (선택적)
```

### 8.4 AWS 사전 준비사항

ADOT Collector 사용을 위한 AWS 리소스:

| 리소스 | 용도 | 필요 여부 |
|--------|------|-----------|
| **AWS X-Ray** | 분산 트레이싱 | 선택 |
| **Amazon Managed Prometheus** | 메트릭 저장 | 선택 |
| **IAM Role** | Collector 권한 | 필수 |

필요한 IAM 권한:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "aps:RemoteWrite"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 9. Grafana 대시보드

### 9.1 권장 대시보드 구성

| 대시보드 | 주요 패널 |
|----------|----------|
| **API Overview** | QPS, Error Rate, Latency (p50/p95/p99) |
| **JVM Metrics** | Heap, GC, Threads, CPU |
| **HikariCP** | Active/Idle Connections, Timeout |
| **Downstream** | Redis/DB/S3 Latency by operation |
| **Scheduler** | Job Success Rate, Duration, Items Processed |
| **SQS** | Queue Depth, Message Age, DLQ Count |

### 9.2 핵심 쿼리 모음

```promql
# 서비스별 QPS
sum(rate(http_server_requests_seconds_count[5m])) by (application)

# Error Rate (5xx)
sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
/ sum(rate(http_server_requests_seconds_count[5m]))

# p99 Latency
histogram_quantile(0.99, sum(rate(http_server_requests_seconds_bucket[5m])) by (le, application))

# HikariCP Active Connections
hikaricp_connections_active{application="fileflow-api"}

# Downstream 평균 Latency
avg by (operation) (rate(downstream_redis_latency_seconds_sum[5m]) / rate(downstream_redis_latency_seconds_count[5m]))
```

---

## 10. 체크리스트

### 10.1 필수 (P0)

- [ ] `management.metrics.tags.application` 서비스별 설정
- [ ] `/actuator/prometheus` 엔드포인트 노출
- [ ] Security에서 prometheus 엔드포인트 허용
- [ ] HikariCP 메트릭 활성화

### 10.2 중요 (P1)

- [ ] 커스텀 비즈니스 메트릭 구현
- [ ] Downstream latency 메트릭 (Redis, DB, S3)
- [ ] Scheduler job 메트릭
- [ ] 구조화된 로그 (JSON + traceId)

### 10.3 권장 (P2)

- [ ] OpenTelemetry Agent 연동
- [ ] otel-collector X-Ray export
- [ ] Grafana 대시보드 구축
- [ ] 알림 규칙 설정

---

## 부록: 참고 자료

- [Spring Boot Actuator Docs](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Micrometer Docs](https://micrometer.io/docs)
- [OpenTelemetry Java Agent](https://opentelemetry.io/docs/instrumentation/java/automatic/)
- [AWS ADOT](https://aws-otel.github.io/docs/getting-started/java-sdk)
