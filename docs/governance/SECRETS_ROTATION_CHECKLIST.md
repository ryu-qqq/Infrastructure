# Secrets Rotation 운영 체크리스트

**작성일**: 2025-10-20  
**목적**: RDS 및 기타 시크릿 로테이션 시 무중단 운영을 위한 검증 체크리스트

---

## 📋 개요

AWS Secrets Manager의 자동 로테이션은 보안 강화를 위해 필수적이지만, 잘못 구현하면 **프로덕션 서비스 장애**를 유발할 수 있습니다. 이 문서는 현재 인프라의 로테이션 메커니즘 분석 결과와 운영 시 확인해야 할 체크리스트를 제공합니다.

---

## 🔍 현재 구현 분석

### 로테이션 프로세스 (4단계)

```
Lambda Function: terraform/secrets/lambda/rotation.py

1. createSecret
   - 새 비밀번호 생성
   - Secrets Manager에 AWSPENDING 버전으로 저장
   - RDS는 아직 이전 비밀번호 사용 중

2. setSecret
   - rds_client.modify_db_instance(ApplyImmediately=True)
   - ⚠️ 이 시점에 RDS 비밀번호가 즉시 변경됨
   - 하지만 애플리케이션은 아직 이전 비밀번호를 캐싱 중일 수 있음

3. testSecret
   - 새 비밀번호로 연결 테스트
   - 검증 성공 시 다음 단계로

4. finishSecret
   - AWSPENDING → AWSCURRENT로 버전 변경
   - 이제부터 GetSecretValue() 호출 시 새 비밀번호 반환
```

### 타임라인 위험 구간

```
T0 [createSecret]
   └─ 새 비밀번호 생성 (AWSPENDING)
   └─ RDS: oldpass / App: oldpass ✅

T1 [setSecret]
   └─ RDS 비밀번호 변경: oldpass → newpass
   └─ RDS: newpass / App: oldpass ❌ 위험 구간 시작!
   
T2 [testSecret]
   └─ Lambda는 newpass로 연결 성공
   └─ RDS: newpass / App: oldpass ❌ 여전히 위험
   
T3 [finishSecret]
   └─ AWSCURRENT = newpass
   └─ RDS: newpass / App: 다음 조회 시 newpass ⚠️
   └─ 캐싱된 경우: 캐시 만료까지 oldpass 사용 ❌
```

---

## ⚠️ 식별된 위험 요소

### 1. 즉시 비밀번호 변경 (Critical)

**파일**: `terraform/secrets/lambda/rotation.py:271-275`

```python
rds_client.modify_db_instance(
    DBInstanceIdentifier=db_identifier,
    MasterUserPassword=secret_dict['password'],
    ApplyImmediately=True  # 🚨 즉시 적용
)
```

**문제점**:
- RDS는 즉시 새 비밀번호만 허용
- 애플리케이션은 아직 이전 비밀번호 사용 중
- **T1~T3 구간(수초~수분)에 DB 연결 실패 발생 가능**

**영향 범위**:
- [ ] ECS Task (장시간 실행 중인 컨테이너)
- [ ] Lambda Functions (warm container)
- [ ] 연결 풀을 사용하는 모든 애플리케이션
- [ ] 시크릿을 캐싱하는 애플리케이션

---

### 2. 시크릿 캐싱 정책 부재 (High)

**파일**: `claudedocs/secrets-management-strategy.md:454-485`

문서에는 캐싱 권장:
```python
# TTL 3600초 (1시간) 캐싱
secret_cache = SecretCache(ttl_seconds=3600)
```

**문제점**:
- Rotation 발생 시 최대 1시간 동안 옛날 비밀번호 사용
- 캐시 만료 전까지 DB 연결 실패 지속

**영향 평가**:
- [ ] 현재 서비스 코드에 시크릿 캐싱 구현되어 있는가?
- [ ] 캐싱 TTL은 얼마인가?
- [ ] Rotation 주기(90일)와 TTL이 적절히 조율되어 있는가?

---

### 3. ECS Task 환경변수 주입 방식 (Medium)

**예상 패턴**:
```hcl
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.db.arn}:password::"
      }
    ]
  }])
}
```

**문제점**:
- ECS는 Task 시작 시 한 번만 시크릿 조회
- Rotation 후에는 **Task 재시작 전까지 이전 비밀번호 사용**
- Rolling deployment 없이는 즉시 적용 불가

**확인 필요**:
- [ ] ECS Task Definition에서 secrets 사용 중인가?
- [ ] Task 재시작 전략이 있는가?
- [ ] Rotation 후 자동 재배포 메커니즘이 있는가?

---

### 4. 재시도 로직 부재 (Medium)

**문제점**:
- 애플리케이션에서 DB 연결 실패 시 재시도 로직이 없다면
- 인증 실패를 일시적 오류가 아닌 영구 오류로 간주
- 시크릿 재조회 기회 없음

**확인 필요**:
- [ ] DB 연결 실패 시 재시도 로직이 있는가?
- [ ] 재시도 시 시크릿을 재조회하는가?
- [ ] Exponential backoff가 구현되어 있는가?

---

## ✅ 운영 체크리스트

### Phase 1: 사전 점검 (Rotation 전)

#### 1.1 애플리케이션 코드 검증

- [ ] **시크릿 조회 방식 확인**
  ```bash
  # 서비스 레포지토리에서
  grep -r "secretsmanager" .
  grep -r "GetSecretValue" .
  grep -r "DB_PASSWORD" .
  ```

- [ ] **캐싱 구현 확인**
  ```bash
  # 캐싱 라이브러리 사용 여부
  grep -r "cache" . | grep -i secret
  grep -r "lru_cache" .
  grep -r "ttl" . | grep -i secret
  ```

- [ ] **재시도 로직 확인**
  ```bash
  # DB 연결 재시도 구현 여부
  grep -r "retry" . | grep -i "database\|db\|connection"
  grep -r "backoff" .
  ```

#### 1.2 인프라 설정 검증

- [ ] **RDS 연결 현황 파악**
  ```bash
  # 현재 활성 연결 수 확인
  aws rds describe-db-instances \
    --db-instance-identifier <instance-id> \
    --query 'DBInstances[0].DBInstanceStatus'
  ```

- [ ] **ECS Task 현황 확인**
  ```bash
  # 실행 중인 Task 목록
  aws ecs list-tasks --cluster <cluster-name>
  
  # Task가 사용 중인 시크릿 확인
  aws ecs describe-task-definition \
    --task-definition <task-def> \
    --query 'taskDefinition.containerDefinitions[*].secrets'
  ```

- [ ] **Lambda 함수 확인**
  ```bash
  # RDS 접근하는 Lambda 목록
  aws lambda list-functions \
    --query 'Functions[?Environment.Variables.DB_HOST].FunctionName'
  ```

#### 1.3 모니터링 설정

- [ ] **CloudWatch 알람 활성화 확인**
  ```bash
  # Rotation 실패 알람
  aws cloudwatch describe-alarms \
    --alarm-names "secrets-manager-rotation-failures"
  
  # RDS 연결 실패 알람
  aws cloudwatch describe-alarms | grep -i "database\|rds"
  ```

- [ ] **Lambda 로그 모니터링 준비**
  ```bash
  # Rotation Lambda 로그 그룹 확인
  aws logs describe-log-groups \
    --log-group-name-prefix "/aws/lambda/secrets-manager-rotation"
  ```

- [ ] **애플리케이션 로그 모니터링 준비**
  - DB 연결 실패 로그 필터 설정
  - Error rate 대시보드 준비

---

### Phase 2: Rotation 실행 중

#### 2.1 실시간 모니터링

- [ ] **Lambda 실행 로그 확인**
  ```bash
  aws logs tail /aws/lambda/secrets-manager-rotation --follow
  ```

- [ ] **RDS 연결 메트릭 모니터링**
  ```bash
  # DatabaseConnections 메트릭
  aws cloudwatch get-metric-statistics \
    --namespace AWS/RDS \
    --metric-name DatabaseConnections \
    --dimensions Name=DBInstanceIdentifier,Value=<instance-id> \
    --start-time $(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average
  ```

- [ ] **애플리케이션 에러율 확인**
  - 5xx 에러 급증 여부
  - DB 연결 실패 로그 증가 여부

#### 2.2 단계별 검증

- [ ] **createSecret 완료 확인**
  ```bash
  aws secretsmanager describe-secret \
    --secret-id /ryuqqq/rds/prod/master \
    --query 'VersionIdsToStages'
  
  # AWSPENDING 버전이 있는지 확인
  ```

- [ ] **setSecret 시점 주의**
  - 이 단계에서 RDS 비밀번호 변경됨
  - 애플리케이션 에러 로그 집중 모니터링

- [ ] **testSecret 완료 확인**
  - Lambda가 새 비밀번호로 연결 성공했는지 확인

- [ ] **finishSecret 완료 확인**
  ```bash
  aws secretsmanager describe-secret \
    --secret-id /ryuqqq/rds/prod/master \
    --query 'VersionIdsToStages'
  
  # AWSCURRENT가 새 버전을 가리키는지 확인
  ```

---

### Phase 3: Rotation 후 검증

#### 3.1 즉시 확인 (5분 이내)

- [ ] **Rotation 성공 여부**
  ```bash
  aws secretsmanager describe-secret \
    --secret-id /ryuqqq/rds/prod/master \
    --query 'RotationEnabled'
  
  aws secretsmanager describe-secret \
    --secret-id /ryuqqq/rds/prod/master \
    --query 'LastRotatedDate'
  ```

- [ ] **새 비밀번호로 직접 연결 테스트**
  ```bash
  # 새 비밀번호 조회
  NEW_PASS=$(aws secretsmanager get-secret-value \
    --secret-id /ryuqqq/rds/prod/master \
    --query 'SecretString' --output text | jq -r '.password')
  
  # MySQL 연결 테스트
  mysql -h <rds-endpoint> -u admin -p"$NEW_PASS" -e "SELECT 1"
  ```

- [ ] **애플리케이션 에러율 정상화 확인**
  - DB 연결 실패 로그 감소 확인
  - 5xx 에러율 정상 범위 복귀 확인

#### 3.2 단기 모니터링 (1시간)

- [ ] **ECS Task 상태 확인**
  ```bash
  # Task 재시작이 필요한 경우
  aws ecs list-tasks --cluster <cluster-name> \
    --desired-status RUNNING
  
  # Task 재시작 (필요 시)
  aws ecs update-service \
    --cluster <cluster-name> \
    --service <service-name> \
    --force-new-deployment
  ```

- [ ] **Lambda 함수 상태 확인**
  ```bash
  # Warm container가 새 비밀번호 사용하는지 확인
  # 필요 시 동시성 설정으로 강제 재시작
  aws lambda put-function-concurrency \
    --function-name <function-name> \
    --reserved-concurrent-executions 0
  
  # 잠시 후 복구
  aws lambda delete-function-concurrency \
    --function-name <function-name>
  ```

- [ ] **캐시 만료 대기**
  - 시크릿 캐싱 TTL만큼 대기 (예: 1시간)
  - 해당 시간 동안 에러 로그 모니터링

#### 3.3 장기 모니터링 (24시간)

- [ ] **RDS 성능 메트릭 확인**
  - DatabaseConnections
  - ReadLatency / WriteLatency
  - CPUUtilization

- [ ] **애플리케이션 메트릭 확인**
  - API 응답 시간
  - 에러율
  - 처리량

- [ ] **CloudTrail 감사 로그 확인**
  ```bash
  aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=EventName,AttributeValue=GetSecretValue \
    --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
    --max-results 50
  ```

---

## 🚨 긴급 롤백 절차

Rotation 후 장애 발생 시:

### 1. 즉시 이전 버전으로 복구

```bash
# 1. 모든 버전 ID 확인
aws secretsmanager list-secret-version-ids \
  --secret-id /ryuqqq/rds/prod/master

# 2. 이전 AWSCURRENT 버전 찾기 (AWSPREVIOUS)
PREVIOUS_VERSION=$(aws secretsmanager describe-secret \
  --secret-id /ryuqqq/rds/prod/master \
  --query 'VersionIdsToStages' --output json | \
  jq -r 'to_entries[] | select(.value[] == "AWSPREVIOUS") | .key')

# 3. 이전 버전으로 롤백
aws secretsmanager update-secret-version-stage \
  --secret-id /ryuqqq/rds/prod/master \
  --version-stage AWSCURRENT \
  --move-to-version-id $PREVIOUS_VERSION

# 4. RDS 비밀번호도 롤백
OLD_PASS=$(aws secretsmanager get-secret-value \
  --secret-id /ryuqqq/rds/prod/master \
  --version-id $PREVIOUS_VERSION \
  --query 'SecretString' --output text | jq -r '.password')

aws rds modify-db-instance \
  --db-instance-identifier <instance-id> \
  --master-user-password "$OLD_PASS" \
  --apply-immediately
```

### 2. 서비스 재시작

```bash
# ECS 서비스 강제 재배포
aws ecs update-service \
  --cluster <cluster-name> \
  --service <service-name> \
  --force-new-deployment

# Lambda 동시성 재설정 (warm container 제거)
aws lambda put-function-concurrency \
  --function-name <function-name> \
  --reserved-concurrent-executions 0

sleep 10

aws lambda delete-function-concurrency \
  --function-name <function-name>
```

### 3. 사후 분석

- [ ] CloudWatch Logs에서 실패 원인 분석
- [ ] Rotation Lambda 로그 확인
- [ ] 애플리케이션 에러 로그 수집
- [ ] 타임라인 재구성
- [ ] 개선 방안 수립

---

## 🔧 개선 권장 사항

### 즉시 적용 가능 (Quick Wins)

1. **[ ] Rotation 시간대 조정**
   ```hcl
   # terraform/secrets/main.tf
   # 업무 외 시간으로 설정 (예: 새벽 3-4시)
   resource "aws_secretsmanager_secret_rotation" "db-master" {
     rotation_rules {
       automatically_after_days = 90
       # schedule_expression = "cron(0 3 ? * SUN *)"  # 매주 일요일 새벽 3시
     }
   }
   ```

2. **[ ] CloudWatch 알람 강화**
   ```hcl
   # 추가 알람 생성
   resource "aws_cloudwatch_metric_alarm" "db_connection_failures" {
     alarm_name          = "rds-connection-failures-spike"
     comparison_operator = "GreaterThanThreshold"
     evaluation_periods  = 2
     metric_name         = "DatabaseConnections"
     namespace           = "AWS/RDS"
     period              = 60
     statistic           = "Average"
     threshold           = 0
     treat_missing_data  = "notBreaching"
     
     dimensions = {
       DBInstanceIdentifier = "<instance-id>"
     }
   }
   ```

3. **[ ] Runbook 작성**
   - Rotation 실행 전 체크리스트 (이 문서)
   - 장애 발생 시 대응 절차
   - 담당자 연락처

### 단기 개선 (1-2주)

1. **[ ] Rotation Lambda 개선**
   ```python
   # terraform/secrets/lambda/rotation.py
   
   import time
   
   def setSecret(client, arn, token, secret_type):
       """Update target system with new credentials"""
       pending_secret = client.get_secret_value(
           SecretId=arn, 
           VersionId=token, 
           VersionStage="AWSPENDING"
       )
       pending_dict = json.loads(pending_secret['SecretString'])
   
       if secret_type == 'rds':
           set_rds_password(pending_dict)
           
           # 🔧 개선: setSecret과 finishSecret 사이 대기 시간 추가
           logger.info("Waiting 30 seconds before proceeding to testSecret...")
           time.sleep(30)  # 애플리케이션이 재시도할 시간 확보
   ```

2. **[ ] 애플리케이션에 재시도 로직 추가**
   ```python
   # 서비스 레포지토리에 추가
   import time
   from functools import wraps
   
   def retry_on_auth_failure(max_retries=3, backoff=2):
       def decorator(func):
           @wraps(func)
           def wrapper(*args, **kwargs):
               last_exception = None
               for attempt in range(max_retries):
                   try:
                       return func(*args, **kwargs)
                   except DatabaseAuthError as e:
                       last_exception = e
                       logger.warning(
                           f"Auth failure (attempt {attempt + 1}/{max_retries}). "
                           f"Refreshing credentials..."
                       )
                       # 시크릿 재조회
                       refresh_db_credentials()
                       if attempt < max_retries - 1:
                           time.sleep(backoff ** attempt)
               raise last_exception
           return wrapper
       return decorator
   
   @retry_on_auth_failure()
   def get_db_connection():
       return db.connect(**get_db_credentials())
   ```

3. **[ ] 시크릿 캐싱 TTL 단축**
   ```python
   # 3600초 (1시간) → 300초 (5분)
   secret_cache = SecretCache(ttl_seconds=300)
   ```

### 중기 개선 (1-2개월)

1. **[ ] EventBridge로 자동 재배포**
   ```hcl
   # Rotation 완료 이벤트 감지 시 ECS Task 자동 재시작
   resource "aws_cloudwatch_event_rule" "rotation_completed" {
     name        = "secrets-rotation-completed"
     description = "Trigger on secrets rotation completion"
     
     event_pattern = jsonencode({
       source      = ["aws.secretsmanager"]
       detail-type = ["AWS API Call via CloudTrail"]
       detail = {
         eventName = ["RotateSecret"]
         responseElements = {
           ARN = [aws_secretsmanager_secret.db-master-password.arn]
         }
       }
     })
   }
   
   resource "aws_cloudwatch_event_target" "trigger_ecs_deployment" {
     rule      = aws_cloudwatch_event_rule.rotation_completed.name
     target_id = "TriggerECSDeployment"
     arn       = aws_lambda_function.trigger_deployment.arn
   }
   
   # Lambda: ECS 서비스 재배포 트리거
   resource "aws_lambda_function" "trigger_deployment" {
     function_name = "secrets-rotation-ecs-redeployment"
     # ... ECS update-service --force-new-deployment 실행
   }
   ```

2. **[ ] Multi-user rotation 구현**
   ```hcl
   # 읽기 전용 사용자는 별도 관리
   resource "aws_secretsmanager_secret" "db-readonly" {
     name = "${local.name_prefix}-readonly-password"
   }
   
   resource "aws_secretsmanager_secret_rotation" "db-readonly" {
     secret_id           = aws_secretsmanager_secret.db-readonly.id
     rotation_lambda_arn = aws_lambda_function.rotation.arn
     
     rotation_rules {
       automatically_after_days = 90
       # 마스터 계정과 다른 시간대
     }
   }
   ```

### 장기 개선 (3-6개월)

1. **[ ] RDS Proxy 도입**
   ```hcl
   resource "aws_db_proxy" "main" {
     name                   = "${local.name_prefix}-proxy"
     engine_family          = "MYSQL"
     auth {
       auth_scheme = "SECRETS"
       secret_arn  = aws_secretsmanager_secret.db-master-password.arn
     }
     role_arn               = aws_iam_role.proxy.arn
     vpc_subnet_ids         = var.private_subnet_ids
     require_tls            = true
   }
   ```
   
   **장점**:
   - 연결 풀링 자동 관리
   - Credential rotation 투명하게 처리
   - Failover 시간 단축

2. **[ ] Chaos Engineering 테스트**
   - 프로덕션 환경에서 실제 rotation 시뮬레이션
   - 애플리케이션 복원력 검증
   - 모니터링 및 알람 유효성 확인

---

## 📊 메트릭 및 KPI

### Rotation 성공률

```
목표: 99.9% 이상
측정: CloudWatch Logs Insights

fields @timestamp, @message
| filter @message like /Successfully completed finishSecret/
| stats count() as successful_rotations by bin(1d)
```

### Rotation 중 에러율

```
목표: 기준선 대비 10% 이내 증가
측정: 애플리케이션 로그

fields @timestamp, @message
| filter @message like /Database connection failed/
| stats count() as connection_errors by bin(5m)
```

### 평균 복구 시간 (MTTR)

```
목표: 5분 이내
측정: 수동 기록 및 분석
```

---

## 📚 참고 자료

- [AWS Secrets Manager Rotation Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [프로젝트 Secrets 전략 가이드](../claudedocs/secrets-management-strategy.md)
- [RDS 비밀번호 변경 문서](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBInstance.Modifying.html)

---

## 📝 변경 이력

| 날짜 | 작성자 | 변경 내용 |
|------|--------|----------|
| 2025-10-20 | Platform Team | 초기 작성 - 현재 rotation 메커니즘 분석 및 체크리스트 수립 |

---

## 🔖 체크리스트 요약

**Rotation 전**
- [ ] 애플리케이션 코드 분석 (시크릿 조회, 캐싱, 재시도)
- [ ] 인프라 현황 파악 (RDS, ECS, Lambda)
- [ ] 모니터링 준비

**Rotation 중**
- [ ] Lambda 로그 실시간 모니터링
- [ ] RDS 연결 메트릭 확인
- [ ] 애플리케이션 에러율 추적

**Rotation 후**
- [ ] Rotation 성공 검증
- [ ] 새 비밀번호 연결 테스트
- [ ] ECS Task 재시작 (필요 시)
- [ ] 24시간 모니터링

**개선 작업**
- [ ] Rotation Lambda 대기 시간 추가
- [ ] 애플리케이션 재시도 로직 구현
- [ ] CloudWatch 알람 강화
- [ ] EventBridge 자동 재배포 설정 (선택)
- [ ] RDS Proxy 도입 검토 (장기)
