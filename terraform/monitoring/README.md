# Monitoring System with AMP/AMG

Amazon Managed Prometheus (AMP)와 Amazon Managed Grafana (AMG)를 사용한 중앙 모니터링 시스템 구성

## 📋 개요

이 모듈은 IN-117 태스크의 일환으로 ECS, RDS, ALB 리소스를 모니터링하기 위한 AWS Managed 서비스 기반 관측성 시스템을 구축합니다.

### 주요 구성요소

- **Amazon Managed Prometheus (AMP)**: 메트릭 저장 및 쿼리
- **Amazon Managed Grafana (AMG)**: 시각화 및 대시보드
- **AWS Distro for OpenTelemetry (ADOT)**: 메트릭 수집 에이전트
- **IAM Roles**: 서비스 간 권한 관리

## 🏗️ 아키텍처

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  ECS Tasks  │────▶│     AMP     │────▶│     AMG     │
│  + ADOT     │     │  Workspace  │     │  Workspace  │
└─────────────┘     └─────────────┘     └─────────────┘
       │
       │ Metrics
       ▼
┌─────────────┐
│  CloudWatch │
│   Metrics   │
└─────────────┘
```

## 📁 파일 구조

```
monitoring/
├── provider.tf                 # Terraform & AWS provider 설정
├── variables.tf                # 변수 정의
├── terraform.tfvars            # 변수 값 설정
├── amp.tf                      # AMP Workspace 리소스
├── amg.tf                      # AMG Workspace 리소스
├── iam.tf                      # IAM 역할 및 정책
├── alerting.tf                 # SNS Topics, CloudWatch Alarms (IN-118)
├── chatbot.tf                  # AWS Chatbot for Slack (IN-118)
├── adot-ecs-integration.tf     # ADOT Collector ECS 통합 예제
├── outputs.tf                  # 출력 변수
├── configs/
│   └── adot-config.yaml        # ADOT Collector 설정
└── README.md                   # 이 파일
```

## 🚀 배포 순서

### 1. 전제 조건

- Terraform >= 1.5.0
- AWS CLI 구성 완료
- 적절한 IAM 권한
- 기존 인프라: VPC, ECS Cluster, KMS Key

### 2. 초기 설정

```bash
cd terraform/monitoring

# Backend 설정 구성
# backend.conf.example을 복사하여 backend.conf 생성
cp backend.conf.example backend.conf
# backend.conf 파일 편집하여 실제 값 입력

# Terraform 초기화 (backend 설정 포함)
terraform init -backend-config=backend.conf

# 계획 확인
terraform plan

# 적용
terraform apply
```

### 3. AMP/AMG Workspace 생성 확인

```bash
# AMP Workspace ID 확인
terraform output amp_workspace_id

# AMG Workspace Endpoint 확인
terraform output amg_workspace_endpoint
```

### 4. ADOT Collector 통합

ADOT Collector를 ECS 태스크에 통합하려면:

1. `adot-ecs-integration.tf`의 예제 참조
2. 기존 ECS Task Definition에 ADOT sidecar 컨테이너 추가
3. Task Role을 `ecs_amp_writer` 역할로 변경
4. 환경 변수 설정:
   - `AWS_REGION`: ap-northeast-2
   - `AMP_ENDPOINT`: (terraform output에서 확인)
   - `SERVICE_NAME`: 서비스 이름

### 5. Grafana 설정

1. AMG Workspace에 접속 (AWS Console 또는 endpoint URL)
2. AWS SSO로 로그인
3. Data Source 추가:
   - Type: Amazon Managed Prometheus
   - URL: AMP workspace endpoint (terraform output)
   - Authentication: SigV4
4. 대시보드 임포트 (추후 제공)

## 📊 메트릭 수집 대상

### ECS 서비스
- CPU/Memory 사용률
- 네트워크 I/O
- Task 개수 및 상태
- Container Insights 메트릭

### RDS (향후 추가)
- CPU 사용률
- 연결 수
- 지연시간 (Read/Write)
- IOPS

### ALB (향후 추가)
- 요청 수
- 응답 시간
- HTTP 상태 코드 분포
- 타겟 헬스 체크

## 🔧 설정 변수

주요 변수 (`terraform.tfvars`):

```hcl
# Environment
environment = "prod"
aws_region  = "ap-northeast-2"

# AMP
amp_workspace_alias  = "infrastructure-metrics"
amp_retention_period = 150  # days

# AMG
amg_workspace_name = "infrastructure-observability"
amg_authentication_providers = ["AWS_SSO"]

# ADOT
enable_adot_collector = true
adot_image_version    = "v0.42.0"
```

## 🔐 IAM 역할

### ECS Task Role (amp-writer)
- `aps:RemoteWrite`: AMP에 메트릭 전송
- `aps:GetSeries`, `aps:GetLabels`: 메트릭 조회

### Grafana Role (amp-reader)
- `aps:QueryMetrics`: AMP 쿼리
- `cloudwatch:GetMetricData`: CloudWatch 조회

## 📝 다음 단계

### Phase 1: 기본 구성 (현재)
- [x] AMP Workspace 생성
- [x] AMG Workspace 생성
- [x] IAM 역할 및 정책
- [x] ADOT Collector 설정

### Phase 2: 메트릭 수집
- [ ] Atlantis ECS Task에 ADOT 통합
- [ ] RDS CloudWatch 메트릭 연동
- [ ] ALB CloudWatch 메트릭 연동

### Phase 3: 시각화
- [ ] Overview 대시보드
- [ ] ECS 서비스 대시보드
- [ ] RDS 성능 대시보드
- [ ] ALB 트래픽 대시보드

### Phase 4: 알림 체계 (완료)
- [x] SNS Topics 생성 (Critical/Warning/Info)
- [x] AWS Chatbot Slack 연동
- [x] CloudWatch Alarms 설정 (ECS)
- [x] Runbook 문서 작성

## 💰 비용 예상

### AMP
- 메트릭 수집: ~$9/월
- 저장: ~$0.3/월
- 쿼리: ~$1.5/월
- **소계: ~$11/월**

### AMG
- Editor 라이선스: $9/사용자/월
- **소계: $9-18/월**

### 총 예상 비용
**$20-30/월** (초기 소규모 운영 기준)

## 🔍 트러블슈팅

### AMP에 메트릭이 표시되지 않음
1. ECS Task Role에 AMP write 권한 확인
2. ADOT Collector 로그 확인: `/aws/ecs/adot-collector`
3. AMP endpoint 환경 변수 확인
4. Security Group에서 HTTPS 아웃바운드 허용 확인

### Grafana에서 데이터를 볼 수 없음
1. Data Source 설정 확인 (AMP endpoint URL)
2. Grafana IAM role에 AMP query 권한 확인
3. 메트릭이 AMP에 실제로 수집되고 있는지 확인

### ADOT Collector가 시작되지 않음
1. IAM 역할 assume 권한 확인
2. 설정 파일 구문 검증: `adot-config.yaml`
3. 메모리/CPU 할당 충분한지 확인
4. Health check endpoint 응답 확인: `curl localhost:13133`

## 📚 참고 자료

- [Amazon Managed Prometheus Documentation](https://docs.aws.amazon.com/prometheus/)
- [Amazon Managed Grafana Documentation](https://docs.aws.amazon.com/grafana/)
- [ADOT Collector Configuration](https://aws-otel.github.io/docs/getting-started/collector)
- [AWS Observability Best Practices](https://aws-observability.github.io/observability-best-practices/)

## 🤝 기여

질문이나 개선 사항이 있으면 Platform Team에 문의하세요.

## 🚨 알림 체계 (IN-118)

### 개요
3단계 알림 시스템으로 Critical, Warning, Info 레벨별 SNS Topic과 Slack 연동을 통한 실시간 알림을 제공합니다.

### SNS Topics
- **prod-monitoring-critical**: P0 즉시 대응 필요
- **prod-monitoring-warning**: P1 30분 이내 대응
- **prod-monitoring-info**: P2 정보성 알림

### CloudWatch Alarms (ECS)
- Critical: Task Count Zero, High Memory (95%)
- Warning: High CPU (80%), High Memory (80%)

### Slack 연동 (AWS Chatbot)
1. Slack Workspace에 AWS Chatbot 앱 설치
2. 채널 생성: `#alerts-critical`, `#alerts-warning`, `#alerts-info`
3. Chatbot 설정에서 각 채널 ID 확보
4. `terraform.tfvars`에 Slack workspace ID와 channel IDs 추가
5. `enable_chatbot = true`로 설정 후 배포

### Runbook
대응 절차는 `docs/runbooks/` 참조:
- [ECS High CPU](../../docs/runbooks/ecs-high-cpu.md)
- [ECS Memory Critical](../../docs/runbooks/ecs-memory-critical.md)
- [ECS Task Count Zero](../../docs/runbooks/ecs-task-count-zero.md)

### 테스트
```bash
# SNS 토픽 테스트
aws sns publish \
  --topic-arn $(terraform output -raw sns_topic_critical_arn) \
  --message "Test critical alert" \
  --subject "Test Alert"
```

## 📄 라이선스

Internal Use Only - Platform Team
