# 모니터링 스택 통합 전략

> 작성일: 2026-01-09
> 관련 프로젝트: infrastructure, observability-spring-boot-starter

---

## 1. 개요

### 1.1 현황 분석

현재 모니터링 스택 구성:

| 도구 | 역할 | 현재 상태 |
|------|------|----------|
| **AMP (Prometheus)** | 메트릭 수집/저장 | 운영 중 |
| **AMG (Grafana)** | 시각화/대시보드 | 운영 중 |
| **OpenSearch** | 로그 저장/검색 | 운영 중 (t3.small - 성능 이슈) |
| **Sentry** | 에러 추적/알림 | 운영 중 (SDK 연동 필요) |

### 1.2 해결해야 할 문제

1. **traceId 연결 불가**: Sentry 에러 → OpenSearch 로그 추적이 안됨
2. **OpenSearch 성능 이슈**: t3.small 인스턴스로 JVM Memory Pressure 70-75%
3. **로그 포맷 비일관성**: 서비스별 로그 포맷이 달라 통합 검색 어려움
4. **Sentry-Grafana 통합 불가**: AMG에서 Sentry 플러그인 미지원

---

## 2. 목표 아키텍처

### 2.1 역할 분리 원칙

```
┌─────────────────────────────────────────────────────────────────────┐
│                    모니터링 스택 역할 분리                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│  │   Metrics   │     │    Logs     │     │   Errors    │           │
│  │  (숫자/차트) │     │  (텍스트)   │     │  (예외/스택) │           │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘           │
│         │                   │                   │                   │
│         ▼                   ▼                   ▼                   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│  │     AMP     │     │ OpenSearch  │     │   Sentry    │           │
│  │ (Prometheus)│     │   (Logs)    │     │  (Errors)   │           │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘           │
│         │                   │                   │                   │
│         └───────────┬───────┘                   │                   │
│                     ▼                           │                   │
│              ┌─────────────┐                    │                   │
│              │     AMG     │◄───────────────────┘                   │
│              │  (Grafana)  │  별도 알림 채널                         │
│              └──────┬──────┘                                        │
│                     │                                               │
│                     ▼                                               │
│              ┌─────────────┐                                        │
│              │    Slack    │  통합 알림 채널                         │
│              └─────────────┘                                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 도구별 역할 정의

| 도구 | 담당 데이터 | 사용 목적 | 알림 채널 |
|------|------------|----------|----------|
| **AMP** | CPU, Memory, Latency, Request Rate | 인프라/애플리케이션 메트릭 | AMG → Slack |
| **OpenSearch** | Application Logs, Access Logs | 로그 검색/분석, 트러블슈팅 | AMG → Slack |
| **Sentry** | Exceptions, Stack Traces | 에러 추적, 릴리즈 모니터링 | Sentry → Slack |
| **AMG** | 위 데이터 통합 시각화 | 통합 대시보드, 알림 라우팅 | - |

---

## 3. 핵심: traceId 연결 전략

### 3.1 문제 상황

```
현재: traceId 연결 안됨
┌─────────────┐               ┌─────────────┐
│ Sentry 에러  │  ────❌────→  │ OpenSearch  │
│ traceId: ?  │               │ 검색 불가    │
└─────────────┘               └─────────────┘
```

### 3.2 해결: observability-spring-boot-starter SDK

```
SDK 적용 후: traceId 일관성 보장
┌─────────────┐               ┌─────────────┐
│ Sentry 에러  │  ────✅────→  │ OpenSearch  │
│ traceId:abc │               │ traceId:abc │
└─────────────┘               └─────────────┘
```

### 3.3 데이터 흐름

```
[HTTP 요청] ─────→ [SDK TraceIdFilter]
                        │
                        ▼
                 ┌─────────────┐
                 │    MDC      │  traceId, userId, tenantId
                 └──────┬──────┘
                        │
       ┌────────────────┼────────────────┐
       ▼                ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Logback    │  │   Sentry    │  │  WebClient  │
│  (JSON)     │  │  Appender   │  │  (전파)     │
└──────┬──────┘  └──────┬──────┘  └──────┬──────┘
       │                │                │
       ▼                ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ OpenSearch  │  │   Sentry    │  │ 다음 서비스 │
└─────────────┘  └─────────────┘  └─────────────┘
```

### 3.4 운영 플로우

```
1. Sentry Alert 수신
   ↓
2. Sentry 이벤트에서 traceId 확인
   - Tags: traceId=abc-123
   ↓
3. OpenSearch에서 traceId로 검색
   GET logs-*/_search
   { "query": { "term": { "traceId": "abc-123" } } }
   ↓
4. 전체 요청 흐름 로그 확인
   - Gateway → API → Worker 순서대로 추적
   ↓
5. 에러 원인 파악 및 수정
```

---

## 4. SDK 적용 가이드

### 4.1 의존성 추가

```groovy
// build.gradle
dependencies {
    // Observability 전체 스택
    implementation libs.bundles.observability.full
}
```

**libs.versions.toml:**
```toml
[versions]
observabilityStarter = "v1.2.0"
sentry = "8.29.0"
logstashLogback = "7.4"

[libraries]
observability-starter = { module = "com.github.ryu-qqq:observability-spring-boot-starter", version.ref = "observabilityStarter" }
sentry-spring-boot = { module = "io.sentry:sentry-spring-boot-starter-jakarta", version.ref = "sentry" }
sentry-logback = { module = "io.sentry:sentry-logback", version.ref = "sentry" }
logstash-logback-encoder = { module = "net.logstash.logback:logstash-logback-encoder", version.ref = "logstashLogback" }

[bundles]
observability-full = [
    "observability-starter",
    "sentry-spring-boot",
    "sentry-logback",
    "logstash-logback-encoder"
]
```

### 4.2 application.yml 설정

```yaml
# Sentry 설정
sentry:
  dsn: ${SENTRY_DSN:}
  environment: ${SPRING_PROFILES_ACTIVE:local}
  release: ${APP_VERSION:unknown}
  traces-sample-rate: ${SENTRY_TRACES_SAMPLE_RATE:0.1}
  logging:
    minimum-event-level: error
    minimum-breadcrumb-level: info

# Observability SDK 설정
observability:
  service-name: ${spring.application.name}
  trace:
    include-in-response: true
  http:
    enabled: true
    exclude-paths:
      - /actuator/**
      - /health
```

### 4.3 Logback 설정

```xml
<!-- logback-spring.xml -->
<configuration>
    <!-- Sentry Appender -->
    <appender name="SENTRY" class="io.sentry.logback.SentryAppender">
        <filter class="ch.qos.logback.classic.filter.ThresholdFilter">
            <level>ERROR</level>
        </filter>
        <minimumBreadcrumbLevel>INFO</minimumBreadcrumbLevel>
        <minimumEventLevel>ERROR</minimumEventLevel>
    </appender>

    <!-- JSON Appender (Production) -->
    <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
        <encoder class="net.logstash.logback.encoder.LogstashEncoder">
            <includeMdcKeyName>traceId</includeMdcKeyName>
            <includeMdcKeyName>userId</includeMdcKeyName>
            <includeMdcKeyName>tenantId</includeMdcKeyName>
        </encoder>
    </appender>

    <springProfile name="prod,production">
        <root level="INFO">
            <appender-ref ref="JSON"/>
            <appender-ref ref="SENTRY"/>
        </root>
    </springProfile>
</configuration>
```

---

## 5. 인프라 개선 사항

### 5.1 OpenSearch 사양 업그레이드

**현재 문제:**
- 인스턴스: t3.small.search (2GB RAM, JVM 1GB)
- JVM Memory Pressure: 70-75% (위험 경계)
- 어제 오후 접속 불가 발생

**개선 계획:**
| 항목 | 현재 | 변경 |
|------|------|------|
| Instance Type | t3.small.search | t3.medium.search |
| Instance Count | 1 | 2 (권장) |
| Zone Awareness | disabled | enabled |
| Storage | 20GB gp3 | 50GB gp3 |

**Terraform 관리:**
- 현재: 콘솔에서 생성, data source로 참조만
- 변경: Terraform 리소스로 관리하도록 추가

### 5.2 AMG 데이터소스 구성

**현재 구성:**
- [x] AMP (Prometheus) 연결됨
- [x] CloudWatch 연결됨
- [x] X-Ray 연결됨
- [x] OpenSearch 연결됨

**Sentry 통합:**
- AMG에서 Sentry 플러그인 미지원
- 대안: Sentry는 별도 알림 채널로 운영

---

## 6. 알림 채널 정리

### 6.1 채널별 알림 분류

| 채널 | 소스 | 알림 유형 |
|------|------|----------|
| `#alerts-critical` | Sentry, AMG | 즉시 대응 필요 (500 에러, 서비스 다운) |
| `#alerts-warning` | AMG | 모니터링 필요 (CPU 80%, Memory 85%) |
| `#alerts-info` | AMG | 정보성 (배포 완료, 스케일링 이벤트) |

### 6.2 알림 규칙

**Critical (즉시 대응):**
- Sentry: ERROR 레벨 이벤트
- AMG: 서비스 헬스체크 실패, 5xx 에러율 > 1%

**Warning (모니터링):**
- AMG: CPU > 80%, Memory > 85%, Latency P95 > 1s
- OpenSearch: JVM Memory Pressure > 75%

---

## 7. 적용 로드맵

### Phase 1: 인프라 (이번 주)
- [x] AMG에 OpenSearch 데이터소스 추가
- [ ] OpenSearch t3.medium 업그레이드
- [ ] Stage RDS 프로비저닝 완료

### Phase 2: SDK 적용 (다음 주)
- [ ] connectly-gateway SDK 적용
- [ ] 각 서비스별 SDK 적용 상태 평가
- [ ] Sentry 컨텍스트 강화

### Phase 3: 대시보드/알림 (2주 후)
- [ ] AMG 통합 대시보드 구성
- [ ] 알림 채널 정리 및 라우팅 설정
- [ ] 운영 가이드 문서화

---

## 8. 관련 문서

- [observability-spring-boot-starter SDK](https://github.com/ryu-qqq/observability-spring-boot-starter)
- [SDK 통합 표준](https://github.com/ryu-qqq/observability-spring-boot-starter/blob/main/docs/standards/sdk-integration-standard.md)
- [Sentry 통합 표준](https://github.com/ryu-qqq/observability-spring-boot-starter/blob/main/docs/standards/sentry-integration-standard.md)
- [Logging 표준](https://github.com/ryu-qqq/observability-spring-boot-starter/blob/main/docs/standards/logging-standard.md)
