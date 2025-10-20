# Secrets Rotation 개선 작업 TODO

**작성일**: 2025-10-20
**컨텍스트**: Gemini 리뷰 + 문서 분석 종합 결과
**우선순위**: 🔴 CRITICAL → 🟡 HIGH

---

## 📊 현재 상태 요약

**구현 완성도**: 90%
- ✅ Gemini 피드백 반영 완료 (Lambda egress VPC 제한, SQL injection 방지)
- ✅ 핵심 인프라 100% 완료
- ⚠️ 무중단 Rotation 보장 개선 필요

**남은 작업**:
1. 🔴 Lambda setSecret 대기 시간 30초 추가 (즉시)
2. 🟡 RDS 연결 실패 CloudWatch 알람 추가 (단기)

---

## 🔴 Priority 1: Lambda setSecret 대기 시간 추가 (CRITICAL)

### 문제점

**현재 코드** (`terraform/secrets/lambda/index.py:108-156`):
```python
def set_secret(secret_arn: str, token: str) -> None:
    # ... RDS 비밀번호 변경 ...
    cursor.execute(alter_user_sql, (username, new_password))
    cursor.execute("FLUSH PRIVILEGES")
    conn.commit()
    logger.info(f"setSecret: Successfully updated password")
    # ⚠️ 즉시 다음 단계로 진행 - 문제!
```

**위험 구간**:
```
T1 [setSecret] → RDS 비밀번호 즉시 변경
   RDS: newpass ❌ | App: oldpass (캐시) ❌ DB 연결 실패!

T2 [testSecret] → Lambda는 성공하지만
   RDS: newpass ✅ | App: oldpass (캐시) ❌ 여전히 실패

T3 [finishSecret] → 새 비밀번호 공개
   RDS: newpass ✅ | App: 캐시 만료까지 실패 가능
```

### 해결책

**파일**: `terraform/secrets/lambda/index.py`

**Step 1: import 추가** (파일 상단)
```python
import time  # 기존 imports 섹션에 추가
```

**Step 2: set_secret() 함수 수정** (Line 108-156)
```python
def set_secret(secret_arn: str, token: str) -> None:
    """
    Set the new password in the RDS database.

    Args:
        secret_arn: ARN of the secret
        token: Rotation token for this rotation
    """
    # Get pending secret
    pending_secret = secretsmanager.get_secret_value(
        SecretId=secret_arn,
        VersionId=token,
        VersionStage="AWSPENDING"
    )
    pending_dict = json.loads(pending_secret['SecretString'])

    # Get current secret for connection
    current_secret = secretsmanager.get_secret_value(
        SecretId=secret_arn,
        VersionStage="AWSCURRENT"
    )
    current_dict = json.loads(current_secret['SecretString'])

    # Connect to RDS with current credentials
    conn = get_connection(current_dict)

    try:
        with conn.cursor() as cursor:
            # Update password for the user
            username = pending_dict['username']
            new_password = pending_dict['password']

            # MySQL 5.7+ and 8.0 compatible password update
            # Fully parameterized to prevent SQL injection
            alter_user_sql = "ALTER USER %s@'%%' IDENTIFIED BY %s"
            cursor.execute(alter_user_sql, (username, new_password))

            # Flush privileges to ensure changes take effect
            cursor.execute("FLUSH PRIVILEGES")

            conn.commit()
            logger.info(f"setSecret: Successfully updated password for user: {username}")

            # 🔧 NEW: Wait to allow applications time to retry with new password
            # This prevents connection failures during the rotation window (T1-T3)
            logger.info("Waiting 30 seconds to allow application retry and cache refresh...")
            time.sleep(30)

    except Exception as e:
        logger.error(f"setSecret: Failed to update password: {str(e)}")
        raise
    finally:
        conn.close()
```

**변경 요약**:
- Line 18: `import time` 추가
- Line 149-151: 30초 대기 로직 추가 (총 3줄)

### 배포 절차

```bash
# 1. Lambda 코드 재빌드
cd terraform/secrets/lambda
./build.sh

# 2. Terraform 적용
cd ..
terraform init
terraform plan  # 변경사항 확인
terraform apply

# 3. Lambda 배포 확인
aws lambda get-function \
  --function-name secrets-manager-rotation \
  --region ap-northeast-2 \
  --query 'Configuration.LastModified'
```

### 테스트 방법

**⚠️ 주의: 비운영 시간대(새벽 2-4시)에 실행**

```bash
# 1. 사전 점검
./scripts/validators/check-secrets-rotation.sh --verbose

# 2. 수동 rotation 실행
aws secretsmanager rotate-secret \
  --secret-id prod-shared-mysql-master-password \
  --region ap-northeast-2

# 3. Lambda 로그 모니터링
aws logs tail /aws/lambda/secrets-manager-rotation --follow

# 4. 30초 대기 로그 확인
# 예상 로그:
# "setSecret: Successfully updated password for user: admin"
# "Waiting 30 seconds to allow application retry..."
# (30초 후)
# "testSecret: Successfully connected with new password"

# 5. 사후 검증
./scripts/validators/check-secrets-rotation.sh
```

### 검증 체크리스트

- [ ] Lambda 함수 재배포 완료
- [ ] CloudWatch Logs에서 30초 대기 로그 확인
- [ ] Rotation 성공 완료 (4단계 모두 성공)
- [ ] 애플리케이션 에러 로그 없음
- [ ] RDS 연결 메트릭 정상

### 예상 효과

- ✅ T1~T3 구간 애플리케이션 재시도 시간 확보
- ✅ 시크릿 캐시 갱신 대기 시간 제공
- ✅ 무중단 Rotation 보장 향상
- ✅ DB 연결 실패 최소화

---

## 🟡 Priority 2: RDS 연결 실패 CloudWatch 알람 추가 (HIGH)

### 목적

Rotation 중 RDS 연결 문제 조기 감지

### 구현 위치

**옵션 1**: `terraform/rds/cloudwatch.tf` (신규 파일 생성)
**옵션 2**: `terraform/rds/main.tf` (기존 파일에 추가)

### 추가할 리소스

```hcl
# RDS 연결 실패 감지 알람
resource "aws_cloudwatch_metric_alarm" "database_connection_failures" {
  alarm_name          = "${local.name_prefix}-rds-connection-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 10  # 연결 수가 10 이하로 떨어지면 알림
  alarm_description   = "Alert when database connections drop significantly during rotation. May indicate password rotation issue."
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = []  # TODO: SNS topic ARN 추가 필요

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-rds-connection-failures"
      Severity  = "high"
      Component = "database"
      Runbook   = "https://github.com/ryu-qqq/Infrastructure/wiki/RDS-Connection-Failures"
    }
  )
}

# 선택적: RDS CPU 사용률 급증 알람 (Rotation 부하 감지)
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${local.name_prefix}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when RDS CPU usage is high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = []

  tags = merge(
    local.required_tags,
    {
      Name      = "${local.name_prefix}-rds-high-cpu"
      Severity  = "medium"
      Component = "database"
    }
  )
}
```

### 변수 추가 (선택적)

**파일**: `terraform/rds/variables.tf`

```hcl
variable "connection_failure_threshold" {
  description = "Threshold for database connection failure alarm"
  type        = number
  default     = 10
}

variable "cpu_utilization_threshold" {
  description = "Threshold for RDS CPU utilization alarm"
  type        = number
  default     = 80
}
```

### 배포 절차

```bash
cd terraform/rds

# 1. 코드 변경 후 검증
terraform fmt
terraform validate

# 2. Plan 확인
terraform plan

# 3. Apply
terraform apply

# 4. 알람 생성 확인
aws cloudwatch describe-alarms \
  --alarm-name-prefix "prod-shared-mysql" \
  --region ap-northeast-2
```

### 검증 방법

```bash
# 알람 목록 확인
aws cloudwatch describe-alarms \
  --region ap-northeast-2 \
  --query 'MetricAlarms[?contains(AlarmName, `rds`)].{Name:AlarmName,State:StateValue}' \
  --output table

# 예상 출력:
# -----------------------------------------------------------------
# |                        DescribeAlarms                         |
# +----------------------------------------------+----------------+
# |                     Name                     |     State      |
# +----------------------------------------------+----------------+
# |  prod-shared-mysql-rds-connection-failures   |  OK            |
# |  prod-shared-mysql-rds-high-cpu              |  OK            |
# +----------------------------------------------+----------------+
```

---

## 📚 참고 문서

### 프로젝트 문서
- `docs/governance/README_SECRETS_ROTATION.md` - 문서 가이드
- `docs/governance/SECRETS_ROTATION_CHECKLIST.md` - 운영 체크리스트
- `docs/governance/SECRETS_ROTATION_CURRENT_STATUS.md` - 현황 분석

### 관련 파일
- `terraform/secrets/lambda/index.py` - Rotation Lambda 코드
- `terraform/secrets/rotation.tf` - Lambda 인프라
- `terraform/rds/secrets.tf` - RDS Secret + Rotation 설정
- `scripts/validators/check-secrets-rotation.sh` - 검증 스크립트

### 외부 참고
- [AWS Secrets Manager Rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [RDS Password Rotation Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets-rds.html)

---

## ⏸️ 연기된 작업 (참고용)

### Gemini 리뷰 피드백
- ✅ Issue #1: Lambda egress VPC CIDR 제한 (완료)
- ✅ Issue #2: SQL injection 방지 (완료)
- ⏸️ Issue #3: S3 bucket 변수화 (단일 환경, 불필요)
- ⏸️ Issue #4: IAM policy script (일회성 유틸리티)

### 문서 피드백
- ⏸️ EventBridge 자동 재배포 (복잡도 높음, 중기 과제)
- ⏸️ Multi-user rotation (현재 불필요)
- ⏸️ RDS Proxy 도입 (별도 Epic 필요)
- ⏸️ Chaos Engineering 테스트 (프로덕션 안정화 후)

---

## 🎯 작업 체크리스트

### 즉시 실행 (이번 주)
- [ ] `terraform/secrets/lambda/index.py` 수정 (import time + sleep 30)
- [ ] Lambda 재빌드 (`./build.sh`)
- [ ] Terraform apply
- [ ] 검증 스크립트 실행
- [ ] 비운영 시간대 테스트 rotation 실행
- [ ] CloudWatch Logs 확인 (30초 대기 로그)
- [ ] 결과 문서화

### 단기 실행 (다음 Sprint)
- [ ] `terraform/rds/cloudwatch.tf` 생성 (또는 main.tf에 추가)
- [ ] RDS 연결 실패 알람 추가
- [ ] 선택적: CPU/메모리 알람 추가
- [ ] Terraform apply
- [ ] 알람 생성 확인
- [ ] SNS topic 연동 (향후)

### 정기 점검
- [ ] 월 1회: `check-secrets-rotation.sh --verbose` 실행
- [ ] 분기 1회: Rotation 로그 분석 및 성공률 검토
- [ ] 반기 1회: 문서 업데이트 및 정책 검토

---

## 💡 주요 근거

### Lambda 대기 시간 추가 근거
1. **문서**: `SECRETS_ROTATION_CHECKLIST.md:483-503`
2. **문서**: `SECRETS_ROTATION_CURRENT_STATUS.md:186-211`
3. **위험**: T1~T3 구간 애플리케이션 DB 연결 실패 가능
4. **효과**: 재시도 및 캐시 갱신 시간 확보

### CloudWatch 알람 추가 근거
1. **문서**: `SECRETS_ROTATION_CHECKLIST.md:456-473`
2. **문서**: `SECRETS_ROTATION_CURRENT_STATUS.md:217-237`
3. **현황**: Rotation 중 DB 연결 문제 감지 불가
4. **효과**: 문제 조기 발견 및 대응

---

## 📞 문의 및 지원

- **긴급 상황**: `#platform-emergency` (Slack)
- **일반 문의**: `#platform-team` (Slack)
- **GitHub Issues**: [Infrastructure Repository](https://github.com/ryu-qqq/Infrastructure/issues)
- **관련 Epic**: [IN-159 - RDS Secrets Rotation](https://ryuqqq.atlassian.net/browse/IN-159)

---

**다음 세션 시작 시:**
1. 이 문서 읽기
2. Priority 1 작업부터 진행
3. 각 단계별 체크리스트 확인
4. 완료 후 이 문서 업데이트
