# AMP/AMG 기반 모니터링 시스템 아키텍처

## 개요

Amazon Managed Prometheus (AMP)와 Amazon Managed Grafana (AMG)를 사용하여 ECS, RDS, ALB 리소스를 모니터링하는 중앙 관측성 시스템을 구축합니다.

## 아키텍처 구성요소

### 1. Amazon Managed Prometheus (AMP)
- **역할**: 메트릭 저장소 및 쿼리 엔진
- **구성**: 단일 workspace (환경별로 분리 가능)
- **데이터 보존**: 기본 150일 (조정 가능)

### 2. Amazon Managed Grafana (AMG)
- **역할**: 시각화 및 대시보드 플랫폼
- **구성**: 단일 workspace
- **인증**: AWS IAM Identity Center 또는 SAML

### 3. AWS Distro for OpenTelemetry (ADOT) Collector
- **역할**: 메트릭 수집 및 AMP로 전송
- **배포 방식**: ECS 사이드카 컨테이너
- **수집 대상**:
  - ECS 컨테이너 메트릭 (CPU, Memory, Network)
  - 애플리케이션 메트릭 (Custom metrics)

### 4. CloudWatch 통합
- **RDS 메트릭**: CloudWatch → AMP 연동
- **ALB 메트릭**: CloudWatch → AMP 연동
- **방식**: CloudWatch Metric Streams 또는 Prometheus CloudWatch Exporter

## 데이터 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                       Data Collection                        │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐     ┌──────────────┐
│  ECS Tasks   │      │     RDS      │     │     ALB      │
│              │      │              │     │              │
│ ADOT         │      │ CloudWatch   │     │ CloudWatch   │
│ Collector    │      │ Metrics      │     │ Metrics      │
└──────┬───────┘      └──────┬───────┘     └──────┬───────┘
       │                     │                     │
       │ Remote Write        │                     │
       └─────────────────────┼─────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  Amazon Managed │
                    │   Prometheus    │
                    │   (Workspace)   │
                    └────────┬────────┘
                             │
                             │ Query
                             ▼
                    ┌─────────────────┐
                    │  Amazon Managed │
                    │     Grafana     │
                    │   (Workspace)   │
                    └─────────────────┘
```

## IAM 권한 구조

### 1. AMP Write 권한 (ECS Tasks)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "aps:RemoteWrite",
        "aps:GetSeries",
        "aps:GetLabels",
        "aps:GetMetricMetadata"
      ],
      "Resource": "arn:aws:aps:region:account:workspace/workspace-id"
    }
  ]
}
```

### 2. AMG Data Source 권한
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "aps:ListWorkspaces",
        "aps:DescribeWorkspace",
        "aps:QueryMetrics",
        "aps:GetLabels",
        "aps:GetSeries",
        "aps:GetMetricMetadata"
      ],
      "Resource": "*"
    }
  ]
}
```

### 3. CloudWatch 읽기 권한 (선택사항)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:GetMetricData"
      ],
      "Resource": "*"
    }
  ]
}
```

## ADOT Collector 구성

### ECS Task Definition 예시
```json
{
  "containerDefinitions": [
    {
      "name": "app",
      "image": "app-image:latest",
      "portMappings": [{"containerPort": 8080}]
    },
    {
      "name": "adot-collector",
      "image": "public.ecr.aws/aws-observability/aws-otel-collector:latest",
      "environment": [
        {
          "name": "AOT_CONFIG_CONTENT",
          "value": "base64-encoded-config"
        }
      ]
    }
  ]
}
```

### ADOT Config (prometheus-config.yaml)
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
    endpoint: "https://aps-workspaces.region.amazonaws.com/workspaces/workspace-id/api/v1/remote_write"
    auth:
      authenticator: sigv4auth

extensions:
  sigv4auth:
    region: ap-northeast-2
    service: aps

service:
  extensions: [sigv4auth]
  pipelines:
    metrics:
      receivers: [prometheus]
      exporters: [prometheusremotewrite]
```

## 메트릭 수집 전략

### 1. ECS 메트릭
**수집 방법**: ADOT Collector 사이드카

**주요 메트릭**:
- `container_cpu_usage_seconds_total`: CPU 사용량
- `container_memory_usage_bytes`: 메모리 사용량
- `container_network_receive_bytes_total`: 네트워크 수신
- `container_network_transmit_bytes_total`: 네트워크 전송

### 2. RDS 메트릭
**수집 방법**: CloudWatch Metrics → AMP

**주요 메트릭**:
- `CPUUtilization`: CPU 사용률
- `DatabaseConnections`: 데이터베이스 연결 수
- `FreeableMemory`: 사용 가능한 메모리
- `ReadLatency` / `WriteLatency`: 읽기/쓰기 지연시간
- `ReadIOPS` / `WriteIOPS`: 읽기/쓰기 IOPS

### 3. ALB 메트릭
**수집 방법**: CloudWatch Metrics → AMP

**주요 메트릭**:
- `RequestCount`: 요청 수
- `TargetResponseTime`: 대상 응답 시간
- `HTTPCode_Target_2XX_Count`: 2xx 응답 수
- `HTTPCode_Target_4XX_Count`: 4xx 응답 수
- `HTTPCode_Target_5XX_Count`: 5xx 응답 수
- `HealthyHostCount` / `UnHealthyHostCount`: 정상/비정상 호스트 수

## Grafana 대시보드 구성

### 1. System Overview Dashboard
- **목적**: 전체 시스템 상태 한눈에 파악
- **패널**:
  - ECS 클러스터 전체 리소스 사용률
  - RDS 연결 상태 및 성능
  - ALB 요청률 및 응답 시간
  - 전체 에러율

### 2. ECS Service Dashboard
- **목적**: ECS 서비스별 상세 모니터링
- **패널**:
  - 서비스별 CPU/Memory 사용률
  - 태스크 개수 및 상태
  - 네트워크 트래픽
  - 컨테이너 재시작 횟수

### 3. RDS Performance Dashboard
- **목적**: 데이터베이스 성능 모니터링
- **패널**:
  - CPU 및 메모리 사용률
  - 연결 수 및 대기 이벤트
  - 쿼리 지연시간
  - IOPS 및 처리량
  - 디스크 사용률

### 4. ALB Traffic Dashboard
- **목적**: 로드밸런서 트래픽 분석
- **패널**:
  - 요청률 (RPS)
  - 응답 시간 분포
  - HTTP 상태 코드별 분포
  - 타겟 그룹 헬스 체크 상태

## 비용 최적화 고려사항

### AMP 비용
- **메트릭 샘플 수집**: $0.0003/샘플
- **메트릭 저장**: $0.03/GB/월
- **쿼리 샘플 처리**: $0.00001/샘플

**예상 비용** (월간):
- 메트릭 수집: 약 100만 샘플/일 → $9
- 저장: 약 10GB → $0.3
- 쿼리: 약 500만 샘플/일 → $1.5
- **총합: 약 $11/월**

### AMG 비용
- **Editor 라이선스**: $9/사용자/월
- **Viewer 라이선스**: 무료 (처음 5명)

**예상 비용**: $9-18/월 (사용자 1-2명)

### 총 예상 비용
**$20-30/월** (초기 소규모 운영 기준)

## 보안 고려사항

### 1. 네트워크 보안
- AMP/AMG VPC 엔드포인트 사용 (프라이빗 통신)
- Security Group으로 접근 제어

### 2. 데이터 보안
- AMP 데이터 암호화 (저장/전송 모두)
- AMG HTTPS 통신 강제

### 3. 접근 제어
- IAM 역할 기반 권한 관리
- 최소 권한 원칙 적용
- AMG 사용자 인증 (SSO 권장)

## 구현 순서

1. ✅ 아키텍처 설계 문서 작성 (현재 단계)
2. AMP Workspace 생성 (Terraform)
3. AMG Workspace 생성 (Terraform)
4. IAM 역할 및 정책 생성
5. ADOT Collector ECS 사이드카 구성
6. CloudWatch 메트릭 연동 (RDS, ALB)
7. AMG 데이터 소스 설정
8. Grafana 대시보드 템플릿 생성
9. 테스트 및 검증
10. 운영 가이드 문서화

## 참고 자료

- [AWS Observability Best Practices](https://aws-observability.github.io/observability-best-practices/)
- [Amazon Managed Prometheus Documentation](https://docs.aws.amazon.com/prometheus/)
- [Amazon Managed Grafana Documentation](https://docs.aws.amazon.com/grafana/)
- [AWS Distro for OpenTelemetry](https://aws-otel.github.io/)
