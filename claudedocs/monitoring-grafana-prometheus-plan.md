# Grafana + Prometheus 중앙 모니터링 시스템 구축 계획
# 멀티 서비스 환경 (5개 서비스 대상)

**업데이트 날짜**: 2025-10-13
**대상 서비스**: 5개 ECS 서비스 (Atlantis + 4개 추가)
**목적**: 확장 가능한 중앙 모니터링 플랫폼 구축

---

## 🎯 상황 재평가

### 새로운 요구사항
- **서비스 수**: 5개 (현재 1개 → 확장 예정)
- **관리 복잡도**: 높음 (멀티 서비스 통합 모니터링)
- **확장성**: 지속적 성장 예상
- **중앙화**: 통합 대시보드 필수

### 결론: **Grafana + Prometheus 추천으로 변경** ✅

**근거**:
1. ✅ 서비스 5개 → CloudWatch 대시보드 관리 복잡도 급증
2. ✅ 통합 대시보드로 전체 인프라 한눈에 파악 가능
3. ✅ 확장성 - 추가 서비스 통합 용이
4. ✅ 비용 효율 - 서비스당 대시보드 vs 통합 플랫폼
5. ✅ 고급 쿼리 - 서비스 간 상관 분석 가능

---

## 🏗️ 아키텍처 설계

### 전체 구조
```
┌─────────────────────────────────────────────────────────────┐
│                     AWS ECS Cluster                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Service 1 │  │Service 2 │  │Service 3 │  │Service 4 │   │
│  │Atlantis  │  │  API-1   │  │  API-2   │  │  Worker  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │              │             │          │
│       └─────────────┴──────────────┴─────────────┘          │
│                          │                                   │
│                          ↓                                   │
│              ┌─────────────────────┐                        │
│              │  Prometheus Server  │                        │
│              │  (ECS Fargate)      │                        │
│              │  - Service Discovery│                        │
│              │  - Metrics Storage  │                        │
│              │  - PromQL Engine    │                        │
│              └──────────┬──────────┘                        │
│                         │                                    │
│                         ↓                                    │
│              ┌─────────────────────┐                        │
│              │   Grafana Server    │                        │
│              │   (ECS Fargate)     │                        │
│              │   - Dashboards      │                        │
│              │   - Alerting        │                        │
│              │   - User Management │                        │
│              └──────────┬──────────┘                        │
│                         │                                    │
└─────────────────────────┼────────────────────────────────────┘
                          │
                          ↓
                    ┌───────────┐
                    │    ALB    │ (HTTPS)
                    └─────┬─────┘
                          │
                          ↓
                    ┌───────────┐
                    │   Users   │
                    └───────────┘

추가 통합:
├─ CloudWatch Exporter → CloudWatch 메트릭 수집
├─ AlertManager → Slack/PagerDuty 알림
└─ Loki (선택) → 로그 집계
```

---

## 📦 컴포넌트 상세 설계

### 1. Prometheus Server

#### 역할
- 모든 ECS 서비스에서 메트릭 수집 (Pull 방식)
- ECS Service Discovery 활용
- 시계열 데이터 저장 (15일 보관)
- PromQL 쿼리 엔진

#### 리소스 사이징 (5개 서비스 기준)
```terraform
resource "aws_ecs_task_definition" "prometheus" {
  family = "prometheus"

  cpu    = "1024"  # 1 vCPU
  memory = "2048"  # 2 GB

  # 메트릭 수: ~500개 (서비스당 100개 × 5)
  # 수집 주기: 15초
  # 저장 기간: 15일
  # 예상 스토리지: 10-20GB
}
```

#### 설정 예시 (prometheus.yml)
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # ECS Service Discovery
  - job_name: 'ecs-services'
    ec2_sd_configs:
      - region: ap-northeast-2
        port: 9090
        filters:
          - name: tag:monitoring
            values: ['prometheus']

  # CloudWatch Exporter
  - job_name: 'cloudwatch'
    static_configs:
      - targets: ['cloudwatch-exporter:9106']

  # 개별 서비스 메트릭
  - job_name: 'service-atlantis'
    static_configs:
      - targets: ['atlantis:9090']
        labels:
          service: 'atlantis'
          env: 'prod'

  - job_name: 'service-api-1'
    static_configs:
      - targets: ['api-1:9090']
        labels:
          service: 'api-1'
          env: 'prod'

  # ... (나머지 3개 서비스)
```

#### EFS 볼륨 (메트릭 데이터 저장)
```terraform
resource "aws_efs_file_system" "prometheus" {
  creation_token = "prometheus-data"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "prometheus-metrics-storage"
  }
}

# 예상 크기: 15-25GB (15일 보관)
```

---

### 2. Grafana Server

#### 역할
- 대시보드 시각화
- 알림 규칙 관리
- 사용자 인증 및 권한 관리
- 멀티 데이터 소스 통합

#### 리소스 사이징
```terraform
resource "aws_ecs_task_definition" "grafana" {
  family = "grafana"

  cpu    = "512"   # 0.5 vCPU
  memory = "1024"  # 1 GB

  # 사용자: <10명
  # 대시보드: ~20개
  # 동시 접속: <5명
}
```

#### 데이터 소스 설정
```yaml
apiVersion: 1

datasources:
  # Prometheus (메인)
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true

  # CloudWatch (보조)
  - name: CloudWatch
    type: cloudwatch
    jsonData:
      authType: default
      defaultRegion: ap-northeast-2
```

#### 주요 대시보드 (사전 구성)
1. **Infrastructure Overview** - 전체 서비스 상태
2. **ECS Cluster Dashboard** - 클러스터 리소스
3. **Service-Specific Dashboards** (×5) - 개별 서비스
4. **Application Performance** - 응답 시간, 에러율
5. **Cost Monitoring** - 리소스 사용 비용 추정

---

### 3. CloudWatch Exporter

#### 역할
- CloudWatch 메트릭을 Prometheus 포맷으로 변환
- ECS Container Insights 메트릭 수집
- ALB 메트릭 수집

#### 설정 예시
```yaml
# cloudwatch-exporter.yml
region: ap-northeast-2
metrics:
  # ECS 메트릭
  - aws_namespace: AWS/ECS
    aws_metric_name: CPUUtilization
    aws_dimensions: [ClusterName, ServiceName]
    aws_statistics: [Average]

  - aws_namespace: AWS/ECS
    aws_metric_name: MemoryUtilization
    aws_dimensions: [ClusterName, ServiceName]
    aws_statistics: [Average]

  # ALB 메트릭
  - aws_namespace: AWS/ApplicationELB
    aws_metric_name: TargetResponseTime
    aws_dimensions: [LoadBalancer, TargetGroup]
    aws_statistics: [Average, Maximum]
```

---

### 4. AlertManager (선택 - 고급 알림)

#### 역할
- Prometheus 알림 라우팅
- 알림 중복 제거 (Deduplication)
- 알림 그룹화 및 억제
- Slack/PagerDuty 통합

#### 설정 예시
```yaml
route:
  group_by: ['alertname', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack-critical'

  routes:
    - match:
        severity: critical
      receiver: 'slack-critical'

    - match:
        severity: warning
      receiver: 'slack-warning'

receivers:
  - name: 'slack-critical'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#alerts-critical'
        title: 'Critical Alert: {{ .GroupLabels.alertname }}'

  - name: 'slack-warning'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#alerts-warning'
```

---

## 💰 비용 상세 분석 (5개 서비스)

### AWS 인프라 비용

#### ECS Fargate
```
Prometheus Server:
- vCPU: 1.0 × $0.04048/hr = $29.15/월
- Memory: 2GB × $0.004445/hr = $6.40/월
- Subtotal: $35.55/월

Grafana Server:
- vCPU: 0.5 × $0.04048/hr = $14.58/월
- Memory: 1GB × $0.004445/hr = $3.20/월
- Subtotal: $17.78/월

CloudWatch Exporter:
- vCPU: 0.25 × $0.04048/hr = $7.29/월
- Memory: 512MB × $0.004445/hr = $1.60/월
- Subtotal: $8.89/월

ECS Fargate 총계: $62.22/월
```

#### 스토리지 (EFS)
```
Prometheus 메트릭 데이터:
- 크기: ~20GB (15일 보관)
- 비용: 20GB × $0.30/GB = $6.00/월

Grafana 설정 데이터:
- 크기: ~2GB
- 비용: 2GB × $0.30/GB = $0.60/월

EFS 총계: $6.60/월
```

#### Application Load Balancer
```
ALB (Grafana HTTPS 접근):
- 시간: 730hr × $0.0225/hr = $16.43/월
- LCU: ~5 LCU × $0.008 = ~$2.92/월

ALB 총계: $19.35/월
```

#### CloudWatch (유지)
```
기존 CloudWatch 로그 수집: $10-15/월
CloudWatch Exporter API 호출: $5-8/월

CloudWatch 총계: $15-23/월
```

#### 데이터 전송
```
VPC 내부 전송: 무료
ALB → 인터넷 (대시보드 접근): ~$2-5/월

데이터 전송 총계: $2-5/월
```

---

### 월별 총 비용 (5개 서비스 환경)

```
┌─────────────────────────────────────────────┐
│ 항목                     │ 월 비용          │
├─────────────────────────────────────────────┤
│ ECS Fargate (Prometheus) │ $35.55          │
│ ECS Fargate (Grafana)    │ $17.78          │
│ ECS Fargate (Exporter)   │ $8.89           │
│ EFS 스토리지             │ $6.60           │
│ Application Load Balancer│ $19.35          │
│ CloudWatch (유지)        │ $15-23          │
│ 데이터 전송              │ $2-5            │
├─────────────────────────────────────────────┤
│ 총 예상 비용             │ $105-116/월     │
└─────────────────────────────────────────────┘

서비스당 비용: $21-23/월 (5개 서비스 기준)
```

### CloudWatch 대시보드 대비 비용

```
5개 서비스 환경 비교:

CloudWatch 대시보드 (개별):
- 대시보드 × 5: $15/월
- CloudWatch Metrics: $20/월
- CloudWatch Alarms × 20: $8/월
- Log Insights 쿼리: $15/월
- 총: $58/월

Grafana + Prometheus:
- 총: $105-116/월

추가 비용: $47-58/월 (약 2배)
```

### ROI 분석

**추가 투자**: $47-58/월

**얻는 가치**:
1. ✅ **통합 대시보드** - 5개 서비스 한눈에
2. ✅ **시간 절약** - 주 5-10시간 (서비스당 1-2시간)
3. ✅ **고급 분석** - 서비스 간 상관 관계 파악
4. ✅ **확장성** - 추가 서비스 통합 용이
5. ✅ **커스터마이징** - 임원/팀별 대시보드

**Break-even 계산**:
- 시간 절약: 주 7시간 × 4주 = 월 28시간
- 개발자 시급: $15-20/시간
- 절감 가치: $420-560/월
- **ROI: 700-1000%** (투자 대비 수익)

---

## 🚀 구축 로드맵 (4주 계획)

### Week 1: 기반 인프라 구축
**목표**: Prometheus + Grafana 기본 설치

**작업**:
- [ ] EFS 볼륨 생성 (Prometheus 데이터)
- [ ] ECS Task Definition 작성 (Prometheus)
- [ ] ECS Task Definition 작성 (Grafana)
- [ ] ALB 설정 (HTTPS, Route53)
- [ ] IAM 역할 및 정책
- [ ] 보안 그룹 설정

**Terraform 코드**:
```bash
terraform/
├── monitoring/
│   ├── prometheus.tf      # Prometheus 설정
│   ├── grafana.tf         # Grafana 설정
│   ├── alb.tf             # Load Balancer
│   ├── efs.tf             # 스토리지
│   ├── iam.tf             # 권한
│   ├── security-groups.tf # 네트워크 보안
│   └── variables.tf       # 변수
```

**완료 기준**: Grafana UI 접근 가능 (https://grafana.yourdomain.com)

---

### Week 2: 서비스 통합 및 메트릭 수집
**목표**: 5개 서비스 메트릭 수집 설정

**작업**:
- [ ] Atlantis 서비스 메트릭 Exporter 추가
- [ ] 나머지 4개 서비스 Exporter 설정
- [ ] Prometheus Service Discovery 설정
- [ ] CloudWatch Exporter 구성
- [ ] 메트릭 수집 검증

**각 서비스별 작업**:
```yaml
# Task Definition에 추가
- name: metrics-exporter
  image: prom/cloudwatch-exporter:latest
  portMappings:
    - containerPort: 9106
  environment:
    - name: AWS_REGION
      value: ap-northeast-2
```

**완료 기준**: Prometheus UI에서 모든 서비스 메트릭 확인 가능

---

### Week 3: 대시보드 구축 및 알림 설정
**목표**: 핵심 대시보드 및 알림 완성

**대시보드 목록**:
1. **Infrastructure Overview** (전체)
   - 5개 서비스 상태 한눈에
   - CPU, 메모리, 네트워크 통합 뷰
   - 에러율 및 응답 시간

2. **ECS Cluster Monitoring**
   - 클러스터 리소스 사용률
   - 작업(Task) 상태
   - 오토스케일링 메트릭

3. **Service-Specific Dashboards** (×5)
   - 서비스별 상세 메트릭
   - 요청/응답 패턴
   - 에러 트레이싱

4. **Application Performance**
   - P50/P95/P99 레이턴시
   - 처리량 (RPS)
   - 에러율 추이

5. **Cost Estimation**
   - vCPU/메모리 사용 → 비용 추정
   - 서비스별 비용 분석

**알림 규칙**:
```yaml
# alerts/ecs-alerts.yml
groups:
  - name: ecs_alerts
    rules:
      - alert: HighCPUUsage
        expr: avg(ecs_cpu_utilization) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"

      - alert: ServiceDown
        expr: up{job="ecs-services"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.service }} is down"
```

**완료 기준**:
- 5개 대시보드 완성
- Slack 알림 동작 확인

---

### Week 4: 최적화 및 문서화
**목표**: 성능 튜닝, 백업, 운영 문서

**작업**:
- [ ] Prometheus 쿼리 성능 최적화
- [ ] Grafana 대시보드 리팩토링
- [ ] EFS 백업 설정 (AWS Backup)
- [ ] Disaster Recovery 계획
- [ ] 운영 매뉴얼 작성
- [ ] 팀 교육 (Grafana/PromQL)

**문서**:
1. 운영 매뉴얼 (Runbook)
2. 대시보드 사용 가이드
3. 알림 대응 절차
4. 장애 복구 절차
5. PromQL 치트시트

**완료 기준**:
- 팀원 독립적으로 대시보드 생성 가능
- 백업 및 복구 검증 완료

---

## 📊 성능 및 확장성

### 메트릭 수집 성능
```
서비스당 메트릭: ~100개
총 메트릭 수: 500개
수집 주기: 15초
초당 쿼리: 33 QPS

Prometheus 처리 능력: 10,000+ QPS
→ 여유율: 300배 (충분한 확장 여력)
```

### 스토리지 증가 예측
```
현재 (5개 서비스):
- 일일 증가: ~1GB
- 15일 보관: ~15GB
- 버퍼: 5GB
- 총 필요: 20GB

10개 서비스로 확장 시:
- 일일 증가: ~2GB
- 15일 보관: ~30GB
- 총 필요: 35GB

→ EFS 자동 확장, 추가 비용: $4.50/월
```

### 확장 시나리오
```
10개 서비스:
- Prometheus: 1.5 vCPU, 3GB 메모리
- 추가 비용: ~$25/월
- 서비스당 비용: $13/월 (더 저렴)

20개 서비스:
- Prometheus: 2 vCPU, 4GB 메모리
- 추가 비용: ~$60/월
- 서비스당 비용: $10.5/월 (규모의 경제)
```

---

## 🔐 보안 고려사항

### 네트워크 보안
```terraform
# Grafana 보안 그룹
resource "aws_security_group" "grafana" {
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["YOUR_OFFICE_IP/32"]  # VPN/Office IP만 허용
  }
}

# Prometheus 보안 그룹 (내부만)
resource "aws_security_group" "prometheus" {
  ingress {
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_services.id]
  }
}
```

### 인증 및 권한
```yaml
# Grafana 설정
auth:
  # AWS Cognito 또는 OAuth
  generic_oauth:
    enabled: true
    client_id: ${OAUTH_CLIENT_ID}
    client_secret: ${OAUTH_CLIENT_SECRET}
    scopes: openid profile email

  # 또는 기본 인증
  basic:
    enabled: true

# 역할 기반 접근 제어 (RBAC)
users:
  - email: admin@company.com
    role: Admin
  - email: dev@company.com
    role: Editor
  - email: viewer@company.com
    role: Viewer
```

### 데이터 보호
- **EFS 암호화**: 저장 데이터 암호화 (at-rest)
- **TLS/SSL**: ALB HTTPS 강제 (in-transit)
- **백업**: AWS Backup 일일 스냅샷
- **감사**: CloudTrail 로깅

---

## 🛠️ Terraform 구현 예시

### 디렉토리 구조
```
terraform/monitoring/
├── main.tf                    # 메인 설정
├── prometheus.tf              # Prometheus 서버
├── grafana.tf                 # Grafana 서버
├── cloudwatch-exporter.tf     # CloudWatch 통합
├── alb.tf                     # Load Balancer
├── efs.tf                     # 스토리지
├── iam.tf                     # IAM 역할/정책
├── security-groups.tf         # 보안 그룹
├── route53.tf                 # DNS
├── variables.tf               # 입력 변수
├── outputs.tf                 # 출력
├── configs/
│   ├── prometheus.yml         # Prometheus 설정
│   ├── grafana-datasources.yml# Grafana 데이터 소스
│   └── cloudwatch-exporter.yml# CloudWatch 설정
└── dashboards/
    ├── infrastructure.json    # 인프라 대시보드
    ├── ecs-cluster.json       # ECS 대시보드
    └── services.json          # 서비스 대시보드
```

### prometheus.tf 예시
```terraform
# EFS 볼륨
resource "aws_efs_file_system" "prometheus" {
  creation_token = "prometheus-data-${var.environment}"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "prometheus-data"
      Component = "monitoring"
    }
  )
}

# EFS 마운트 타겟
resource "aws_efs_mount_target" "prometheus" {
  count = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.prometheus.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs_prometheus.id]
}

# ECS Task Definition
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.prometheus_execution.arn
  task_role_arn            = aws_iam_role.prometheus_task.arn

  volume {
    name = "prometheus-data"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.prometheus.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049

      authorization_config {
        access_point_id = aws_efs_access_point.prometheus.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      essential = true

      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "prometheus-data"
          containerPath = "/prometheus"
          readOnly      = false
        }
      ]

      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--storage.tsdb.retention.time=15d",
        "--web.console.libraries=/usr/share/prometheus/console_libraries",
        "--web.console.templates=/usr/share/prometheus/consoles",
        "--web.enable-lifecycle"
      ]

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "prometheus"
        }
      }

      healthCheck = {
        command = [
          "CMD-SHELL",
          "wget -q --spider http://localhost:9090/-/healthy || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    var.common_tags,
    {
      Name      = "prometheus-task"
      Component = "monitoring"
    }
  )
}

# ECS Service
resource "aws_ecs_service" "prometheus" {
  name            = "prometheus-${var.environment}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.prometheus.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.prometheus.arn
  }

  tags = merge(
    var.common_tags,
    {
      Name      = "prometheus-service"
      Component = "monitoring"
    }
  )
}
```

---

## 📚 운영 가이드

### 일상 운영 작업

#### 대시보드 모니터링
```bash
# 매일 아침 확인
1. Infrastructure Overview 대시보드 열기
2. 전체 서비스 상태 확인 (녹색/빨간색)
3. 이상 메트릭 확인 (CPU >80%, 메모리 >85%)
4. 에러율 추이 확인 (목표: <1%)
```

#### 주간 리뷰
```bash
# 매주 금요일
1. Cost Estimation 대시보드 확인
2. 리소스 사용 트렌드 분석
3. 불필요한 리소스 식별
4. 다음 주 용량 계획
```

#### 월간 최적화
```bash
# 매월 첫 주
1. Prometheus 쿼리 성능 분석
2. 대시보드 사용 통계 확인
3. 안 쓰는 메트릭 제거
4. 스토리지 정리 (오래된 데이터)
```

### 장애 대응

#### Prometheus 다운
```bash
1. ECS 콘솔에서 Task 로그 확인
2. 스토리지 용량 확인 (df -h)
3. Task 재시작 (ECS Console)
4. 데이터 손실 체크 (메트릭 연속성)
```

#### Grafana 접근 불가
```bash
1. ALB 상태 확인
2. Route53 DNS 확인
3. 보안 그룹 규칙 검증
4. Grafana Task 로그 확인
```

#### 메트릭 수집 중단
```bash
1. Prometheus Targets 페이지 확인
2. 서비스 디스커버리 로그 체크
3. 네트워크 연결성 테스트 (telnet)
4. IAM 권한 확인
```

---

## 🎓 팀 교육 계획

### PromQL 기초 (2시간)
```promql
# 기본 쿼리
ecs_cpu_utilization

# 필터링
ecs_cpu_utilization{service="atlantis"}

# 집계
avg(ecs_cpu_utilization)

# 시간 범위
rate(http_requests_total[5m])

# 비교
ecs_cpu_utilization > 80
```

### 대시보드 생성 (1시간)
- 패널 추가
- 쿼리 작성
- 시각화 옵션
- 변수 활용

### 알림 설정 (1시간)
- 알림 규칙 작성
- 임계값 설정
- 알림 채널 연결
- 알림 테스트

---

## ✅ 성공 기준

### 기술적 목표
- [ ] 모든 서비스(5개) 메트릭 수집 100% 가동률
- [ ] Grafana 대시보드 응답 시간 <2초
- [ ] Prometheus 쿼리 응답 시간 <1초
- [ ] 알림 지연 시간 <2분

### 비즈니스 목표
- [ ] 장애 감지 시간 50% 단축 (30분 → 15분)
- [ ] 장애 복구 시간 40% 단축 (60분 → 36분)
- [ ] 운영 효율성 30% 향상 (모니터링 시간 절감)
- [ ] 팀원 만족도 80% 이상

---

## 📌 다음 단계 (구현 시작)

### Immediate (이번 주)
1. ✅ **분석 완료** - Grafana/Prometheus 선택 확정
2. ⏭️ **아키텍처 리뷰** - 팀과 설계 검토
3. ⏭️ **예산 승인** - $105-116/월 확보

### Short-term (1-2주)
1. ⏭️ **Terraform 코드 작성** - monitoring/ 디렉토리
2. ⏭️ **개발 환경 배포** - 테스트 및 검증
3. ⏭️ **대시보드 프로토타입** - 핵심 메트릭 3개

### Mid-term (3-4주)
1. ⏭️ **프로덕션 배포** - 단계적 롤아웃
2. ⏭️ **팀 교육** - PromQL 및 대시보드 사용법
3. ⏭️ **모니터링 자동화** - Terraform 완전 자동화

---

**결론**: 5개 서비스 환경에서는 Grafana + Prometheus가 CloudWatch 대시보드보다 월 $50 더 비싸지만, 통합 관리, 고급 기능, 확장성을 고려하면 **투자 가치가 충분합니다**.

특히 서비스가 계속 늘어날 계획이라면 지금 구축하는 것이 **장기적으로 더 경제적**입니다.

🚀 **추천: Grafana + Prometheus 즉시 구축 시작**
