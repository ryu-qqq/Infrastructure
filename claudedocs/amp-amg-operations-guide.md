# AMP/AMG 운영 가이드

Amazon Managed Prometheus (AMP)와 Amazon Managed Grafana (AMG) 기반 모니터링 시스템의 운영 및 관리 가이드입니다.

## 목차

1. [배포 절차](#배포-절차)
2. [일상 운영](#일상-운영)
3. [모니터링 및 알림](#모니터링-및-알림)
4. [문제 해결](#문제-해결)
5. [유지보수](#유지보수)
6. [비용 최적화](#비용-최적화)

---

## 배포 절차

### 초기 배포

#### 1. Terraform 배포

```bash
cd terraform/monitoring

# Terraform 초기화
terraform init

# 변수 확인
cat terraform.tfvars

# 계획 검토
terraform plan -out=tfplan

# 적용
terraform apply tfplan

# 주요 출력 값 저장
terraform output > outputs.txt
```

#### 2. AMP Workspace 확인

```bash
# AWS CLI로 Workspace 확인
aws amp list-workspaces --region ap-northeast-2

# 특정 Workspace 상세 정보
WORKSPACE_ID=$(terraform output -raw amp_workspace_id)
aws amp describe-workspace --workspace-id $WORKSPACE_ID
```

#### 3. AMG Workspace 설정

```bash
# Grafana Workspace 확인
GRAFANA_ID=$(terraform output -raw amg_workspace_id)
aws grafana describe-workspace --workspace-id $GRAFANA_ID

# Grafana Endpoint URL
GRAFANA_URL=$(terraform output -raw amg_workspace_endpoint)
echo "Grafana URL: $GRAFANA_URL"

# 브라우저에서 접속
open $GRAFANA_URL  # macOS
```

**Grafana 초기 설정**:
1. AWS SSO로 로그인
2. 관리자 권한으로 처음 로그인한 사용자가 Admin이 됨
3. Configuration → Data Sources → Add data source
4. "Amazon Managed Prometheus" 선택
5. 설정:
   - Name: `AMP-Infrastructure`
   - URL: AMP Workspace endpoint (terraform output 참조)
   - Authentication: `SigV4`
   - Default Region: `ap-northeast-2`
6. "Save & Test" 클릭

#### 4. ECS Task에 ADOT Collector 통합

**Atlantis Task Definition 수정 예시**:

```bash
# 현재 Task Definition 확인
aws ecs describe-task-definition \
  --task-definition atlantis-prod \
  --query 'taskDefinition.{family:family,revision:revision,containers:containerDefinitions[*].name}'

# 새로운 Task Definition JSON 준비 (ADOT 포함)
# terraform/monitoring/adot-ecs-integration.tf 참조
```

**Task Definition 업데이트 체크리스트**:
- [ ] ADOT Collector 컨테이너 추가
- [ ] Task Role을 `ecs-amp-writer` 역할로 변경
- [ ] CPU/Memory 할당 증가 (기존 + 256/512)
- [ ] 환경 변수 설정 (AMP_ENDPOINT, SERVICE_NAME 등)
- [ ] Health check 구성
- [ ] CloudWatch Logs 설정

#### 5. ECS Service 업데이트

```bash
# Service 업데이트 (새 Task Definition 사용)
aws ecs update-service \
  --cluster atlantis-prod \
  --service atlantis-service \
  --task-definition atlantis-prod:NEW_REVISION \
  --force-new-deployment

# 배포 상태 확인
aws ecs describe-services \
  --cluster atlantis-prod \
  --services atlantis-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'
```

---

## 일상 운영

### 메트릭 수집 상태 확인

#### ADOT Collector 로그 확인

```bash
# CloudWatch Logs Insights 쿼리
aws logs start-query \
  --log-group-name /aws/ecs/adot-collector \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /error/ | sort @timestamp desc | limit 20'
```

**정상 동작 지표**:
- Health check endpoint 응답: HTTP 200
- AMP remote write 성공 로그
- 에러 로그 없음

#### AMP 메트릭 쿼리

Grafana Explore 또는 AWS CLI로 확인:

```bash
# AWS CLI로 메트릭 쿼리
aws amp query-workspace \
  --workspace-id $WORKSPACE_ID \
  --query-string 'up' \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)
```

**Grafana Explore에서 확인**:
```promql
# ADOT Collector 동작 확인
up{job="application-metrics"}

# ECS Container 메트릭
container_cpu_usage_seconds_total

# 메트릭 수집 개수
count(up)
```

### Grafana 대시보드 관리

#### 대시보드 백업

```bash
# API를 통한 대시보드 내보내기 (향후 자동화)
# Grafana API Key 필요
```

#### 대시보드 버전 관리

- Grafana UI에서 Dashboard Settings → Versions
- 변경 사항 확인 및 이전 버전으로 복원 가능

### 사용자 관리

```bash
# AMG Workspace에 사용자 추가 (AWS SSO 기반)
aws grafana update-workspace-authentication \
  --workspace-id $GRAFANA_ID \
  --authentication-providers AWS_SSO

# 사용자에게 역할 할당 (Admin, Editor, Viewer)
# AWS Console > Amazon Managed Grafana > Workspaces > [Your Workspace] > Authentication
```

---

## 모니터링 및 알림

### AMP 모니터링

#### 쿼리 성능 확인

```bash
# AMP 쿼리 로그 확인 (활성화된 경우)
aws logs tail /aws/prometheus/infrastructure-metrics/query-logs --follow
```

#### 메트릭 수집량 확인

```bash
# CloudWatch 메트릭으로 AMP 사용량 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/Prometheus \
  --metric-name SampleCount \
  --dimensions Name=WorkspaceId,Value=$WORKSPACE_ID \
  --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

### AMG 모니터링

```bash
# Grafana 사용자 활동 확인
aws grafana list-workspace-users --workspace-id $GRAFANA_ID
```

### 알림 설정 (향후)

Alert Manager 구성 후:
1. SNS Topic 생성
2. Slack Webhook 연동
3. Alert Rules 정의
4. Contact Points 설정

---

## 문제 해결

### 문제 1: 메트릭이 AMP에 수집되지 않음

**증상**:
- Grafana에서 "No data" 표시
- AMP 쿼리 결과 비어있음

**원인 분석**:

```bash
# 1. ADOT Collector 로그 확인
aws logs tail /aws/ecs/adot-collector --follow

# 2. ECS Task 상태 확인
aws ecs list-tasks --cluster atlantis-prod --service atlantis-service
TASK_ARN=$(aws ecs list-tasks --cluster atlantis-prod --service atlantis-service --query 'taskArns[0]' --output text)
aws ecs describe-tasks --cluster atlantis-prod --tasks $TASK_ARN

# 3. IAM 역할 권한 확인
aws iam get-role --role-name prod-monitoring-ecs-amp-writer
aws iam list-attached-role-policies --role-name prod-monitoring-ecs-amp-writer
```

**해결 방법**:

1. **IAM 권한 문제**:
   ```bash
   # Task Role이 올바르게 설정되었는지 확인
   # aps:RemoteWrite 권한 필요
   ```

2. **네트워크 문제**:
   - Security Group에서 HTTPS 아웃바운드 (443) 허용 확인
   - VPC Endpoint 사용 시 라우팅 테이블 확인

3. **설정 문제**:
   - AMP_ENDPOINT 환경 변수 확인
   - ADOT 설정 파일 검증

### 문제 2: Grafana에서 데이터 소스 연결 실패

**증상**:
- "Data source not found" 에러
- "Unauthorized" 에러

**해결 방법**:

```bash
# 1. Grafana IAM 역할 확인
aws iam get-role --role-name prod-monitoring-grafana-amp-reader

# 2. AMP Workspace 상태 확인
aws amp describe-workspace --workspace-id $WORKSPACE_ID --query 'workspace.status'
```

Data Source 재설정:
1. Grafana UI → Configuration → Data Sources
2. 기존 Data Source 삭제
3. 새로 추가 (설정 단계 참조)

### 문제 3: ADOT Collector 메모리 부족 (OOM)

**증상**:
- ADOT 컨테이너 재시작 반복
- "memory_limiter" 경고 로그

**해결 방법**:

```bash
# Task Definition에서 ADOT 메모리 증가
# 512 MiB → 1024 MiB

# 또는 ADOT 설정에서 메모리 제한 조정
# adot-config.yaml의 memory_limiter 섹션 수정
```

### 문제 4: 비용 급증

**원인**:
- 메트릭 수집량 급증
- 고빈도 쿼리

**분석**:

```bash
# Cost Explorer API로 비용 확인
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '7 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter file://amp-cost-filter.json

# amp-cost-filter.json:
# {
#   "Dimensions": {
#     "Key": "SERVICE",
#     "Values": ["Amazon Managed Service for Prometheus"]
#   }
# }
```

**해결 방법**:
1. 불필요한 메트릭 필터링 (relabel_configs)
2. Scrape interval 증가 (30s → 60s)
3. Retention 기간 단축 (필요시)

---

## 유지보수

### 정기 점검 (월 1회)

#### 1. 리소스 사용량 검토

```bash
# AMP 메트릭 샘플 수
# CloudWatch Console > Metrics > AWS/Prometheus

# AMG 활성 사용자 수
aws grafana list-workspace-users --workspace-id $GRAFANA_ID --query 'length(users)'
```

#### 2. 로그 보존 정책 확인

```bash
# CloudWatch Log Groups 보존 기간 확인
aws logs describe-log-groups \
  --log-group-name-prefix /aws/ecs/adot \
  --query 'logGroups[*].{name:logGroupName,retention:retentionInDays}'
```

#### 3. IAM 권한 감사

```bash
# 사용되지 않는 권한 확인
# AWS IAM Access Analyzer 사용 권장
```

### 버전 업그레이드

#### ADOT Collector 업그레이드

```bash
# 최신 ADOT 버전 확인
# https://gallery.ecr.aws/aws-observability/aws-otel-collector

# terraform/monitoring/variables.tf 수정
# adot_image_version = "v0.42.0" → "v0.43.0"

# Terraform 적용
cd terraform/monitoring
terraform plan
terraform apply

# ECS Task Definition 업데이트 및 배포
```

#### AMG 업그레이드

AMG는 자동으로 Grafana 버전 업그레이드 (Major 버전은 수동 승인)

```bash
# 현재 Grafana 버전 확인
aws grafana describe-workspace \
  --workspace-id $GRAFANA_ID \
  --query 'workspace.grafanaVersion'
```

### 백업 및 복구

#### Terraform State 백업

```bash
# S3 버전 관리 활성화 확인
aws s3api get-bucket-versioning --bucket prod-connectly

# 정기적인 State 백업
terraform state pull > backup-$(date +%Y%m%d).tfstate
```

#### Grafana 대시보드 백업

```bash
# 수동 백업 (API를 통한 자동화 가능)
# Grafana UI > Dashboard > Settings > JSON Model > Copy
```

---

## 비용 최적화

### 현재 비용 구조

| 항목 | 단가 | 예상 사용량 | 월 비용 |
|------|------|-------------|---------|
| AMP 메트릭 수집 | $0.0003/샘플 | 100만 샘플/일 | $9 |
| AMP 메트릭 저장 | $0.03/GB/월 | 10GB | $0.3 |
| AMP 쿼리 | $0.00001/샘플 | 500만 샘플/일 | $1.5 |
| AMG Editor | $9/사용자/월 | 1-2명 | $9-18 |
| **총계** | | | **$20-30** |

### 비용 절감 전략

#### 1. 메트릭 필터링

**불필요한 메트릭 제외**:

```yaml
# adot-config.yaml의 metric_relabel_configs
metric_relabel_configs:
  # Debug 메트릭 제외
  - source_labels: [__name__]
    regex: '.*_debug_.*'
    action: drop

  # 고빈도 메트릭 샘플링
  - source_labels: [__name__]
    regex: 'high_cardinality_metric'
    action: drop
```

#### 2. Scrape Interval 최적화

```yaml
# 일반 메트릭: 30s (기본)
scrape_interval: 30s

# 중요하지 않은 메트릭: 60s
- job_name: 'low-priority-metrics'
  scrape_interval: 60s
```

#### 3. Retention 정책

```bash
# Terraform에서 설정
amp_retention_period = 90  # 150일 → 90일로 단축 (필요시)
```

#### 4. AMG 사용자 최적화

- Editor는 최소한으로 유지 (1-2명)
- Viewer는 무료 (처음 5명)
- AWS SSO 그룹으로 관리

### 비용 모니터링

```bash
# Cost Anomaly Detection 설정
aws ce create-anomaly-monitor \
  --anomaly-monitor '{
    "MonitorName": "AMP-AMG-Cost-Monitor",
    "MonitorType": "CUSTOM",
    "MonitorSpecification": "{\"Dimensions\":{\"Key\":\"SERVICE\",\"Values\":[\"Amazon Managed Service for Prometheus\",\"Amazon Managed Grafana\"]}}"
  }'

# Budget 설정
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://monitoring-budget.json
```

---

## 추가 리소스

### 문서

- [AMP Documentation](https://docs.aws.amazon.com/prometheus/)
- [AMG Documentation](https://docs.aws.amazon.com/grafana/)
- [ADOT Documentation](https://aws-otel.github.io/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)

### 유용한 도구

- **promtool**: Prometheus 설정 검증
- **amtool**: Alert Manager 테스트
- **k6**: 부하 테스트 및 메트릭 생성
- **AWS Cost Explorer**: 비용 분석

### 지원

- **Platform Team**: platform-team@company.com
- **AWS Support**: AWS Console > Support Center
- **On-call**: PagerDuty (향후 구성)

---

## 변경 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|-----------|--------|
| 2024-10-14 | 1.0 | 초기 작성 | Platform Team |

---

**마지막 업데이트**: 2024-10-14
**문서 소유자**: Platform Team
**검토 주기**: 분기별
