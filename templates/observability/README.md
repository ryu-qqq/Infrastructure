# Observability Templates

Spring Boot 애플리케이션의 Observability (모니터링, 트레이싱, 로깅) 설정을 위한 템플릿 모음입니다.

## 포함 템플릿

### Dockerfile.otel

AWS ADOT (OpenTelemetry) Agent가 포함된 Dockerfile 템플릿입니다.

**특징:**
- AWS ADOT Agent 자동 다운로드 및 설정
- 컨테이너 최적화 JVM 옵션
- OpenTelemetry 환경변수 사전 설정
- non-root 사용자 실행 (보안)
- 헬스체크 포함

## 사용법

### 1. 템플릿 복사

```bash
# 프로젝트 루트에서
cp /path/to/infrastructure/templates/observability/Dockerfile.otel ./Dockerfile
```

### 2. 변수 교체

Dockerfile에서 다음 변수들을 실제 값으로 교체합니다:

| 변수 | 설명 | 예시 |
|------|------|------|
| `${SERVICE_NAME}` | 서비스 이름 | `fileflow-web-api` |
| `${SERVICE_NAMESPACE}` | 서비스 네임스페이스 | `fileflow` |
| `${ENVIRONMENT}` | 환경 | `prod`, `staging`, `dev` |

또는 ECS Task Definition에서 환경변수로 오버라이드할 수 있습니다.

### 3. ECS Task Definition 설정

Dockerfile만으로는 완전한 Observability가 구성되지 않습니다. ECS Task Definition에 다음이 필요합니다:

#### OTEL Collector Sidecar

```json
{
  "containerDefinitions": [
    {
      "name": "app",
      "image": "your-ecr-repo/your-service:latest",
      "essential": true,
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
      ]
    }
  ]
}
```

#### Task Role 권한

[ecs-task-role-observability 모듈](../../terraform/modules/ecs-task-role-observability/README.md)을 사용하여 필요한 IAM 권한을 구성합니다:

```hcl
module "task_role" {
  source = "../../modules/ecs-task-role-observability"

  role_name    = "myservice-task-role-prod"
  environment  = "prod"
  service_name = "myservice"
  # ... 기타 설정

  enable_combined_observability_policy = true
  cloudwatch_metric_namespaces         = ["MyService"]
}
```

## 환경변수 설명

### 필수 설정

| 환경변수 | 설명 | 기본값 |
|----------|------|--------|
| `OTEL_SERVICE_NAME` | 서비스 식별자 (X-Ray에 표시됨) | `my-service` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTEL Collector 엔드포인트 | `http://localhost:4317` |

### Exporter 설정

| 환경변수 | 설명 | 권장값 |
|----------|------|--------|
| `OTEL_METRICS_EXPORTER` | 메트릭 내보내기 대상 | `otlp` |
| `OTEL_TRACES_EXPORTER` | 트레이스 내보내기 대상 | `otlp` |
| `OTEL_LOGS_EXPORTER` | 로그 내보내기 대상 | `none` (CloudWatch 직접 사용) |

### 고급 설정

| 환경변수 | 설명 | 기본값 |
|----------|------|--------|
| `OTEL_PROPAGATORS` | 컨텍스트 전파 방식 | `xray,tracecontext,baggage` |
| `OTEL_TRACES_SAMPLER` | 트레이스 샘플링 전략 | `always_on` |
| `OTEL_RESOURCE_ATTRIBUTES` | 추가 리소스 속성 | - |

## 샘플링 설정

프로덕션 환경에서는 트래픽에 따라 샘플링 비율을 조정하세요:

```dockerfile
# 10% 샘플링 (고트래픽 서비스)
ENV OTEL_TRACES_SAMPLER="parentbased_traceidratio"
ENV OTEL_TRACES_SAMPLER_ARG="0.1"

# 100% 샘플링 (저트래픽 서비스, 기본값)
ENV OTEL_TRACES_SAMPLER="always_on"
```

## 트러블슈팅

### 초기 Timeout 에러

컨테이너 시작 순서로 인해 OTEL Collector 연결 실패 시:

```
[otel.javaagent 2024-xx-xx] ERROR ... Failed to export spans.
The request could not be executed. Full error message: Connection refused
```

**해결**: `dependsOn` 설정으로 otel-collector가 먼저 시작되도록 설정

### 메트릭이 CloudWatch에 표시되지 않음

1. Task Role에 `cloudwatch:PutMetricData` 권한 확인
2. `cloudwatch_metric_namespaces`에 올바른 네임스페이스 설정 확인
3. OTEL Collector 로그 확인

### X-Ray 트레이스가 표시되지 않음

1. Task Role에 `xray:PutTraceSegments` 권한 확인
2. `OTEL_PROPAGATORS`에 `xray` 포함 확인
3. 샘플링 설정 확인

## 관련 문서

- [Spring Boot Monitoring Guide](../../spring-boot-monitoring-guide.md)
- [ECS Task Role Observability Module](../../terraform/modules/ecs-task-role-observability/README.md)
- [AWS ADOT Documentation](https://aws-otel.github.io/docs/introduction)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
