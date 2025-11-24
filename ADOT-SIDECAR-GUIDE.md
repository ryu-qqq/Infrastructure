# ADOT Sidecar 모듈화 가이드

ECS Fargate 서비스에 AWS Distro for OpenTelemetry (ADOT) 사이드카를 추가하여 메트릭을 수집하는 방법.

---

## 1. 개요

### 왜 필요한가?

Spring Boot 애플리케이션의 `/actuator/prometheus` 엔드포인트에서 메트릭을 수집하여:
- **AMP (Amazon Managed Prometheus)**: 메트릭 저장
- **AMG (Amazon Managed Grafana)**: 시각화 및 대시보드

### 아키텍처

```
┌─────────────────────────────────────────────┐
│  ECS Task                                   │
│  ┌─────────────┐    ┌─────────────────┐     │
│  │ Spring Boot │    │ ADOT Sidecar    │     │
│  │ :8080       │───▶│ (Prometheus     │     │
│  │ /actuator/  │    │  scraper)       │     │
│  │ prometheus  │    └────────┬────────┘     │
│  └─────────────┘             │              │
└──────────────────────────────┼──────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Amazon Managed      │
                    │ Prometheus (AMP)    │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Amazon Managed      │
                    │ Grafana (AMG)       │
                    └─────────────────────┘
```

---

## 2. 사전 준비

### 2.1 AMP 워크스페이스 생성

```bash
aws amp create-workspace \
  --alias "prod-metrics" \
  --region ap-northeast-2
```

결과에서 `workspaceId` 확인 (예: `ws-df3ce6a3-a2b1-44a6-8fd3-3f698d75fcd8`)

### 2.2 OTEL Config 파일 생성

각 서비스별로 S3에 OTEL 설정 파일 업로드:

```
s3://connectly-prod/otel-config/{project}-{service}/otel-config.yaml
```

예시 config:

```yaml
# otel-config.yaml
extensions:
  health_check:
  sigv4auth:
    region: ap-northeast-2
    service: aps

receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: '{project}-{service}'  # 예: crawlinghub-web-api
          scrape_interval: 15s
          metrics_path: '/actuator/prometheus'
          static_configs:
            - targets: ['localhost:8080']

processors:
  batch:
    timeout: 30s
    send_batch_size: 1000
  resourcedetection:
    detectors:
      - env
      - ecs

exporters:
  prometheusremotewrite:
    endpoint: https://aps-workspaces.ap-northeast-2.amazonaws.com/workspaces/{workspace-id}/api/v1/remote_write
    auth:
      authenticator: sigv4auth

service:
  extensions: [health_check, sigv4auth]
  pipelines:
    metrics:
      receivers: [prometheus]
      processors: [batch, resourcedetection]
      exporters: [prometheusremotewrite]
```

**중요**: `job_name`을 서비스별로 다르게 설정해야 AMP에서 프로젝트/서비스 구분 가능.

### 2.3 S3 + CloudFront 설정

ADOT는 S3 URL을 직접 파싱하지 못함. **CloudFront CDN 필수**.

```
S3: s3://connectly-prod/otel-config/...
CDN: https://cdn.set-of.com/otel-config/...  ← ADOT는 이 URL 사용
```

---

## 3. Terraform 모듈 사용법

### 3.1 모듈 위치

```
terraform/modules/adot-sidecar/
├── main.tf          # 컨테이너 정의 및 IAM 정책
├── variables.tf     # 입력 변수
└── README.md        # 모듈 문서
```

### 3.2 ECS 모듈에서 사용

#### Step 1: 모듈 호출

```hcl
# ecs-web-api/main.tf

module "adot_sidecar" {
  source = "../modules/adot-sidecar"

  project_name      = var.project_name           # "crawlinghub"
  service_name      = "web-api"
  aws_region        = var.aws_region             # "ap-northeast-2"
  amp_workspace_arn = var.amp_workspace_arn      # AMP ARN
  log_group_name    = aws_cloudwatch_log_group.web_api.name

  # Optional (defaults provided)
  cdn_host      = "cdn.set-of.com"
  config_bucket = "connectly-prod"
  adot_cpu      = 256
  adot_memory   = 512
}
```

#### Step 2: Task Definition에 컨테이너 추가

```hcl
resource "aws_ecs_task_definition" "web_api" {
  family                   = "${var.project_name}-web-api-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  # 리소스 증가 (ADOT 포함)
  cpu    = var.web_api_cpu + 256    # ADOT CPU 추가
  memory = var.web_api_memory + 512  # ADOT Memory 추가

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    # 메인 애플리케이션 컨테이너
    {
      name  = "web-api"
      image = "${data.aws_ecr_repository.web_api.repository_url}:latest"
      # ... 기존 설정 ...
    },

    # ADOT 사이드카 추가
    module.adot_sidecar.container_definition
  ])
}
```

#### Step 3: Task Role에 IAM 정책 추가

```hcl
resource "aws_iam_role_policy" "adot_amp_access" {
  name   = "${var.project_name}-adot-amp-access-${var.environment}"
  role   = aws_iam_role.ecs_task.id
  policy = module.adot_sidecar.iam_policy_document
}
```

### 3.3 필수 Variables 추가

`provider.tf` 또는 `variables.tf`에 추가:

```hcl
variable "amp_workspace_arn" {
  description = "Amazon Managed Prometheus workspace ARN"
  type        = string
  default     = "arn:aws:aps:ap-northeast-2:646886795421:workspace/ws-df3ce6a3-a2b1-44a6-8fd3-3f698d75fcd8"
}
```

---

## 4. 체크리스트

### 배포 전 확인사항

- [ ] AMP 워크스페이스 생성됨
- [ ] OTEL config 파일이 S3에 업로드됨
- [ ] CloudFront에서 OTEL config 접근 가능
- [ ] Spring Boot에 Actuator Prometheus 활성화됨
  ```yaml
  management:
    endpoints:
      web:
        exposure:
          include: health,metrics,prometheus
    metrics:
      export:
        prometheus:
          enabled: true
  ```

### 배포 후 확인사항

- [ ] ECS Task에 2개 컨테이너 확인 (main + adot-collector)
- [ ] ADOT CloudWatch 로그에 에러 없음
- [ ] AMP에서 메트릭 수집 확인:
  ```bash
  # awscurl로 쿼리
  awscurl --service aps \
    "https://aps-workspaces.ap-northeast-2.amazonaws.com/workspaces/{workspace-id}/api/v1/query?query=up"
  ```

### 트러블슈팅

| 문제 | 원인 | 해결 |
|------|------|------|
| ADOT 시작 실패 | Config URL 접근 불가 | CloudFront URL 확인, S3 권한 확인 |
| 400 Bad Request (out of order) | 이전 배포의 타임스탬프 충돌 | 1-2분 대기 후 자동 해결 |
| 메트릭 없음 | Spring Boot Actuator 미활성화 | `management.endpoints.web.exposure.include` 설정 |
| AMP 인증 실패 | IAM 정책 누락 | Task Role에 `aps:RemoteWrite` 권한 추가 |

---

## 5. 다른 프로젝트에 적용

### 5.1 새 프로젝트 추가 시

1. **OTEL Config 업로드**
   ```bash
   aws s3 cp otel-config.yaml \
     s3://connectly-prod/otel-config/{new-project}-{service}/otel-config.yaml
   ```

2. **Terraform에서 모듈 사용** (위 3.2 참조)

3. **job_name 고유하게 설정** (AMP에서 구분용)

### 5.2 공유 리소스

| 리소스 | 값 | 비고 |
|--------|-----|------|
| AMP Workspace | `ws-df3ce6a3-a2b1-44a6-8fd3-3f698d75fcd8` | 모든 프로젝트 공유 |
| S3 Bucket | `connectly-prod` | OTEL configs 저장 |
| CDN Host | `cdn.set-of.com` | CloudFront 배포 |
| AMG Workspace | `prod-monitoring-infrastructure-observability` | 대시보드 공유 |

---

## 6. Grafana 설정

### 6.1 AMP 데이터 소스 추가

1. AMG → Connections → Add new data source
2. Type: **Prometheus**
3. URL: `https://aps-workspaces.ap-northeast-2.amazonaws.com/workspaces/{workspace-id}`
4. Authentication: **SigV4 auth**
   - Region: ap-northeast-2
   - Default Region: checked

### 6.2 유용한 PromQL 쿼리

```promql
# 서비스별 요청 수
sum(rate(http_server_requests_seconds_count{job="crawlinghub-web-api"}[5m])) by (uri)

# JVM 메모리 사용량
jvm_memory_used_bytes{job="crawlinghub-web-api", area="heap"}

# 활성 스레드
jvm_threads_live_threads{job="crawlinghub-web-api"}

# DB 커넥션 풀
hikaricp_connections_active{job="crawlinghub-web-api"}
```

---

## 7. 비용 고려사항

| 항목 | 예상 비용 | 비고 |
|------|----------|------|
| AMP 메트릭 수집 | ~$0.30/백만 샘플 | 15초 간격, 서비스당 |
| AMP 쿼리 | ~$0.10/십억 샘플 | 대시보드 사용량에 따라 |
| ADOT CPU/Memory | Task 리소스에 포함 | 256 CPU, 512 MiB |
| CloudWatch Logs | ~$0.50/GB | ADOT 로그 |

---

## 8. 참고 자료

- [AWS ADOT Documentation](https://aws-otel.github.io/docs/introduction)
- [Amazon Managed Prometheus](https://docs.aws.amazon.com/prometheus/)
- [Spring Boot Actuator Prometheus](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.metrics.export.prometheus)

---

**문의**: Platform Team / #infra-support
