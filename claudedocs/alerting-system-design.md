# 알림 체계 설계 문서

## 개요

IN-118 태스크의 일환으로 중앙 관측성 시스템(EPIC 3)에 통합 알림 체계를 구축합니다. AMP/AMG 모니터링 시스템과 연계하여 CloudWatch Alarm 기반의 3단계 알림 시스템을 Slack으로 전달합니다.

## 알림 레벨 정의

### Critical (즉시 대응 필요)
- **우선순위**: P0
- **대응 시간**: 즉시 (5분 이내)
- **대상**: 서비스 장애 또는 심각한 성능 저하
- **Slack 채널**: `#alerts-critical`
- **색상**: 🔴 Red

**기준**:
- ECS 태스크 완전 중단
- RDS 연결 불가 또는 CPU 90% 이상 지속
- ALB 5xx 에러율 10% 이상
- 핵심 서비스 다운

### Warning (주의 필요)
- **우선순위**: P1
- **대응 시간**: 30분 이내
- **대상**: 잠재적 문제 또는 성능 저하 징후
- **Slack 채널**: `#alerts-warning`
- **색상**: 🟡 Yellow

**기준**:
- ECS CPU/Memory 80% 이상
- RDS 연결 수 80% 임계값 도달
- ALB 응답 시간 증가 (p99 > 2초)
- 5xx 에러율 5% 이상

### Info (정보성)
- **우선순위**: P2
- **대응 시간**: 모니터링 및 추세 분석
- **대상**: 일반적인 운영 정보 및 변경사항
- **Slack 채널**: `#alerts-info`
- **색상**: 🔵 Blue

**기준**:
- 정기 배포 알림
- Auto Scaling 이벤트
- 백업 완료/실패
- 일일 시스템 헬스 체크

## SNS Topic 구조

### Topic 명명 규칙
```
{environment}-monitoring-{severity}
```

### Topic 리스트
1. **prod-monitoring-critical**
   - 용도: Critical 알람 수신
   - 구독자: AWS Chatbot (Slack #alerts-critical), Email (on-call)

2. **prod-monitoring-warning**
   - 용도: Warning 알람 수신
   - 구독자: AWS Chatbot (Slack #alerts-warning)

3. **prod-monitoring-info**
   - 용도: Info 알람 수신
   - 구독자: AWS Chatbot (Slack #alerts-info)

### SNS Topic 속성
- **암호화**: KMS 암호화 적용 (기존 monitoring KMS key 사용)
- **태그**: Team, Environment, ManagedBy
- **메시지 보존**: 기본 설정 (재시도 정책 포함)

## AWS Chatbot 연동

### Chatbot 구성
- **서비스**: AWS Chatbot
- **플랫폼**: Slack
- **역할**: CloudWatch Logs 읽기 권한 포함
- **채널 매핑**:
  - Critical SNS → #alerts-critical
  - Warning SNS → #alerts-warning
  - Info SNS → #alerts-info

### Slack 메시지 포맷
```
[{SEVERITY}] {ALARM_NAME}

Resource: {RESOURCE_TYPE} - {RESOURCE_NAME}
Metric: {METRIC_NAME}
Threshold: {THRESHOLD}
Current Value: {CURRENT_VALUE}

Runbook: {RUNBOOK_URL}
Dashboard: {GRAFANA_DASHBOARD_URL}
```

## CloudWatch Alarm 정의

### ECS 알람

#### Critical
1. **ECS Task Count Zero**
   - 메트릭: `DesiredTaskCount = 0`
   - 조건: 1분간 0개
   - 설명: 모든 태스크 중단

2. **ECS High Memory**
   - 메트릭: `MemoryUtilization`
   - 조건: 5분간 평균 95% 이상
   - 설명: 메모리 고갈 위험

#### Warning
1. **ECS High CPU**
   - 메트릭: `CPUUtilization`
   - 조건: 10분간 평균 80% 이상
   - 설명: CPU 부하 증가

2. **ECS Memory Warning**
   - 메트릭: `MemoryUtilization`
   - 조건: 10분간 평균 80% 이상
   - 설명: 메모리 사용량 증가

### RDS 알람

#### Critical
1. **RDS Connection Failed**
   - 메트릭: `DatabaseConnections`
   - 조건: 최대 연결 수 95% 이상
   - 설명: 연결 풀 고갈

2. **RDS CPU Critical**
   - 메트릭: `CPUUtilization`
   - 조건: 5분간 평균 90% 이상
   - 설명: DB 성능 저하

#### Warning
1. **RDS High Latency**
   - 메트릭: `ReadLatency` 또는 `WriteLatency`
   - 조건: 5분간 평균 50ms 이상
   - 설명: 쿼리 지연 증가

2. **RDS Free Memory Low**
   - 메트릭: `FreeableMemory`
   - 조건: 1GB 미만
   - 설명: 메모리 부족

### ALB 알람

#### Critical
1. **ALB High 5xx Error Rate**
   - 메트릭: `HTTPCode_Target_5XX_Count` / `RequestCount`
   - 조건: 5분간 10% 이상
   - 설명: 서버 에러 급증

2. **ALB No Healthy Targets**
   - 메트릭: `HealthyHostCount`
   - 조건: 0개
   - 설명: 모든 타겟 비정상

#### Warning
1. **ALB High Response Time**
   - 메트릭: `TargetResponseTime` (p99)
   - 조건: 5분간 2초 이상
   - 설명: 응답 시간 증가

2. **ALB Elevated 4xx Rate**
   - 메트릭: `HTTPCode_Target_4XX_Count` / `RequestCount`
   - 조건: 5분간 15% 이상
   - 설명: 클라이언트 에러 증가

## Runbook 구조

### Runbook 위치
```
docs/runbooks/
├── ecs-high-cpu.md
├── ecs-memory-critical.md
├── rds-connection-failed.md
├── rds-high-latency.md
├── alb-5xx-errors.md
└── alb-no-healthy-targets.md
```

### Runbook 템플릿
```markdown
# {ALARM_NAME} Runbook

## 알람 정보
- **심각도**: {SEVERITY}
- **대상 리소스**: {RESOURCE_TYPE}
- **메트릭**: {METRIC_NAME}

## 증상
{SYMPTOM_DESCRIPTION}

## 영향 범위
{IMPACT_DESCRIPTION}

## 즉시 대응 절차
1. {STEP_1}
2. {STEP_2}
3. {STEP_3}

## 근본 원인 분석
- {ROOT_CAUSE_1}
- {ROOT_CAUSE_2}

## 관련 대시보드
- [Grafana Dashboard]({GRAFANA_URL})
- [CloudWatch Metrics]({CLOUDWATCH_URL})

## 에스컬레이션
- {ESCALATION_CONTACT}
```

## Terraform 구조

### 파일 구성
```
terraform/monitoring/
├── alerting.tf          # SNS Topics, CloudWatch Alarms
├── chatbot.tf           # AWS Chatbot 설정
└── variables.tf         # 알림 관련 변수 추가
```

### 주요 변수
```hcl
variable "slack_workspace_id" {
  description = "Slack Workspace ID for AWS Chatbot"
  type        = string
}

variable "slack_channel_ids" {
  description = "Slack Channel IDs for each severity level"
  type = map(string)
  default = {
    critical = "C0XXXXXXX"  # #alerts-critical
    warning  = "C0YYYYYYY"  # #alerts-warning
    info     = "C0ZZZZZZZ"  # #alerts-info
  }
}

variable "alarm_email" {
  description = "Email for critical alarms"
  type        = string
}
```

## 구현 순서

1. ✅ 설계 문서 작성 (현재)
2. SNS Topics 생성 (Terraform)
3. AWS Chatbot 설정 (Terraform + Manual Slack 연동)
4. CloudWatch Alarms 생성 (ECS 우선)
5. Runbook 문서 작성
6. 알림 테스트 (각 레벨별)
7. RDS/ALB 알람 추가
8. 운영 가이드 문서화

## 테스트 계획

### 단위 테스트
1. **SNS Topic 발행 테스트**
   ```bash
   aws sns publish \
     --topic-arn arn:aws:sns:region:account:prod-monitoring-critical \
     --message "Test message" \
     --subject "Test Alert"
   ```

2. **Chatbot 수신 확인**
   - Slack 채널에서 메시지 수신 확인
   - 메시지 포맷 검증

### 통합 테스트
1. **CloudWatch Alarm 트리거**
   - 의도적으로 임계값 초과 상황 생성
   - 알람 발생 → SNS → Slack 전체 플로우 검증

2. **알람 레벨별 라우팅**
   - Critical, Warning, Info 각각 올바른 채널로 전달되는지 확인

### 운영 테스트
1. **Runbook 절차 검증**
   - 실제 알람 발생 시 Runbook 단계 실행
   - 절차 정확성 및 완전성 확인

## 모니터링 및 개선

### 알림 품질 메트릭
- **False Positive Rate**: 오탐률 (목표: <5%)
- **Mean Time to Detect (MTTD)**: 문제 감지 시간 (목표: <5분)
- **Mean Time to Resolve (MTTR)**: 문제 해결 시간 (Critical: <30분)

### 개선 방향
- 알람 임계값 지속적 튜닝
- False Positive 감소
- 알람 피로도 관리 (Alert Fatigue)
- Runbook 정확도 향상

## 참고 자료

- [AWS SNS Documentation](https://docs.aws.amazon.com/sns/)
- [AWS Chatbot Documentation](https://docs.aws.amazon.com/chatbot/)
- [CloudWatch Alarms Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html)
- [Alerting Best Practices](https://sre.google/sre-book/monitoring-distributed-systems/)
