# CloudWatch Logs Naming Convention

CloudWatch Log Group 네이밍 표준 및 규칙

## 목적

- 일관된 로그 그룹 네이밍으로 관리 효율성 향상
- 로그 타입별 분리를 통한 향후 통합 (Sentry, Langfuse) 준비
- 비용 최적화를 위한 Retention 정책 적용 용이성
- CloudWatch Logs Insights 쿼리 효율성 향상

## 일반 원칙

### 기본 패턴
```
/aws/{service}/{resource-name}/{log-type}
```

### 구성 요소

| 요소 | 설명 | 예시 |
|------|------|------|
| `{service}` | AWS 서비스 유형 | `ecs`, `lambda`, `rds`, `alb` |
| `{resource-name}` | 리소스 이름 (kebab-case) | `atlantis`, `api-server`, `user-auth` |
| `{log-type}` | 로그 타입 구분 | `application`, `errors`, `llm`, `access` |

### 명명 규칙

1. **소문자만 사용**: 대문자 사용 금지
2. **kebab-case**: 단어 구분은 하이픈(`-`) 사용
3. **AWS 서비스 프리픽스**: `/aws/` 시작 (AWS 표준)
4. **계층 구조**: 슬래시(`/`)로 논리적 그룹핑
5. **간결성**: 불필요한 약어나 축약 지양

## 서비스별 네이밍 규칙

### 1. ECS (Elastic Container Service)

#### 일반 애플리케이션 로그
```
/aws/ecs/{service-name}/application
```

**예시:**
- `/aws/ecs/atlantis/application`
- `/aws/ecs/api-server/application`
- `/aws/ecs/user-service/application`

#### 에러 로그 (Sentry 연동 대상)
```
/aws/ecs/{service-name}/errors
```

**예시:**
- `/aws/ecs/api-server/errors`
- `/aws/ecs/user-service/errors`

**목적:**
- Subscription Filter를 통한 Sentry 실시간 에러 전송
- 장기 에러 패턴 분석 (90일 보관)

#### LLM 호출 로그 (Langfuse 연동 대상)
```
/aws/ecs/{service-name}/llm
```

**예시:**
- `/aws/ecs/api-server/llm`
- `/aws/ecs/chatbot/llm`

**목적:**
- LLM 호출 추적 (프롬프트, 응답, 토큰, 비용)
- Langfuse를 통한 프롬프트 최적화 및 비용 분석

### 2. Lambda Functions

#### 기본 Lambda 로그
```
/aws/lambda/{function-name}
```

**예시:**
- `/aws/lambda/secrets-manager-rotation`
- `/aws/lambda/api-gateway-authorizer`
- `/aws/lambda/cloudtrail-processor`

#### 에러 분리 (옵션)
```
/aws/lambda/{function-name}/errors
```

**사용 케이스:**
- 크리티컬 Lambda 함수
- 높은 에러율 예상 함수
- Sentry 통합 필요 함수

### 3. Application Load Balancer (ALB)

#### Access 로그
```
/aws/alb/{load-balancer-name}/access
```

**예시:**
- `/aws/alb/api-gateway/access`
- `/aws/alb/web-frontend/access`

#### Error 로그
```
/aws/alb/{load-balancer-name}/errors
```

**예시:**
- `/aws/alb/api-gateway/errors`

### 4. RDS (Relational Database Service)

#### Error 로그
```
/aws/rds/{db-identifier}/error
```

#### General 로그
```
/aws/rds/{db-identifier}/general
```

#### Slow Query 로그
```
/aws/rds/{db-identifier}/slowquery
```

**예시:**
- `/aws/rds/production-postgres/error`
- `/aws/rds/production-postgres/slowquery`

### 5. API Gateway

#### Execution 로그
```
/aws/apigateway/{api-name}/execution
```

#### Access 로그
```
/aws/apigateway/{api-name}/access
```

**예시:**
- `/aws/apigateway/rest-api/execution`
- `/aws/apigateway/rest-api/access`

### 6. CloudTrail

#### 조직 전체 이벤트
```
/aws/cloudtrail/organization
```

#### 특정 계정 이벤트
```
/aws/cloudtrail/{account-name}
```

**예시:**
- `/aws/cloudtrail/organization`
- `/aws/cloudtrail/production-account`

### 7. CodeBuild

```
/aws/codebuild/{project-name}
```

**예시:**
- `/aws/codebuild/infrastructure-pipeline`
- `/aws/codebuild/api-server-build`

### 8. Step Functions

```
/aws/states/{state-machine-name}
```

**예시:**
- `/aws/states/data-processing-pipeline`
- `/aws/states/order-fulfillment`

## 로그 타입 정의

### application
- **용도**: 일반 애플리케이션 로그
- **레벨**: INFO, WARN, ERROR, DEBUG
- **Retention**: 14일
- **내용**: 정상 동작 로그, 비즈니스 로직 추적

### errors
- **용도**: 에러 및 예외 로그만 분리
- **레벨**: ERROR, CRITICAL
- **Retention**: 90일
- **통합**: Sentry (실시간 알림 + 이슈 트래킹)
- **내용**: 스택 트레이스, 예외 메시지, 컨텍스트

### llm
- **용도**: LLM (Large Language Model) 호출 추적
- **Retention**: 60일
- **통합**: Langfuse (프롬프트 관리 + 비용 분석)
- **내용**:
  ```json
  {
    "timestamp": "2025-01-14T10:30:00Z",
    "model": "gpt-4",
    "prompt_tokens": 150,
    "completion_tokens": 300,
    "total_cost": 0.015,
    "latency_ms": 1200,
    "request_id": "req-abc123"
  }
  ```

### access
- **용도**: HTTP 액세스 로그 (ALB, API Gateway)
- **Retention**: 7일
- **내용**: IP, User-Agent, 요청 경로, 응답 코드, 레이턴시

### audit
- **용도**: 감사 추적 로그
- **Retention**: 365일
- **내용**: 사용자 행동, 권한 변경, 중요 데이터 접근

## Retention 정책

로그 타입별 기본 Retention 기간:

| 로그 타입 | Retention | 근거 |
|-----------|-----------|------|
| `errors` | 90일 | 장기 패턴 분석, 규정 준수 |
| `llm` | 60일 | 비용 추적, 프롬프트 최적화 |
| `application` | 14일 | 최근 이슈 디버깅 |
| `access` | 7일 | 트래픽 패턴 단기 분석 |
| `audit` | 365일 | 규정 준수, 보안 감사 |
| `slowquery` | 30일 | DB 성능 튜닝 |

**비용 최적화 노트**:
- 장기 보관 필요 시 S3 Export 고려 (90% 비용 절감)
- 불필요한 DEBUG 로그는 애플리케이션 레벨에서 필터링

## 태그 전략

모든 Log Group은 다음 태그 필수 적용:

```hcl
tags = merge(
  module.common_tags.tags,  # Environment, Service, Team, Owner, CostCenter, ManagedBy, Project
  {
    LogType          = "application" | "errors" | "llm" | "access" | "audit"
    RetentionDays    = "7" | "14" | "30" | "60" | "90" | "365"
    KMSEncrypted     = "true"
    ExportToS3       = "false" | "pending" | "enabled"
    SentrySync       = "pending" | "enabled" | "disabled"
    LangfuseSync     = "pending" | "enabled" | "disabled"
  }
)
```

## 마이그레이션 가이드

### 기존 로그 그룹 마이그레이션

#### 1단계: 신규 로그 그룹 생성
새로운 네이밍 규칙에 따라 Log Group 생성

#### 2단계: 애플리케이션 업데이트
로깅 설정을 신규 Log Group으로 변경

#### 3단계: 검증
신규 Log Group에 로그 정상 수집 확인

#### 4단계: 구 로그 그룹 삭제
데이터 Export 후 구 Log Group 삭제 (선택)

### 예시: ECS Task Definition 업데이트

**Before:**
```json
{
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/api-server",
      "awslogs-region": "ap-northeast-2",
      "awslogs-stream-prefix": "ecs"
    }
  }
}
```

**After:**
```json
{
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/aws/ecs/api-server/application",
      "awslogs-region": "ap-northeast-2",
      "awslogs-stream-prefix": "ecs"
    }
  }
}
```

## 검증 체크리스트

새로운 Log Group 생성 시 확인사항:

- [ ] 네이밍 규칙 준수 (`/aws/{service}/{resource}/{log-type}`)
- [ ] kebab-case 사용 (소문자 + 하이픈)
- [ ] Retention 정책 적용
- [ ] KMS 암호화 활성화
- [ ] 필수 태그 적용 (common_tags + 로그 특화 태그)
- [ ] IAM 권한 설정 (최소 권한 원칙)
- [ ] 로그 수집 정상 동작 확인

## 참고 자료

- [AWS CloudWatch Logs Naming Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html)
- [프로젝트 Naming Convention](./NAMING_CONVENTION.md)
- [Tagging Standards](./TAGGING_STANDARDS.md)
- [IN-116 설계 문서](../claudedocs/IN-116-logging-system-design.md)
