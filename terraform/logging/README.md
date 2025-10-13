# Central Logging System

CloudWatch Logs 기반 중앙 로깅 시스템 - 표준화된 로그 수집, 암호화, Retention 정책 관리

## 📋 개요

IN-116 (EPIC 3: 중앙 관측성 시스템)의 일환으로 구축된 중앙 로깅 시스템입니다.

### 주요 기능

- ✅ CloudWatch Log Group 자동 생성
- ✅ KMS 암호화 (로그 전용 키)
- ✅ 로그 타입별 Retention 정책
- ✅ 표준화된 네이밍 규칙
- ✅ 향후 Sentry/Langfuse 통합 준비
- ✅ 90+ Logs Insights 쿼리 템플릿

## 🏗️ 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   ECS    │  │  Lambda  │  │   ALB    │  │   RDS    │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
└───────┼─────────────┼─────────────┼─────────────┼───────────┘
        │             │             │             │
        ▼             ▼             ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│              CloudWatch Logs (Central Hub)                   │
│                                                              │
│  ┌────────────────────┐  ┌────────────────────┐            │
│  │ /aws/ecs/*/        │  │ /aws/lambda/*      │            │
│  │ - application      │  │                     │            │
│  │ - errors (90d)     │  │                     │            │
│  │ - llm (60d)        │  │                     │            │
│  └────────────────────┘  └────────────────────┘            │
│                                                              │
│  KMS Encryption: alias/cloudwatch-logs                      │
└───────┬──────────────────────────────────────────────────────┘
        │
        ├──► Logs Insights (Query & Analysis)
        ├──► S3 Export (Long-term Archive) [Future]
        ├──► Sentry (Error Tracking) [Future]
        └──► Langfuse (LLM Observability) [Future]
```

## 📁 디렉토리 구조

```
terraform/logging/
├── main.tf           # Log Group 리소스 정의
├── variables.tf      # 입력 변수
├── outputs.tf        # 출력 변수
├── provider.tf       # Terraform & AWS 설정
└── README.md         # 이 파일

terraform/modules/cloudwatch-log-group/
├── main.tf           # 재사용 가능한 모듈
├── variables.tf
├── outputs.tf
└── README.md

docs/
├── LOGGING_NAMING_CONVENTION.md  # 네이밍 규칙
└── LOGS_INSIGHTS_QUERIES.md      # 쿼리 템플릿

claudedocs/
└── IN-116-logging-system-design.md  # 설계 문서
```

## 🚀 사용법

### 1. 사전 요구사항

- Terraform >= 1.5.0
- AWS CLI 설정 완료
- KMS 모듈 배포 완료 (`terraform/kms`)
- Common Tags 모듈 존재

### 2. 배포

```bash
cd terraform/logging

# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply
```

### 3. 로그 그룹 확인

```bash
# AWS CLI로 확인
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/" \
  --region ap-northeast-2

# Terraform으로 확인
terraform output log_groups_summary
```

## 📊 생성되는 리소스

### Log Groups

| 이름 | 타입 | Retention | KMS | 목적 |
|------|------|-----------|-----|------|
| `/aws/ecs/atlantis/application` | application | 14일 | ✅ | Atlantis 일반 로그 |
| `/aws/ecs/atlantis/errors` | errors | 90일 | ✅ | Atlantis 에러 로그 (Sentry 연동 대상) |
| `/aws/lambda/secrets-manager-rotation` | application | 14일 | ✅ | Lambda 로그 |

### KMS Keys

- **alias/cloudwatch-logs**: CloudWatch Logs 전용 KMS 키 (자동 rotation)

## 🔧 커스터마이징

### 새로운 서비스 추가

`main.tf`에 모듈 추가:

```hcl
module "new_service_logs" {
  source = "../modules/cloudwatch-log-group"

  name               = "/aws/ecs/new-service/application"
  retention_in_days  = 14
  kms_key_id         = data.terraform_remote_state.kms.outputs.cloudwatch_logs_key_arn
  log_type           = "application"
  common_tags        = module.common_tags.tags
}
```

### Retention 변경

```hcl
retention_in_days = 30  # 7, 14, 30, 60, 90, 365 등
```

### 에러 모니터링 활성화

```hcl
module "error_logs" {
  # ... 기본 설정 ...

  enable_error_rate_metric = true
  metric_namespace         = "CustomLogs/MyService"
}
```

## 📖 Logs Insights 쿼리

### 최근 에러 조회

```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

### 성능 분석

```
fields @timestamp, duration
| filter ispresent(duration)
| stats avg(duration), p95(duration) by bin(5m)
```

**더 많은 쿼리**: [LOGS_INSIGHTS_QUERIES.md](../../../docs/LOGS_INSIGHTS_QUERIES.md) 참고

## 🔐 보안

- ✅ KMS 암호화 (전송 중 & 저장 중)
- ✅ 자동 키 rotation
- ✅ IAM 역할 기반 접근 제어
- ✅ CloudTrail 감사 추적
- ✅ 최소 권한 원칙

## 💰 비용 최적화

### 현재 설정 (월간 예상)

```
일일 로그: 5 GB
월간 로그: 150 GB

- 데이터 수집: 150 GB × $0.76 = $114
- 저장 (평균 70 GB): 70 GB × $0.033 = $2.31
- Insights 쿼리 (100 GB): 100 GB × $0.0076 = $0.76
- KMS 키: $1
총계: ~$118/월
```

### 비용 절감 방안

1. **Retention 단축**: 14일 → 7일 (50% 저장 비용 절감)
2. **S3 Export**: 장기 보관 시 90% 비용 절감
3. **로그 필터링**: 불필요한 DEBUG 로그 제외
4. **Subscription Filter**: Sentry로 에러만 실시간 전송

## 🚧 향후 계획

### Phase 2: Sentry 통합 (IN-117)

- Subscription Filter 생성
- Lambda 변환 함수
- Sentry API 연동

### Phase 3: Langfuse 통합 (IN-118)

- LLM 로그 구조화
- Langfuse API 연동
- 비용 추적 대시보드

### Phase 4: S3 Export

- 장기 보관용 자동 Export
- Lifecycle 정책
- Athena 쿼리 지원

## 📝 변경 이력

- **2025-01-14**: IN-116 초기 구축
  - CloudWatch Log Groups 생성
  - KMS 암호화 적용
  - Retention 정책 설정
  - 네이밍 규칙 표준화

## 🔗 관련 문서

- [로깅 네이밍 규칙](../../../docs/LOGGING_NAMING_CONVENTION.md)
- [Logs Insights 쿼리 템플릿](../../../docs/LOGS_INSIGHTS_QUERIES.md)
- [설계 문서](../../../claudedocs/IN-116-logging-system-design.md)
- [태깅 표준](../../../docs/TAGGING_STANDARDS.md)
- [IN-116 Jira Task](https://ryuqqq.atlassian.net/browse/IN-116)
- [EPIC 3: 중앙 관측성 시스템](https://ryuqqq.atlassian.net/browse/IN-99)

## 🆘 문제 해결

### Log Group 생성 실패

```bash
# KMS 키 권한 확인
aws kms describe-key --key-id alias/cloudwatch-logs

# CloudWatch Logs 서비스 권한 확인
aws kms get-key-policy --key-id alias/cloudwatch-logs --policy-name default
```

### Terraform State 문제

```bash
# State 새로고침
terraform refresh

# 초기화 재실행
terraform init -upgrade
```

### 로그가 수집되지 않음

1. ECS Task Definition의 `logConfiguration` 확인
2. IAM 역할 권한 확인 (`logs:CreateLogStream`, `logs:PutLogEvents`)
3. KMS 키 권한 확인

## 👥 담당자

- **Owner**: Platform Team
- **Maintainer**: platform-team@example.com
- **Jira Epic**: [IN-99](https://ryuqqq.atlassian.net/browse/IN-99)
- **Jira Task**: [IN-116](https://ryuqqq.atlassian.net/browse/IN-116)
