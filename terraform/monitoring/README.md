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

## 🚀 사용 방법 (Usage)

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

## 🔧 Troubleshooting

### 1. AMP에 메트릭이 표시되지 않음

**증상**: Prometheus 쿼리 결과가 비어있거나 메트릭이 수집되지 않음

**확인 방법**:
```bash
# AMP Workspace 상태 확인
aws amp describe-workspace \
  --workspace-id $(terraform output -raw amp_workspace_id) \
  --region ap-northeast-2

# ADOT Collector 로그 확인
aws logs tail /aws/ecs/adot-collector --follow --region ap-northeast-2
```

**해결 방법**:

1. **ECS Task Role 권한 확인**:
   ```bash
   # Task Role이 AMP write 권한이 있는지 확인
   aws iam get-role-policy \
     --role-name ecs-amp-writer \
     --policy-name AMP-RemoteWrite \
     --region ap-northeast-2
   ```

   필요한 권한:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "aps:RemoteWrite",
       "aps:GetSeries",
       "aps:GetLabels"
     ],
     "Resource": "arn:aws:aps:ap-northeast-2:*:workspace/*"
   }
   ```

2. **ADOT Collector 설정 확인**:
   ```bash
   # ADOT Task Definition에서 환경 변수 확인
   aws ecs describe-task-definition \
     --task-definition <task-definition-name> \
     --query 'taskDefinition.containerDefinitions[*].environment'
   ```

   필수 환경 변수:
   - `AWS_REGION`: ap-northeast-2
   - `AMP_ENDPOINT`: AMP workspace remote write URL

3. **보안 그룹 확인**:
   - ADOT Collector가 실행되는 ECS Task의 보안 그룹에서 HTTPS (443) 아웃바운드 허용 확인
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <security-group-id> \
     --query 'SecurityGroups[*].{Egress:IpPermissionsEgress}'
   ```

4. **VPC 엔드포인트 확인** (Private subnet 사용 시):
   ```bash
   # AMP VPC 엔드포인트 확인
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-2.aps-workspaces" \
     --region ap-northeast-2
   ```

### 2. Grafana에서 데이터를 볼 수 없음

**증상**: Grafana 대시보드가 비어있거나 "No data" 표시

**확인 방법**:
```bash
# AMG Workspace 상태 확인
aws grafana describe-workspace \
  --workspace-id $(terraform output -raw amg_workspace_id) \
  --region ap-northeast-2

# AMG Workspace endpoint 확인
terraform output amg_workspace_endpoint
```

**해결 방법**:

1. **Data Source 설정 확인**:
   - Grafana UI에서 Configuration > Data Sources
   - Prometheus Data Source 설정 확인:
     - Type: Prometheus
     - URL: AMP workspace query endpoint (`terraform output amp_workspace_endpoint`)
     - Authentication: SigV4
     - Default Region: ap-northeast-2

2. **Grafana IAM Role 권한 확인**:
   ```bash
   # Grafana workspace role 권한 확인
   aws iam get-role-policy \
     --role-name <grafana-role-name> \
     --policy-name AMP-Query
   ```

   필요한 권한:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "aps:QueryMetrics",
       "aps:GetSeries",
       "aps:GetLabels",
       "aps:GetMetricMetadata"
     ],
     "Resource": "*"
   }
   ```

3. **메트릭 존재 여부 확인**:
   - AMP 콘솔에서 직접 PromQL 쿼리 실행
   - 간단한 쿼리 테스트: `up` (모든 타겟 상태)

4. **시간 범위 확인**:
   - Grafana 대시보드 상단 시간 범위가 적절한지 확인
   - 최근 메트릭이 수집되었는지 확인 (최대 5분 지연 가능)

### 3. ADOT Collector가 시작되지 않음

**증상**: ECS Task가 ADOT sidecar 컨테이너 시작 실패로 계속 재시작

**확인 방법**:
```bash
# ECS Task 이벤트 확인
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-id> \
  --region ap-northeast-2 \
  --query 'tasks[0].stoppedReason'

# ADOT Collector 로그 확인
aws logs tail /aws/ecs/adot-collector \
  --since 1h \
  --region ap-northeast-2
```

**해결 방법**:

1. **IAM 역할 Assume 권한 확인**:
   ```bash
   # Task Execution Role이 Task Role을 assume할 수 있는지 확인
   aws iam get-role \
     --role-name <task-execution-role> \
     --query 'Role.AssumeRolePolicyDocument'
   ```

2. **ADOT 설정 파일 검증**:
   - `configs/adot-config.yaml` 구문 오류 확인
   - YAML linter 실행: `yamllint configs/adot-config.yaml`

3. **리소스 할당 확인**:
   - ADOT Collector용 CPU/Memory 충분한지 확인
   - 권장: CPU 256 units, Memory 512 MB 이상

4. **Health Check 설정**:
   ```bash
   # ADOT Collector health check endpoint 테스트 (컨테이너 내부)
   curl http://localhost:13133/
   ```

### 4. CloudWatch 알람이 트리거되지 않음

**증상**: 메트릭 임계값 초과했지만 알람 발생 안 함

**확인 방법**:
```bash
# CloudWatch 알람 상태 확인
aws cloudwatch describe-alarms \
  --alarm-name-prefix "prod-ecs" \
  --region ap-northeast-2

# 알람 히스토리 확인
aws cloudwatch describe-alarm-history \
  --alarm-name <alarm-name> \
  --max-records 10 \
  --region ap-northeast-2
```

**해결 방법**:

1. **메트릭 데이터 확인**:
   ```bash
   # 실제 메트릭 값 확인
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ECS \
     --metric-name CPUUtilization \
     --dimensions Name=ServiceName,Value=<service-name> \
     --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
     --period 300 \
     --statistics Average \
     --region ap-northeast-2
   ```

2. **알람 설정 검증**:
   - Threshold 값이 적절한지 확인
   - Evaluation Period 및 Datapoints 설정 확인
   - Treat Missing Data 설정 확인

3. **SNS Topic 구독 확인**:
   ```bash
   # SNS Topic 구독 확인
   aws sns list-subscriptions-by-topic \
     --topic-arn $(terraform output -raw sns_topic_critical_arn) \
     --region ap-northeast-2
   ```

### 5. Slack 알림이 오지 않음

**증상**: CloudWatch 알람이 발생해도 Slack에 알림 전송 안 됨

**확인 방법**:
```bash
# AWS Chatbot 설정 확인
aws chatbot describe-slack-channel-configurations \
  --region ap-northeast-2

# SNS Topic에서 Chatbot 구독 확인
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_critical_arn)
```

**해결 방법**:

1. **AWS Chatbot Slack 앱 권한 확인**:
   - Slack Workspace에 AWS Chatbot 앱이 설치되어 있는지 확인
   - AWS Chatbot이 채널에 초대되어 있는지 확인
   - 채널 설정 > Integrations에서 AWS Chatbot 확인

2. **Slack Channel ID 확인**:
   ```bash
   # 올바른 Slack Channel ID가 설정되어 있는지 확인
   terraform output slack_channel_id_critical
   ```

   Slack Channel ID 찾는 방법:
   - Slack에서 채널 이름 클릭 > 채널 세부정보
   - 하단에 Channel ID 표시

3. **SNS 메시지 형식 확인**:
   - AWS Chatbot은 특정 JSON 형식만 지원
   - CloudWatch 알람은 자동으로 올바른 형식 사용

4. **테스트 알림 전송**:
   ```bash
   # SNS Topic 직접 테스트
   aws sns publish \
     --topic-arn $(terraform output -raw sns_topic_critical_arn) \
     --message "Test critical alert from CLI" \
     --subject "Test Alert" \
     --region ap-northeast-2
   ```

### 6. 메트릭 데이터 누락 또는 지연

**증상**: 일부 메트릭이 간헐적으로 누락되거나 5분 이상 지연

**확인 방법**:
```bash
# Container Insights 활성화 확인
aws ecs describe-clusters \
  --clusters <cluster-name> \
  --include SETTINGS \
  --query 'clusters[0].settings'

# ADOT Collector 메모리 사용량 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=TaskDefinitionFamily,Value=adot-collector \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

**해결 방법**:

1. **Container Insights 활성화**:
   ```bash
   # ECS 클러스터에 Container Insights 활성화
   aws ecs update-cluster-settings \
     --cluster <cluster-name> \
     --settings name=containerInsights,value=enabled
   ```

2. **ADOT Collector 리소스 증가**:
   - CPU/Memory 부족 시 메트릭 드롭 발생 가능
   - 권장: CPU 512 units, Memory 1024 MB

3. **Scrape Interval 조정**:
   - `adot-config.yaml`에서 scrape_interval 확인
   - 너무 짧으면 리소스 부족, 너무 길면 지연 발생
   - 권장: 30초-60초

4. **Batch 크기 조정**:
   ```yaml
   # adot-config.yaml
   exporters:
     prometheusremotewrite:
       endpoint: ${AMP_ENDPOINT}
       timeout: 30s
       queue_size: 10000  # 증가
       batch_size: 5000   # 증가
   ```

### 7. 비용 초과 문제

**증상**: AMP/AMG 비용이 예상보다 높음

**확인 방법**:
```bash
# 현재 월 비용 확인 (Cost Explorer API)
aws ce get-cost-and-usage \
  --time-period Start=$(date -v-30d +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter file://cost-filter.json

# cost-filter.json:
# {
#   "Dimensions": {
#     "Key": "SERVICE",
#     "Values": ["Amazon Managed Service for Prometheus", "Amazon Managed Grafana"]
#   }
# }
```

**해결 방법**:

1. **메트릭 수집 최적화**:
   - 불필요한 메트릭 제외 (relabel_configs 사용)
   - High-cardinality 메트릭 제거 또는 aggregation

2. **Retention Period 조정**:
   ```hcl
   # terraform.tfvars
   amp_retention_period = 90  # 150일 → 90일
   ```

3. **Grafana 사용자 관리**:
   - Editor 라이선스 최소화 ($9/사용자/월)
   - Viewer 사용자로 전환 (무료)

4. **쿼리 최적화**:
   - Grafana 대시보드 쿼리 빈도 감소
   - 불필요한 Panel 제거

### 8. 하이브리드 인프라: Application 프로젝트에서 AMP 통합

**증상**: Application 프로젝트(애플리케이션 레포지토리)의 ECS 서비스가 중앙 모니터링 시스템(AMP)에 메트릭을 전송하지 못함

**확인 방법**:
```bash
# SSM Parameter로 AMP Endpoint 확인
aws ssm get-parameter \
  --name /shared/monitoring/amp-workspace-endpoint \
  --region ap-northeast-2 \
  --query 'Parameter.Value' \
  --output text

# Application ECS Task에 ADOT Collector sidecar가 있는지 확인
aws ecs describe-task-definition \
  --task-definition <app-task-definition> \
  --query 'taskDefinition.containerDefinitions[?name==`aws-otel-collector`]'
```

**해결 방법**:

1. **SSM Parameter Export** (Infrastructure 프로젝트 - monitoring 패키지):
   ```hcl
   # Infrastructure 프로젝트에서 AMP Workspace Endpoint를 SSM Parameter로 Export
   resource "aws_ssm_parameter" "amp_workspace_endpoint" {
     name  = "/shared/monitoring/amp-workspace-endpoint"
     type  = "String"
     value = aws_prometheus_workspace.main.prometheus_endpoint

     tags = merge(
       local.required_tags,
       {
         Name = "amp-workspace-endpoint-export"
       }
     )
   }

   resource "aws_ssm_parameter" "amp_workspace_id" {
     name  = "/shared/monitoring/amp-workspace-id"
     type  = "String"
     value = aws_prometheus_workspace.main.id

     tags = merge(
       local.required_tags,
       {
         Name = "amp-workspace-id-export"
       }
     )
   }

   # AMP Writer IAM Role ARN도 Export
   resource "aws_ssm_parameter" "amp_writer_role_arn" {
     name  = "/shared/monitoring/amp-writer-role-arn"
     type  = "String"
     value = aws_iam_role.ecs_amp_writer.arn

     tags = merge(
       local.required_tags,
       {
         Name = "amp-writer-role-arn-export"
       }
     )
   }
   ```

2. **Application 프로젝트에서 AMP Endpoint 참조** (`data.tf`):
   ```hcl
   # Infrastructure 프로젝트에서 생성한 AMP Workspace Endpoint 참조
   data "aws_ssm_parameter" "amp_workspace_endpoint" {
     name = "/shared/monitoring/amp-workspace-endpoint"
   }

   data "aws_ssm_parameter" "amp_workspace_id" {
     name = "/shared/monitoring/amp-workspace-id"
   }

   data "aws_ssm_parameter" "amp_writer_role_arn" {
     name = "/shared/monitoring/amp-writer-role-arn"
   }

   locals {
     amp_workspace_endpoint = data.aws_ssm_parameter.amp_workspace_endpoint.value
     amp_workspace_id       = data.aws_ssm_parameter.amp_workspace_id.value
     amp_writer_role_arn    = data.aws_ssm_parameter.amp_writer_role_arn.value
   }
   ```

3. **ADOT Collector Sidecar 추가** (Application 프로젝트 ECS Task Definition):
   ```hcl
   resource "aws_ecs_task_definition" "app" {
     family                   = "app-service"
     network_mode             = "awsvpc"
     requires_compatibilities = ["FARGATE"]
     cpu                      = "512"
     memory                   = "1024"
     task_role_arn            = local.amp_writer_role_arn  # Infrastructure 프로젝트의 Role 사용
     execution_role_arn       = aws_iam_role.ecs_execution.arn

     container_definitions = jsonencode([
       {
         name  = "app"
         image = "app:latest"
         portMappings = [{
           containerPort = 8080
           protocol      = "tcp"
         }]
         # Application 메트릭을 Prometheus 형식으로 노출
         environment = [
           {
             name  = "PROMETHEUS_METRICS_PORT"
             value = "9090"
           }
         ]
         logConfiguration = {
           logDriver = "awslogs"
           options = {
             "awslogs-group"         = "/aws/ecs/app-service"
             "awslogs-region"        = "ap-northeast-2"
             "awslogs-stream-prefix" = "app"
           }
         }
       },
       {
         name  = "aws-otel-collector"
         image = "public.ecr.aws/aws-observability/aws-otel-collector:v0.42.0"
         environment = [
           {
             name  = "AWS_REGION"
             value = "ap-northeast-2"
           },
           {
             name  = "AMP_ENDPOINT"
             value = "${local.amp_workspace_endpoint}api/v1/remote_write"
           },
           {
             name  = "SERVICE_NAME"
             value = "app-service"
           },
           {
             name  = "ENVIRONMENT"
             value = var.environment
           }
         ]
         command = ["--config=/etc/ecs/ecs-amp-config.yaml"]
         logConfiguration = {
           logDriver = "awslogs"
           options = {
             "awslogs-group"         = "/aws/ecs/adot-collector"
             "awslogs-region"        = "ap-northeast-2"
             "awslogs-stream-prefix" = "app-service"
           }
         }
       }
     ])
   }
   ```

4. **ADOT Collector 설정 파일** (`configs/adot-config.yaml`):
   ```yaml
   # Application 프로젝트의 ADOT 설정
   receivers:
     prometheus:
       config:
         scrape_configs:
           - job_name: 'app-service'
             scrape_interval: 30s
             static_configs:
               - targets: ['localhost:9090']  # Application 메트릭 엔드포인트
             relabel_configs:
               - source_labels: [__address__]
                 target_label: instance
                 replacement: '${ENVIRONMENT}-app-service'
               - target_label: service
                 replacement: 'app-service'
               - target_label: environment
                 replacement: '${ENVIRONMENT}'

   processors:
     batch:
       timeout: 60s
       send_batch_size: 5000

   exporters:
     prometheusremotewrite:
       endpoint: ${AMP_ENDPOINT}
       auth:
         authenticator: sigv4auth
       resource_to_telemetry_conversion:
         enabled: true

   extensions:
     sigv4auth:
       region: ${AWS_REGION}
       service: aps

   service:
     extensions: [sigv4auth]
     pipelines:
       metrics:
         receivers: [prometheus]
         processors: [batch]
         exporters: [prometheusremotewrite]
   ```

5. **보안 그룹 규칙** (Application 프로젝트):
   ```hcl
   # ADOT Collector가 AMP로 메트릭 전송 (HTTPS 443)
   resource "aws_security_group_rule" "ecs_to_amp" {
     type              = "egress"
     from_port         = 443
     to_port           = 443
     protocol          = "tcp"
     cidr_blocks       = ["0.0.0.0/0"]
     security_group_id = aws_security_group.ecs_tasks.id
     description       = "Allow HTTPS to AMP for metrics"
   }
   ```

6. **VPC Endpoint 확인** (Private subnet 사용 시):
   ```bash
   # AMP VPC Endpoint 존재 여부 확인
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-2.aps-workspaces" \
     --region ap-northeast-2 \
     --query 'VpcEndpoints[*].[VpcEndpointId,State,VpcId]'
   ```

   VPC Endpoint가 없다면 Infrastructure 프로젝트에서 생성:
   ```hcl
   resource "aws_vpc_endpoint" "amp" {
     vpc_id            = local.vpc_id
     service_name      = "com.amazonaws.ap-northeast-2.aps-workspaces"
     vpc_endpoint_type = "Interface"
     subnet_ids        = local.private_subnet_ids

     security_group_ids = [
       aws_security_group.vpc_endpoints.id
     ]

     private_dns_enabled = true

     tags = merge(
       local.required_tags,
       {
         Name = "amp-endpoint"
       }
     )
   }
   ```

### 9. 하이브리드 인프라: Application별 메트릭 네임스페이스 분리

**증상**: 여러 Application의 메트릭이 섞여서 구분이 어렵거나, 메트릭 이름 충돌 발생

**해결 방법**:

1. **메트릭 Labeling 전략** (Application 프로젝트):
   ```yaml
   # ADOT Config에서 공통 labels 추가
   receivers:
     prometheus:
       config:
         scrape_configs:
           - job_name: 'app-service'
             scrape_interval: 30s
             static_configs:
               - targets: ['localhost:9090']
             relabel_configs:
               # 필수 labels: service, environment, team
               - target_label: service
                 replacement: 'app-service'  # 서비스 이름
               - target_label: environment
                 replacement: '${ENVIRONMENT}'  # dev/staging/prod
               - target_label: team
                 replacement: 'platform-team'  # 팀 이름
               - target_label: component
                 replacement: 'api'  # 컴포넌트 유형

               # Instance label에 AZ 정보 포함
               - source_labels: [__meta_ec2_availability_zone]
                 target_label: availability_zone

               # VPC 정보 포함
               - target_label: vpc
                 replacement: 'application-vpc-1'
   ```

2. **메트릭 네임스페이스 규칙**:
   ```yaml
   # Application 코드에서 메트릭 이름 규칙 준수
   # 형식: {service}_{component}_{metric_name}

   # 예시:
   # - app_service_api_request_total
   # - app_service_api_request_duration_seconds
   # - app_service_db_connection_pool_active
   # - app_service_cache_hit_ratio
   ```

3. **Prometheus Recording Rules** (선택사항):
   ```yaml
   # AMP에서 Recording Rules로 사전 집계
   groups:
     - name: app_service_aggregates
       interval: 60s
       rules:
         # 서비스별 요청률 (per-second)
         - record: app_service:request_rate:5m
           expr: |
             sum(rate(app_service_api_request_total[5m]))
             by (service, environment, status_code)

         # 서비스별 에러율
         - record: app_service:error_rate:5m
           expr: |
             sum(rate(app_service_api_request_total{status_code=~"5.."}[5m]))
             by (service, environment)
             /
             sum(rate(app_service_api_request_total[5m]))
             by (service, environment)

         # 서비스별 p95 레이턴시
         - record: app_service:request_duration:p95:5m
           expr: |
             histogram_quantile(0.95,
               sum(rate(app_service_api_request_duration_seconds_bucket[5m]))
               by (service, environment, le)
             )
   ```

4. **Grafana 쿼리 템플릿**:
   ```promql
   # 특정 서비스의 요청률
   sum(rate(app_service_api_request_total{service="app-service", environment="prod"}[5m]))

   # 모든 Application의 에러율 (서비스별)
   sum(rate(app_service_api_request_total{status_code=~"5..", environment="prod"}[5m]))
   by (service)

   # 특정 팀의 모든 서비스 CPU 사용률
   avg(ecs_task_cpu_utilization{team="platform-team", environment="prod"})
   by (service)
   ```

### 10. 하이브리드 인프라: Application별 Grafana 대시보드 생성

**증상**: Application 프로젝트별 전용 대시보드가 필요하거나, 중앙 모니터링 시스템에서 서비스별 모니터링 뷰가 필요함

**해결 방법**:

1. **Grafana 대시보드 JSON 템플릿** (Application 프로젝트 `monitoring/dashboards/app-service.json`):
   ```json
   {
     "dashboard": {
       "title": "App Service - Overview",
       "tags": ["app-service", "prod"],
       "timezone": "Asia/Seoul",
       "refresh": "30s",
       "templating": {
         "list": [
           {
             "name": "environment",
             "type": "custom",
             "query": "dev,staging,prod",
             "current": {
               "value": "prod"
             }
           },
           {
             "name": "service",
             "type": "query",
             "datasource": "AMP",
             "query": "label_values(app_service_api_request_total, service)"
           }
         ]
       },
       "panels": [
         {
           "id": 1,
           "title": "Request Rate (req/s)",
           "type": "graph",
           "targets": [
             {
               "expr": "sum(rate(app_service_api_request_total{service=\"$service\", environment=\"$environment\"}[5m]))",
               "legendFormat": "Total Requests"
             }
           ]
         },
         {
           "id": 2,
           "title": "Error Rate (%)",
           "type": "graph",
           "targets": [
             {
               "expr": "sum(rate(app_service_api_request_total{service=\"$service\", environment=\"$environment\", status_code=~\"5..\"}[5m])) / sum(rate(app_service_api_request_total{service=\"$service\", environment=\"$environment\"}[5m])) * 100",
               "legendFormat": "Error Rate"
             }
           ]
         },
         {
           "id": 3,
           "title": "Response Time (p95)",
           "type": "graph",
           "targets": [
             {
               "expr": "histogram_quantile(0.95, sum(rate(app_service_api_request_duration_seconds_bucket{service=\"$service\", environment=\"$environment\"}[5m])) by (le))",
               "legendFormat": "p95 Latency"
             }
           ]
         },
         {
           "id": 4,
           "title": "ECS Task CPU/Memory",
           "type": "graph",
           "targets": [
             {
               "expr": "avg(ecs_task_cpu_utilization{service=\"$service\", environment=\"$environment\"})",
               "legendFormat": "CPU %"
             },
             {
               "expr": "avg(ecs_task_memory_utilization{service=\"$service\", environment=\"$environment\"})",
               "legendFormat": "Memory %"
             }
           ]
         }
       ]
     }
   }
   ```

2. **Terraform으로 대시보드 프로비저닝** (Application 프로젝트):
   ```hcl
   # Grafana Provider 설정
   terraform {
     required_providers {
       grafana = {
         source  = "grafana/grafana"
         version = "~> 3.0"
       }
     }
   }

   # AMG Workspace Endpoint 참조
   data "aws_ssm_parameter" "amg_workspace_endpoint" {
     name = "/shared/monitoring/amg-workspace-endpoint"
   }

   provider "grafana" {
     url  = data.aws_ssm_parameter.amg_workspace_endpoint.value
     auth = "aws.amg"  # AWS SSO 인증 사용
   }

   # 대시보드 생성
   resource "grafana_dashboard" "app_service" {
     config_json = file("${path.module}/monitoring/dashboards/app-service.json")

     folder = grafana_folder.app_service.id
   }

   resource "grafana_folder" "app_service" {
     title = "App Service"
   }
   ```

3. **Application 메트릭 엔드포인트 구현** (예: Node.js/Express):
   ```javascript
   // Application 코드에서 Prometheus 메트릭 노출
   const promClient = require('prom-client');
   const express = require('express');

   // Register 생성
   const register = new promClient.Registry();
   promClient.collectDefaultMetrics({ register });

   // Custom metrics
   const httpRequestTotal = new promClient.Counter({
     name: 'app_service_api_request_total',
     help: 'Total number of HTTP requests',
     labelNames: ['method', 'path', 'status_code'],
     registers: [register]
   });

   const httpRequestDuration = new promClient.Histogram({
     name: 'app_service_api_request_duration_seconds',
     help: 'HTTP request duration in seconds',
     labelNames: ['method', 'path'],
     buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
     registers: [register]
   });

   // Middleware
   app.use((req, res, next) => {
     const start = Date.now();
     res.on('finish', () => {
       const duration = (Date.now() - start) / 1000;
       httpRequestTotal.inc({
         method: req.method,
         path: req.route?.path || req.path,
         status_code: res.statusCode
       });
       httpRequestDuration.observe({
         method: req.method,
         path: req.route?.path || req.path
       }, duration);
     });
     next();
   });

   // Metrics endpoint
   app.get('/metrics', async (req, res) => {
     res.set('Content-Type', register.contentType);
     res.end(await register.metrics());
   });
   ```

4. **Cross-Stack 메트릭 통합 쿼리**:
   ```promql
   # 모든 Application의 총 요청률
   sum(rate(app_service_api_request_total{environment="prod"}[5m]))
   by (service)

   # Infrastructure VPC와 Application VPC의 네트워크 트래픽 비교
   sum(rate(vpc_bytes_out{vpc=~"infrastructure-vpc|application-vpc-.*"}[5m]))
   by (vpc)

   # Shared RDS 연결 수 vs Application 요청률 상관관계
   sum(rds_database_connections{db_instance="prod-shared-mysql"})
   /
   sum(rate(app_service_api_request_total{environment="prod"}[5m]))
   ```

5. **대시보드 업데이트 자동화** (CI/CD):
   ```yaml
   # GitHub Actions 예제
   name: Update Grafana Dashboard

   on:
     push:
       branches: [main]
       paths:
         - 'monitoring/dashboards/**'

   jobs:
     update-dashboard:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3

         - name: Configure AWS credentials
           uses: aws-actions/configure-aws-credentials@v2
           with:
             aws-region: ap-northeast-2

         - name: Setup Terraform
           uses: hashicorp/setup-terraform@v2

         - name: Apply Grafana Dashboard
           run: |
             cd monitoring
             terraform init
             terraform apply -target=grafana_dashboard.app_service -auto-approve
   ```

### 11. 일반적인 체크리스트

#### 기본 모니터링 설정
- [ ] AMP Workspace 상태 `ACTIVE`
- [ ] AMG Workspace 상태 `ACTIVE`
- [ ] ADOT Collector ECS Task 정상 실행
- [ ] Grafana Data Source 설정 완료 (AMP 연동)
- [ ] CloudWatch 알람 정상 작동
- [ ] SNS Topics 구독 확인 (Slack, Email 등)
- [ ] AWS Chatbot Slack 연동 확인
- [ ] 기본 대시보드 로드 성공
- [ ] 메트릭 데이터 수집 확인 (최소 5분 대기)
- [ ] 테스트 알람 전송 성공

#### 하이브리드 인프라 (Application 통합)
- [ ] SSM Parameters가 생성됨:
  - [ ] `/shared/monitoring/amp-workspace-endpoint`
  - [ ] `/shared/monitoring/amp-workspace-id`
  - [ ] `/shared/monitoring/amp-writer-role-arn`
  - [ ] `/shared/monitoring/amg-workspace-endpoint` (선택사항)
- [ ] Application ECS Task에 ADOT Collector sidecar 추가
- [ ] Application ECS Task Role이 AMP Writer Role 사용
- [ ] Application별 메트릭 labels 설정 (service, environment, team)
- [ ] Application 메트릭 엔드포인트 구현 (예: /metrics)
- [ ] ADOT Collector가 Application 메트릭 스크래핑 설정
- [ ] VPC Endpoint (AMP) 생성 (Private 서브넷 사용 시)
- [ ] 보안 그룹 HTTPS (443) 아웃바운드 허용

#### Grafana 대시보드
- [ ] Application별 전용 폴더 생성
- [ ] 기본 대시보드 생성 (Overview, API, Database, Infrastructure)
- [ ] 대시보드 변수 설정 (environment, service)
- [ ] 알림 규칙 설정 (Critical, Warning 임계값)
- [ ] 대시보드 JSON을 Git에 버전 관리

#### 메트릭 품질
- [ ] 메트릭 naming convention 준수 (`{service}_{component}_{metric_name}`)
- [ ] 필수 labels 포함 (service, environment, team)
- [ ] High-cardinality labels 최소화 (예: user_id, request_id 제외)
- [ ] Recording Rules 설정 (집계 메트릭)
- [ ] Retention period 설정 확인 (기본 150일)

## 📥 Variables

이 모듈은 다음과 같은 입력 변수를 사용합니다:

### 기본 설정
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `environment` | 환경 이름 (dev, staging, prod) | `string` | `prod` | No |
| `aws_region` | AWS 리전 | `string` | `ap-northeast-2` | No |
| `service` | 서비스 이름 | `string` | `monitoring` | No |

### 태그 관련
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `owner` | 리소스 담당 팀/개인 | `string` | `platform-team` | No |
| `cost_center` | 비용 센터 | `string` | `engineering` | No |
| `team` | 담당 팀 | `string` | `platform-team` | No |

### AMP 설정
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `amp_workspace_alias` | AMP 워크스페이스 별칭 | `string` | `infrastructure-metrics` | No |
| `amp_retention_period` | 메트릭 보관 기간 (일) | `number` | `150` | No |
| `amp_enable_logging` | CloudWatch Logs 활성화 | `bool` | `true` | No |

### AMG 설정
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `amg_workspace_name` | AMG 워크스페이스 이름 | `string` | `infrastructure-observability` | No |
| `amg_authentication_providers` | 인증 제공자 | `list(string)` | `["AWS_SSO"]` | No |
| `amg_data_sources` | 데이터 소스 | `list(string)` | `["PROMETHEUS", "CLOUDWATCH"]` | No |

### ADOT & 알림 설정
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `enable_adot_collector` | ADOT Collector 활성화 | `bool` | `true` | No |
| `enable_ecs_alarms` | ECS CloudWatch 알람 활성화 | `bool` | `true` | No |
| `enable_chatbot` | AWS Chatbot (Slack) 활성화 | `bool` | `false` | No |
| `slack_workspace_id` | Slack Workspace ID | `string` | `""` | No (sensitive) |
| `slack_channel_id` | Slack Channel ID | `string` | `""` | No (sensitive) |

전체 변수 목록은 [variables.tf](./variables.tf) 파일을 참조하세요.

## 📤 Outputs

이 모듈은 다음과 같은 출력 값을 제공합니다:

### AMP 관련
| 출력 이름 | 설명 |
|-----------|------|
| `amp_workspace_id` | AMP 워크스페이스 ID |
| `amp_workspace_arn` | AMP 워크스페이스 ARN |
| `amp_workspace_endpoint` | AMP 엔드포인트 URL |
| `amp_workspace_remote_write_url` | AMP remote write 엔드포인트 |
| `amp_workspace_query_url` | AMP query 엔드포인트 |

### AMG 관련
| 출력 이름 | 설명 |
|-----------|------|
| `amg_workspace_id` | AMG 워크스페이스 ID |
| `amg_workspace_arn` | AMG 워크스페이스 ARN |
| `amg_workspace_endpoint` | Grafana 접속 URL |
| `amg_workspace_grafana_version` | Grafana 버전 |

### IAM Role 관련
| 출력 이름 | 설명 |
|-----------|------|
| `ecs_amp_writer_role_arn` | ECS Task가 AMP에 쓰기 위한 IAM Role ARN |
| `ecs_amp_writer_role_name` | ECS Task IAM Role 이름 |
| `grafana_amp_reader_role_arn` | Grafana가 AMP에서 읽기 위한 IAM Role ARN |
| `grafana_amp_reader_role_name` | Grafana IAM Role 이름 |

### 설정 참조
| 출력 이름 | 설명 |
|-----------|------|
| `adot_collector_config_template` | ADOT Collector 설정 템플릿 (JSON) |
| `grafana_setup_info` | Grafana 데이터 소스 설정 정보 |

전체 출력 목록은 [outputs.tf](./outputs.tf) 파일을 참조하세요.

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
