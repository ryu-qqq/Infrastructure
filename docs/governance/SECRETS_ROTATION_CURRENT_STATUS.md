# Secrets Rotation 현황 분석

**분석일**: 2025-10-20  
**담당**: Platform Team

---

## 📊 현재 설정 상태

### 1. Secrets Manager 모듈 설정

**위치**: `terraform/secrets/`

| 설정 항목 | 값 | 상태 |
|----------|-----|------|
| `enable_rotation` | `true` (기본값) | ✅ 활성화 |
| `rotation_days` | `90` (기본값) | ✅ 90일 주기 |
| Lambda Function | `secrets-manager-rotation` | ✅ 배포됨 |
| CloudWatch Alarm | `rotation-failures` | ✅ 설정됨 |

### 2. Rotation Lambda 분석

**파일**: `terraform/secrets/lambda/rotation.py`

#### 구현된 기능
- ✅ 4단계 rotation 프로세스 (createSecret, setSecret, testSecret, finishSecret)
- ✅ RDS 비밀번호 자동 변경
- ✅ CloudWatch 로깅
- ✅ 에러 핸들링

#### 🚨 확인된 문제점

```python
# Line 271-275: 즉시 비밀번호 변경
rds_client.modify_db_instance(
    DBInstanceIdentifier=db_identifier,
    MasterUserPassword=secret_dict['password'],
    ApplyImmediately=True  # ⚠️ 문제: 즉시 적용
)
```

**영향**:
- RDS 비밀번호가 즉시 변경됨
- 애플리케이션이 아직 새 비밀번호를 모르는 상태
- T1(setSecret) ~ T3(finishSecret) 구간에 연결 실패 가능

### 3. RDS 모듈 설정

**위치**: `terraform/rds/secrets.tf`

```hcl
# Line 30-48: Secrets Manager Secret 생성
resource "aws_secretsmanager_secret" "db-master-password" {
  name                    = "${local.name_prefix}-master-password"
  kms_key_id              = data.aws_kms_key.secrets_manager.arn
  recovery_window_in_days = 0  # ⚠️ 즉시 삭제 (재생성 용이)
}

# Line 50-74: Secret Version (초기값)
resource "aws_secretsmanager_secret_version" "db-master-password" {
  secret_id = aws_secretsmanager_secret.db-master-password.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "mysql"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.database_name
  })
}

# Line 77-84: Remote State 참조
data "terraform_remote_state" "secrets" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "secrets/terraform.tfstate"
    region = var.aws_region
  }
}

# Line 87-100: Rotation 설정
resource "aws_secretsmanager_secret_rotation" "db-master-password" {
  count = var.enable_secrets_rotation ? 1 : 0
  
  secret_id           = aws_secretsmanager_secret.db-master-password.id
  rotation_lambda_arn = data.terraform_remote_state.secrets.outputs.rotation_lambda_arn
  
  rotation_rules {
    automatically_after_days = var.rotation_days  # 기본값: 30일
  }
}
```

**✅ 현재 상태**:
- ✅ **Rotation 설정 구현됨!**
- ✅ Remote state로 Secrets 모듈의 Lambda 참조
- ✅ `enable_secrets_rotation` 변수로 제어 가능 (기본값: true)
- ✅ `rotation_days` 변수로 주기 조정 가능 (기본값: 30일)
- ✅ Security Group에 Lambda 접근 규칙 포함

**⚠️ 주의사항**:
- RDS 모듈은 **30일 주기** (기본값)
- Secrets 모듈의 예제는 **90일 주기** (기본값)
- 프로젝트 표준 정책 확인 필요

---

## 🔍 상세 분석

### 시나리오 1: Secrets 모듈의 예제 시크릿

**위치**: `terraform/secrets/main.tf`

```hcl
# Line 50-63: DB Master Secret Rotation
resource "aws_secretsmanager_secret_rotation" "db-master" {
  count = var.enable_rotation ? 1 : 0  # ✅ 조건부 활성화
  
  secret_id           = aws_secretsmanager_secret.example-secrets["db_master"].id
  rotation_lambda_arn = aws_lambda_function.rotation.arn
  
  rotation_rules {
    automatically_after_days = var.rotation_days  # 90일
  }
}
```

**상태**: ✅ **Rotation 설정됨** (하지만 예제 시크릿에만 해당)

### 시나리오 2: 실제 RDS 시크릿

**위치**: `terraform/rds/secrets.tf`

```hcl
# RDS 시크릿 생성
resource "aws_secretsmanager_secret" "db-master-password" {
  name = "${local.name_prefix}-master-password"
  # ...
}

# ✅ Rotation 설정 있음!
resource "aws_secretsmanager_secret_rotation" "db-master-password" {
  count = var.enable_secrets_rotation ? 1 : 0
  
  secret_id           = aws_secretsmanager_secret.db-master-password.id
  rotation_lambda_arn = data.terraform_remote_state.secrets.outputs.rotation_lambda_arn
  
  rotation_rules {
    automatically_after_days = var.rotation_days  # 30일
  }
}
```

**상태**: ✅ **Rotation 설정됨** (조건부, 기본 활성화)

---

## 🎯 즉시 조치 필요 항목

### Priority 1: Critical (즉시)

#### 1. ~~RDS 시크릿에 Rotation 설정 추가~~ ✅ 완료됨

**파일**: `terraform/rds/secrets.tf`

**현재 상태**: ✅ Rotation 이미 구현됨  
**확인 필요**: Terraform 변수 설정 확인

```bash
# terraform.tfvars 또는 terraform.auto.tfvars 확인
cd terraform/rds
grep "enable_secrets_rotation" *.tfvars
grep "rotation_days" *.tfvars

# 기본값 사용 중이면:
# - enable_secrets_rotation = true (활성화)
# - rotation_days = 30 (30일 주기)
```

**⚠️ 확인 필요 사항**:
- [ ] Rotation이 실제로 활성화되어 있는가? (변수가 false로 오버라이드되지 않았는가?)
- [ ] Secrets 모듈이 배포되어 Lambda가 존재하는가?
- [ ] Remote state가 올바르게 참조되고 있는가?

#### 2. Rotation Lambda에 대기 시간 추가

**파일**: `terraform/secrets/lambda/rotation.py`

**현재 문제**: setSecret에서 즉시 RDS 비밀번호 변경  
**개선 방안**: testSecret 전 대기 시간 추가

```python
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
        
        # 🔧 개선: 30초 대기 추가
        logger.info("Waiting 30 seconds before testSecret...")
        time.sleep(30)
    
    logger.info(f"setSecret: Successfully updated target system for {arn}")
```

### Priority 2: High (1주 내)

#### 3. CloudWatch 알람 추가

**파일**: `terraform/rds/cloudwatch.tf` 또는 새 파일

```hcl
# RDS 연결 실패 알람
resource "aws_cloudwatch_metric_alarm" "database_connection_failures" {
  alarm_name          = "${local.name_prefix}-connection-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.connection_failure_threshold
  alarm_description   = "Alert when database connections drop significantly"
  
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
  
  alarm_actions = []  # SNS Topic ARN 추가 필요
}
```

#### 4. ~~RDS 모듈에 Rotation 변수 추가~~ ✅ 완료됨

**파일**: `terraform/rds/variables.tf`

**현재 상태**: ✅ 변수 이미 구현됨

```hcl
# Line 307-321 (이미 존재)
variable "enable_secrets_rotation" {
  description = "Enable automatic rotation for RDS master password"
  type        = bool
  default     = true
}

variable "rotation_days" {
  description = "Number of days between automatic password rotations"
  type        = number
  default     = 30  # ⚠️ Secrets 모듈(90일)과 다름
  validation {
    condition     = var.rotation_days >= 1 && var.rotation_days <= 365
    error_message = "Rotation days must be between 1 and 365."
  }
}
```

**주의**: RDS는 30일, Secrets 예제는 90일 - 정책 통일 권장

### Priority 3: Medium (2주 내)

#### 5. ~~Remote State 참조 설정~~ ✅ 완료됨

**파일**: `terraform/rds/secrets.tf` (Line 77-84)

**현재 상태**: ✅ Remote state 이미 구현됨

```hcl
data "terraform_remote_state" "secrets" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "secrets/terraform.tfstate"
    region = var.aws_region
  }
}
```

#### 6. Security Group 규칙 검증

**파일**: `terraform/rds/security-group.tf` (Line 57-74)

**현재 상태**: ✅ Lambda 접근 규칙 이미 구현됨

```hcl
resource "aws_vpc_security_group_ingress_rule" "from-rotation-lambda" {
  count = var.enable_secrets_rotation ? 1 : 0
  
  security_group_id = aws_security_group.rds.id
  
  description                  = "MySQL from Secrets Manager rotation Lambda"
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.terraform_remote_state.secrets.outputs.rotation_lambda_security_group_id
}
```

**확인 필요**: Lambda가 VPC에 배포되어 있고 Security Group ID가 output으로 노출되는가?

---

## 📋 검증 체크리스트

### 설정 검증

```bash
# 1. Secrets Manager에 시크릿이 존재하는지 확인
aws secretsmanager list-secrets \
  --query 'SecretList[?contains(Name, `rds`) || contains(Name, `master-password`)]' \
  --region ap-northeast-2

# 2. Rotation 설정 확인
aws secretsmanager describe-secret \
  --secret-id <secret-name> \
  --region ap-northeast-2 \
  --query '{Name:Name, RotationEnabled:RotationEnabled, RotationRules:RotationRules}'

# 3. Lambda 함수 존재 확인
aws lambda get-function \
  --function-name secrets-manager-rotation \
  --region ap-northeast-2

# 4. CloudWatch Alarm 확인
aws cloudwatch describe-alarms \
  --alarm-names "secrets-manager-rotation-failures" \
  --region ap-northeast-2
```

### 예상 결과

#### 현재 상태 (예상)
```json
{
  "Name": "/ryuqqq/rds/prod/master-password",
  "RotationEnabled": false,  // ❌ 비활성화
  "RotationRules": null
}
```

#### 개선 후 목표
```json
{
  "Name": "/ryuqqq/rds/prod/master-password",
  "RotationEnabled": true,   // ✅ 활성화
  "RotationRules": {
    "AutomaticallyAfterDays": 90
  }
}
```

---

## 🚀 구현 계획

### Phase 1: 현황 확인 (이번 주)

**목표**: RDS Rotation 활성화 상태 검증

1. **[ ] Rotation 설정 확인**
   ```bash
   # 1. RDS Secret 목록 조회
   aws secretsmanager list-secrets \
     --query 'SecretList[?contains(Name, `rds`) || contains(Name, `master-password`)].{Name:Name,RotationEnabled:RotationEnabled}' \
     --region ap-northeast-2 \
     --output table
   
   # 2. 특정 Secret의 Rotation 상세 확인
   aws secretsmanager describe-secret \
     --secret-id <secret-name> \
     --region ap-northeast-2 \
     --query '{Name:Name, RotationEnabled:RotationEnabled, RotationLambdaARN:RotationLambdaARN, RotationRules:RotationRules}'
   ```

2. **[ ] Lambda 함수 확인**
   ```bash
   # Rotation Lambda 존재 여부
   aws lambda get-function \
     --function-name secrets-manager-rotation \
     --region ap-northeast-2
   
   # VPC 설정 확인
   aws lambda get-function-configuration \
     --function-name secrets-manager-rotation \
     --region ap-northeast-2 \
     --query 'VpcConfig'
   ```

3. **[ ] Terraform State 확인**
   ```bash
   cd terraform/rds
   
   # Rotation 리소스가 State에 있는지 확인
   terraform state list | grep rotation
   
   # 변수 값 확인
   terraform console
   > var.enable_secrets_rotation
   > var.rotation_days
   ```

4. **[ ] 문제 발견 시 조치**
   - Rotation이 비활성화되어 있다면:
     ```bash
     cd terraform/rds
     # terraform.tfvars 또는 auto.tfvars에서 확인
     # enable_secrets_rotation = true 설정
     terraform plan
     terraform apply
     ```

### Phase 2: Lambda 개선 (다음 주)

**목표**: 무중단 rotation 구현

1. **[ ] rotation.py 수정**
   - setSecret에 대기 시간 추가
   - 에러 핸들링 강화
   - 로깅 개선

2. **[ ] Lambda 재배포**
   ```bash
   cd terraform/secrets/lambda
   ./build.sh
   cd ..
   terraform apply
   ```

3. **[ ] 테스트 rotation 실행**
   ```bash
   aws secretsmanager rotate-secret \
     --secret-id <test-secret> \
     --region ap-northeast-2
   ```

### Phase 3: 모니터링 강화 (2주차)

**목표**: 운영 안정성 확보

1. **[ ] CloudWatch 알람 추가**
   - RDS 연결 실패
   - Lambda 실행 시간 초과
   - Rotation 실패

2. **[ ] 대시보드 구성**
   - Secrets rotation 상태
   - RDS 연결 메트릭
   - 애플리케이션 에러율

3. **[ ] Runbook 작성**
   - 정기 rotation 절차
   - 장애 대응 절차
   - 롤백 절차

---

## 📊 위험도 평가

### 현재 상태 위험도: 🟡 Medium

**이유**:
1. ✅ RDS 시크릿에 rotation 구현됨
2. ⚠️ Rotation Lambda의 즉시 변경 로직 (무중단 보장 없음)
3. ⚠️ 실제 활성화 여부 검증 필요 (Terraform 변수 확인)
4. ⚠️ 애플리케이션 재시도 로직 미확인

### 개선 후 목표: 🟡 Medium

**개선 사항**:
1. ✅ RDS 시크릿 rotation 활성화
2. ✅ Lambda 대기 시간 추가
3. ✅ 모니터링 강화
4. ⚠️ 애플리케이션 재시도 로직은 서비스 레포에서 구현 필요

### 최종 목표: 🟢 Low

**추가 개선 필요**:
1. 서비스 레포에 재시도 로직 구현
2. EventBridge 자동 재배포 설정
3. RDS Proxy 도입 (선택)

---

## 🔗 관련 문서

- [Secrets Rotation 체크리스트](./SECRETS_ROTATION_CHECKLIST.md)
- [Secrets Management 전략](../../claudedocs/secrets-management-strategy.md)
- [KMS 전략 가이드](../../claudedocs/kms-strategy.md)

---

## 📞 담당자

**Platform Team**
- 긴급 문의: #platform-team (Slack)
- 이슈 보고: GitHub Issues

---

**다음 리뷰 예정일**: 2025-11-20 (개선 작업 완료 후 1개월)
