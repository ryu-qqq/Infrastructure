# IN-116: 중앙 로깅 시스템 설계 문서

## 📋 개요

Epic 3 (IN-99)의 첫 번째 태스크로, CloudWatch Logs 기반 중앙 로깅 시스템을 구축합니다.

### 목표
- CloudWatch Logs를 활용한 중앙 집중식 로그 수집 및 저장
- 일관된 로그 그룹 네이밍 및 Retention 정책 적용
- 비용 효율적인 로그 관리 체계 구축
- 향후 Sentry/Langfuse 통합을 고려한 확장 가능한 구조

## 🏗️ 현재 인프라 분석

### 기존 리소스
1. **ECS 서비스**
   - Atlantis ECS Cluster (Container Insights 활성화)
   - 로그: 암묵적으로 `/aws/ecs/atlantis-{env}` 사용 중

2. **Lambda 함수**
   - Secrets Manager Rotation Lambda
   - 로그 그룹: `/aws/lambda/secrets-manager-rotation` (14일 보관, KMS 암호화)
   - Retention 정책 및 KMS 암호화 이미 적용됨 ✅

3. **KMS 키**
   - Secrets Manager용 KMS 키 존재 (로그 암호화에 사용 중)
   - 로그 전용 KMS 키 필요 여부 검토 필요

### 관측 사항
- Lambda 로그는 이미 모범 사례 적용 (KMS 암호화, Retention)
- ECS 로그는 구조화 필요
- 통합 로그 네이밍 규칙 미정의
- 로그 타입별 분리 없음 (application, error, llm 등)

## 📐 설계 결정사항

### 1. Log Group 네이밍 규칙

#### 일반 원칙
```
/aws/{service}/{resource-name}/{log-type}
```

#### 서비스별 패턴

**ECS 서비스**
```
/aws/ecs/{service-name}/application  # 일반 애플리케이션 로그
/aws/ecs/{service-name}/errors       # 에러 로그 (향후 Sentry 연동 대상)
/aws/ecs/{service-name}/llm          # LLM 호출 로그 (향후 Langfuse 연동 대상)
```

**Lambda 함수**
```
/aws/lambda/{function-name}          # 기본 Lambda 로그
/aws/lambda/{function-name}/errors   # 에러만 분리 (필요시)
```

**ALB (Application Load Balancer)**
```
/aws/alb/{load-balancer-name}/access-logs
/aws/alb/{load-balancer-name}/error-logs
```

**RDS**
```
/aws/rds/{db-identifier}/error
/aws/rds/{db-identifier}/general
/aws/rds/{db-identifier}/slowquery
```

#### 예시
- Atlantis ECS: `/aws/ecs/atlantis/application`
- API 서버 ECS: `/aws/ecs/api/application`, `/aws/ecs/api/errors`, `/aws/ecs/api/llm`
- Rotation Lambda: `/aws/lambda/secrets-manager-rotation` (기존 유지)

### 2. Retention 정책

로그 타입 및 중요도에 따라 차등 적용:

| 로그 타입 | Retention | 근거 |
|-----------|-----------|------|
| **에러 로그** (`*/errors`) | 90일 | 장기 패턴 분석, 규정 준수 |
| **LLM 로그** (`*/llm`) | 60일 | 비용 추적, 성능 분석 |
| **일반 로그** (`*/application`) | 14일 | 최근 이슈 디버깅 |
| **Lambda 로그** | 14일 | 함수별 조정 가능 |
| **RDS 로그** | 30일 | DB 성능 분석 |
| **ALB 로그** | 7일 | 트래픽 패턴 분석 |

**비용 최적화 전략**:
- 14일 이후 로그는 S3 Export 고려 (향후 구현)
- CloudWatch Logs Insights로 주요 로그만 분석
- 에러 로그는 Sentry로 실시간 모니터링 (향후 구현)

### 3. KMS 암호화 전략

**옵션 A: 기존 Secrets Manager KMS 키 재사용**
- 장점: 키 관리 단순화, 비용 절감
- 단점: 권한 분리 어려움, 보안 관점에서 분리 권장

**옵션 B: 로그 전용 KMS 키 생성 (권장)**
- 장점: 권한 명확히 분리, 감사 추적 용이
- 단점: 추가 KMS 키 비용 ($1/month)
- **결정**: 로그 전용 KMS 키 생성 (데이터 분류 기준)

### 4. Log Group 태그 전략

모든 Log Group은 공통 태그 + 로그 특화 태그 적용:

```hcl
tags = merge(
  module.common_tags.tags,
  {
    LogType     = "application" | "errors" | "llm" | "access"
    RetentionDays = "14" | "30" | "60" | "90"
    ExportEnabled = "true" | "false"
    SentrySync    = "pending" | "enabled" | "disabled"
    LangfuseSync  = "pending" | "enabled" | "disabled"
  }
)
```

### 5. 향후 확장성 고려

#### Sentry 통합 준비
- 에러 로그 그룹 (`*/errors`) 별도 생성
- Subscription Filter 적용 가능한 구조
- Filter Pattern: `[timestamp, request_id, level="ERROR", ...]`

#### Langfuse 통합 준비
- LLM 로그 그룹 (`*/llm`) 별도 생성
- LLM 호출 메타데이터 구조화 (프롬프트, 응답, 토큰, 비용)
- JSON 로그 포맷 권장

## 🛠️ 구현 계획

### Phase 1: 기반 구조 (IN-116, 현재)
1. ✅ Log Group 네이밍 규칙 정의
2. 🔄 Terraform 모듈 생성
   - `modules/cloudwatch-log-group`: 재사용 가능한 로그 그룹 모듈
   - KMS 키 생성 또는 참조
   - Retention 정책 적용
   - 태그 자동화
3. 🔄 기존 서비스 로그 그룹 생성
   - ECS Atlantis
   - Lambda Rotation
4. 🔄 Logs Insights 쿼리 템플릿 작성

### Phase 2: Sentry 통합 (향후 IN-117)
- Subscription Filter 생성
- Lambda 변환 함수 구현
- Sentry API 연동

### Phase 3: Langfuse 통합 (향후 IN-118)
- LLM 로그 구조화
- Subscription Filter 생성
- Langfuse API 연동

## 📊 Logs Insights 쿼리 템플릿

### 1. 에러 로그 조회
```
fields @timestamp, @message, @logStream
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

### 2. 특정 Request ID 추적
```
fields @timestamp, @message
| filter @message like /request_id="abc123"/
| sort @timestamp asc
```

### 3. 응답 시간 분석
```
fields @timestamp, duration
| filter ispresent(duration)
| stats avg(duration), max(duration), min(duration) by bin(5m)
```

### 4. LLM 호출 비용 분석 (향후)
```
fields @timestamp, prompt_tokens, completion_tokens, total_cost
| filter ispresent(total_cost)
| stats sum(total_cost) as total, sum(prompt_tokens + completion_tokens) as tokens by bin(1h)
```

## 💰 비용 예측

### CloudWatch Logs 비용 (ap-northeast-2 기준)
- 데이터 수집: $0.76 per GB
- 저장: $0.033 per GB/월
- Logs Insights 쿼리: $0.0076 per GB 스캔

### 예상 월간 비용 (소규모 환경)
```
일일 로그 생성: 5 GB
월간 로그: 150 GB
- 수집: 150 GB × $0.76 = $114
- 저장 (14일 평균): 70 GB × $0.033 = $2.31
- 쿼리 (월 100GB): 100 GB × $0.0076 = $0.76
- KMS 키: $1
합계: ~$118/월
```

### 비용 절감 방안
1. Retention 기간 단축 (14일 → 7일): 50% 저장 비용 절감
2. S3 Export 활용: 장기 보관 시 90% 비용 절감
3. 로그 레벨 필터링: 불필요한 DEBUG 로그 제외

## 🔒 보안 고려사항

1. **암호화**
   - 전송 중: TLS 1.2+
   - 저장 중: KMS 암호화
   - 키 자동 rotation 활성화

2. **접근 제어**
   - IAM 역할 기반 접근
   - 최소 권한 원칙
   - CloudTrail로 로그 접근 감사

3. **민감 정보 보호**
   - 로그에 비밀번호/토큰 포함 금지
   - PII 데이터 마스킹 고려
   - Secrets Manager 참조만 로깅

## 📝 다음 단계

1. ✅ 설계 문서 작성 완료
2. 🔄 Log Group 네이밍 규칙 정의 (Task 3)
3. 🔄 Terraform 모듈 구현 (Task 4)
4. 🔄 기존 서비스 연동 (Task 7)
5. 🔄 문서화 및 쿼리 가이드 (Task 9)

## 📚 참고 자료

- [AWS CloudWatch Logs 요금](https://aws.amazon.com/cloudwatch/pricing/)
- [CloudWatch Logs Insights 쿼리 문법](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [로그 그룹 암호화 Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html)
- [Sentry CloudWatch 통합](https://docs.sentry.io/platforms/python/integrations/aws-lambda/)
- [Langfuse Logging Best Practices](https://langfuse.com/docs/integrations/langchain)
