# Shared MySQL RDS Instance

운영 환경에서 여러 서비스가 공유하여 사용하는 MySQL RDS 인스턴스입니다.

## 📋 개요

이 인프라는 **플랫폼 수준의 공유 데이터베이스**로, 다음과 같은 특징을 가집니다:

- ✅ **Multi-AZ 고가용성**: 자동 페일오버로 99.95% 가용성 보장
- ✅ **자동 백업**: 14일 백업 보존 및 Point-in-Time Recovery
- ✅ **보안 강화**: KMS 암호화, Secrets Manager 비밀번호 관리
- ✅ **성능 모니터링**: Performance Insights, Enhanced Monitoring
- ✅ **자동 확장**: 스토리지 30GB → 200GB 자동 확장
- ✅ **CloudWatch 알람**: CPU, 메모리, 스토리지, 연결 수 모니터링

## 🏗️ 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    VPC (prod-server-vpc)                │
│  ┌───────────────────┐         ┌───────────────────┐   │
│  │  Private Subnet   │         │  Private Subnet   │   │
│  │  (ap-northeast-2a)│         │  (ap-northeast-2b)│   │
│  │                   │         │                   │   │
│  │  ┌────────────┐   │         │   ┌────────────┐ │   │
│  │  │ RDS Primary│◄──┼─────────┼──►│RDS Standby │ │   │
│  │  │  (Active)  │   │         │   │  (Passive) │ │   │
│  │  └─────▲──────┘   │         │   └────────────┘ │   │
│  └────────┼───────────┘         └──────────────────┘   │
│           │                                             │
│  ┌────────┼───────────────────────────────────────┐    │
│  │        │      Application Layer (ECS)          │    │
│  │  ┌─────▼──────┐  ┌──────────┐  ┌──────────┐   │    │
│  │  │  Service 1 │  │Service 2 │  │Service 3 │   │    │
│  │  └────────────┘  └──────────┘  └──────────┘   │    │
│  └───────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │   Secrets Manager    │
            │ (DB Credentials)     │
            └──────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │   CloudWatch Logs    │
            │ (error/general/slow) │
            └──────────────────────┘
```

## 📊 스펙 정보

| 항목 | 값 | 비고 |
|------|-----|------|
| **Instance Class** | db.t4g.small | 2 vCPU, 2GB RAM |
| **Storage** | 30GB → 200GB | gp3, 자동 확장 |
| **Multi-AZ** | ✅ Enabled | 고가용성 보장 |
| **Backup** | 14일 보존 | Point-in-Time Recovery |
| **Encryption** | KMS (rds-encryption) | 저장 데이터 암호화 |
| **MySQL Version** | 8.0.35 | 최신 8.0 LTS |
| **Connections** | 200 max | 동시 연결 제한 |
| **예상 비용** | $60-70/월 | Multi-AZ 포함 |

## 🔐 보안 설정

### KMS 암호화
- **Storage**: `alias/rds-encryption` (기존 KMS 키 사용)
- **Secrets Manager**: `alias/secrets-manager` (기존 KMS 키 사용)
- **Performance Insights**: `alias/rds-encryption`

### Secrets Manager
비밀번호 및 연결 정보는 Secrets Manager에 안전하게 저장됩니다:

```bash
# 마스터 비밀번호 조회
aws secretsmanager get-secret-value \
  --secret-id prod-shared-mysql-master-password \
  --query SecretString --output text | jq

# 연결 정보 조회
aws secretsmanager get-secret-value \
  --secret-id prod-shared-mysql-connection \
  --query SecretString --output text | jq
```

### 네트워크 보안
- **Security Group**: 특정 보안 그룹 또는 CIDR만 접근 허용
- **Private Subnets**: 퍼블릭 인터넷에서 직접 접근 불가
- **VPC Only**: VPC 내부 트래픽만 허용

### IAM 데이터베이스 인증

**비밀번호 대신 IAM 역할로 인증** (권장):

```hcl
resource "aws_db_instance" "main" {
  # IAM 인증 활성화
  iam_database_authentication_enabled = true
}
```

**IAM 정책 설정**:
```hcl
resource "aws_iam_policy" "rds_connect" {
  name = "rds-iam-auth-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "rds-db:connect"
      ]
      Resource = "arn:aws:rds-db:ap-northeast-2:ACCOUNT_ID:dbuser:*/app_user"
    }]
  })
}
```

**애플리케이션에서 사용**:
```bash
# 인증 토큰 생성 (15분 유효)
TOKEN=$(aws rds generate-db-auth-token \
  --hostname prod-shared-mysql.xxx.ap-northeast-2.rds.amazonaws.com \
  --port 3306 \
  --username app_user \
  --region ap-northeast-2)

# MySQL 연결
mysql -h prod-shared-mysql.xxx.ap-northeast-2.rds.amazonaws.com \
  -u app_user \
  --password="$TOKEN" \
  --enable-cleartext-plugin \
  --ssl-ca=/path/to/rds-ca-bundle.pem
```

**장점**:
- 비밀번호 관리 불필요
- 자동 토큰 만료 (15분)
- CloudTrail을 통한 접근 추적
- 세분화된 권한 관리

### 감사 로깅

**CloudWatch Logs 활성화**:
```hcl
resource "aws_db_instance" "main" {
  enabled_cloudwatch_logs_exports = [
    "error",
    "general",
    "slowquery",
    "audit"
  ]
}
```

**로그 스트림 확인**:
```bash
# Error Log
aws logs tail /aws/rds/instance/prod-shared-mysql/error \
  --follow \
  --region ap-northeast-2

# Slow Query Log
aws logs tail /aws/rds/instance/prod-shared-mysql/slowquery \
  --follow \
  --region ap-northeast-2

# Audit Log
aws logs tail /aws/rds/instance/prod-shared-mysql/audit \
  --follow \
  --region ap-northeast-2
```

**CloudWatch Logs Insights 쿼리**:
```sql
-- 느린 쿼리 분석
fields @timestamp, @message
| filter @message like /Query_time/
| sort @timestamp desc
| limit 100

-- 실패한 로그인 시도
fields @timestamp, @message
| filter @message like /Access denied/
| stats count() by bin(5m)

-- 권한 변경 (GRANT/REVOKE)
fields @timestamp, @message
| filter @message like /GRANT|REVOKE/
| sort @timestamp desc
```

**CloudWatch Alarms 설정**:
```hcl
resource "aws_cloudwatch_metric_alarm" "failed_login" {
  alarm_name          = "rds-failed-login-attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedLoginAttempts"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "RDS failed login attempts > 10 in 5 minutes"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}
```

### 보안 그룹 규칙 최소화

**최소 권한 원칙 적용**:

```hcl
# ❌ 잘못된 예: 모든 IP 허용
resource "aws_security_group_rule" "bad" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # 모든 IP 허용
  security_group_id = aws_security_group.rds.id
}

# ✅ 올바른 예: 특정 보안 그룹만 허용
resource "aws_security_group_rule" "good" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id  # 앱 SG만 허용
  security_group_id        = aws_security_group.rds.id
  description              = "Allow MySQL from application servers"
}
```

**보안 그룹 규칙 검증**:
```bash
# RDS 보안 그룹 규칙 확인
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=prod-shared-mysql-sg" \
  --region ap-northeast-2 \
  --query 'SecurityGroups[*].{Name:GroupName,InboundRules:IpPermissions}'

# 0.0.0.0/0 규칙 검색 (위험)
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=prod-shared-mysql-sg" \
  --region ap-northeast-2 \
  --query 'SecurityGroups[?IpPermissions[?contains(IpRanges[].CidrIp, `0.0.0.0/0`)]]'
```

### 스냅샷 암호화

**자동 백업 암호화**:
```hcl
resource "aws_db_instance" "main" {
  storage_encrypted   = true
  kms_key_id          = data.aws_ssm_parameter.rds-encryption-key-arn.value

  # 자동 백업 설정
  backup_retention_period = 30  # 30일 보관
  backup_window           = "03:00-04:00"  # UTC
  copy_tags_to_snapshot   = true
}
```

**수동 스냅샷 생성 및 검증**:
```bash
# 암호화된 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier prod-shared-mysql \
  --db-snapshot-identifier prod-mysql-snapshot-$(date +%Y%m%d-%H%M%S) \
  --region ap-northeast-2

# 스냅샷 암호화 확인
aws rds describe-db-snapshots \
  --db-instance-identifier prod-shared-mysql \
  --region ap-northeast-2 \
  --query 'DBSnapshots[*].{Snapshot:DBSnapshotIdentifier,Encrypted:Encrypted,KmsKeyId:KmsKeyId}'
```

**암호화되지 않은 스냅샷 복사 및 암호화**:
```bash
# 암호화되지 않은 스냅샷을 암호화하여 복사
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:ap-northeast-2:ACCOUNT_ID:snapshot:unencrypted-snapshot \
  --target-db-snapshot-identifier encrypted-snapshot \
  --kms-key-id arn:aws:kms:ap-northeast-2:ACCOUNT_ID:key/xxx \
  --region ap-northeast-2
```

### SSL/TLS 연결 강제

**RDS Parameter Group 설정**:
```hcl
resource "aws_db_parameter_group" "ssl_required" {
  family = "mysql8.0"
  name   = "mysql80-ssl-required"

  parameter {
    name  = "require_secure_transport"
    value = "1"  # SSL/TLS 필수
  }
}

resource "aws_db_instance" "main" {
  parameter_group_name = aws_db_parameter_group.ssl_required.name
}
```

**애플리케이션에서 SSL 연결**:
```bash
# RDS CA 인증서 다운로드
wget https://truststore.pki.rds.amazonaws.com/ap-northeast-2/ap-northeast-2-bundle.pem

# MySQL SSL 연결
mysql -h prod-shared-mysql.xxx.ap-northeast-2.rds.amazonaws.com \
  -u admin \
  -p \
  --ssl-ca=ap-northeast-2-bundle.pem \
  --ssl-mode=REQUIRED
```

**연결 상태 확인**:
```sql
-- SSL 연결 확인
SHOW STATUS LIKE 'Ssl_cipher';

-- 현재 연결 중인 세션의 SSL 상태
SELECT * FROM performance_schema.session_status
WHERE VARIABLE_NAME IN ('Ssl_cipher','Ssl_version');
```

### 보안 체크리스트

#### 배포 전 필수 확인
- [ ] **KMS 암호화**: Storage, Backups, Performance Insights 모두 암호화
- [ ] **Secrets Manager**: Master password 저장 완료
- [ ] **Private Subnet**: Public 접근 불가능한 서브넷에 배치
- [ ] **보안 그룹**: 특정 보안 그룹에서만 접근 허용 (0.0.0.0/0 금지)
- [ ] **SSL/TLS 강제**: `require_secure_transport = 1` 설정
- [ ] **Deletion Protection**: 프로덕션 환경에서 활성화
- [ ] **Multi-AZ**: 고가용성이 필요한 경우 활성화

#### 운영 중 주기적 점검
- [ ] **CloudTrail 로그**: 비정상적인 RDS API 호출 확인 (매주)
- [ ] **CloudWatch Logs**: 실패한 로그인 시도, 권한 변경 확인 (매주)
- [ ] **Slow Query Log**: 성능 저하 쿼리 분석 및 최적화 (매주)
- [ ] **보안 그룹 규칙**: 불필요한 규칙 제거 (매월)
- [ ] **IAM 권한**: 과도한 RDS 권한 검출 (매월)
- [ ] **Secrets Rotation**: Master password 주기적 교체 (분기별)
- [ ] **KMS 키 회전**: 자동 키 회전 활성화 상태 확인 (분기별)
- [ ] **백업 검증**: 스냅샷 복원 테스트 (분기별)

#### 데이터 보호
- [ ] **백업 보관**: 최소 30일 보관 (프로덕션)
- [ ] **스냅샷 암호화**: 모든 스냅샷 KMS 암호화 확인
- [ ] **자동 백업**: 백업 윈도우 설정 및 작동 확인
- [ ] **Final Snapshot**: 삭제 시 최종 스냅샷 생성 설정
- [ ] **크로스 리전 복제**: DR 필요 시 다른 리전에 스냅샷 복사

#### 액세스 제어
- [ ] **IAM 인증**: 비밀번호 대신 IAM 인증 사용 권장
- [ ] **최소 권한**: 애플리케이션별 개별 데이터베이스 사용자 생성
- [ ] **권한 분리**: DBA, 개발자, 애플리케이션 권한 분리
- [ ] **연결 수 제한**: `max_connections` 적절히 설정
- [ ] **Idle 연결 관리**: `wait_timeout`, `interactive_timeout` 설정

#### 보안 사고 대응
- [ ] **Runbook**: 보안 사고 대응 절차 문서화
- [ ] **격리 절차**: 침해 의심 시 보안 그룹 즉시 차단
- [ ] **Rollback**: 최근 스냅샷으로 즉시 복구 가능
- [ ] **연락처**: 보안팀 및 DBA 연락처 명시
- [ ] **조사**: CloudTrail, CloudWatch Logs 분석 절차 수립

## 🚀 배포 가이드

### 1. 사전 준비사항

**필수 요구사항**:
- ✅ VPC 및 Private Subnets (Multi-AZ)
- ✅ KMS 키 (`alias/rds-encryption`, `alias/secrets-manager`)
- ✅ Terraform >= 1.5.0
- ✅ AWS CLI 설정 완료

**확인 사항**:
```bash
# VPC 및 서브넷 확인
aws ec2 describe-vpcs --vpc-ids vpc-0f162b9e588276e09
aws ec2 describe-subnets --subnet-ids subnet-09692620519f86cf0 subnet-0d99080cbe134b6e9

# KMS 키 확인
aws kms describe-key --key-id alias/rds-encryption
aws kms describe-key --key-id alias/secrets-manager
```

### 2. 설정 파일 수정

`terraform.auto.tfvars` 파일에서 다음 항목을 환경에 맞게 수정:

```hcl
# 접근 허용할 보안 그룹 추가
allowed_security_group_ids = [
  "sg-xxxxxxxxxxxxx"  # ECS tasks security group
]

# SNS 알람 토픽 설정 (선택사항)
alarm_sns_topic_arn = "arn:aws:sns:ap-northeast-2:646886795421:rds-alarms"
```

### 3. Terraform 배포

```bash
cd terraform/rds

# 초기화
terraform init

# 코드 포맷팅
terraform fmt

# 검증
terraform validate

# 배포 계획 확인
terraform plan

# 배포 실행 (운영 환경이므로 신중하게!)
terraform apply
```

**배포 시간**: 약 15-20분 (Multi-AZ 구성 포함)

### 4. 배포 후 확인

```bash
# RDS 인스턴스 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier prod-shared-mysql \
  --query 'DBInstances[0].[DBInstanceStatus,MultiAZ,Endpoint.Address]'

# Secrets Manager 비밀번호 확인
aws secretsmanager get-secret-value \
  --secret-id prod-shared-mysql-master-password \
  --query SecretString --output text | jq -r '.password'
```

## 📖 사용 가이드

### 애플리케이션에서 연결하기

#### 1. Secrets Manager에서 연결 정보 가져오기 (권장)

```python
# Python 예제
import boto3
import json

def get_db_connection():
    client = boto3.client('secretsmanager', region_name='ap-northeast-2')
    secret = client.get_secret_value(SecretId='prod-shared-mysql-connection')
    db_config = json.loads(secret['SecretString'])

    return {
        'host': db_config['host'],
        'port': db_config['port'],
        'user': db_config['username'],
        'password': db_config['password'],
        'database': db_config['dbname']
    }
```

```javascript
// Node.js 예제
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager({ region: 'ap-northeast-2' });

async function getDbConnection() {
  const secret = await secretsManager.getSecretValue({
    SecretId: 'prod-shared-mysql-connection'
  }).promise();

  const dbConfig = JSON.parse(secret.SecretString);
  return {
    host: dbConfig.host,
    port: dbConfig.port,
    user: dbConfig.username,
    password: dbConfig.password,
    database: dbConfig.dbname
  };
}
```

#### 2. Terraform Output으로 연결 정보 참조

```hcl
# 다른 Terraform 모듈에서 참조
data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket = "ryuqqq-prod-tfstate"
    key    = "rds/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 사용
resource "aws_ecs_task_definition" "app" {
  # ...
  environment = [
    {
      name  = "DB_HOST"
      value = data.terraform_remote_state.rds.outputs.db_instance_address
    },
    {
      name  = "DB_PORT"
      value = tostring(data.terraform_remote_state.rds.outputs.db_instance_port)
    }
  ]

  secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = data.terraform_remote_state.rds.outputs.master_password_secret_arn
    }
  ]
}
```

### 데이터베이스 생성 및 권한 관리

```sql
-- 새로운 데이터베이스 생성
CREATE DATABASE service1_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 서비스별 사용자 생성
CREATE USER 'service1_user'@'%' IDENTIFIED BY 'strong_password_here';

-- 권한 부여
GRANT ALL PRIVILEGES ON service1_db.* TO 'service1_user'@'%';
FLUSH PRIVILEGES;

-- 읽기 전용 사용자 (분석용)
CREATE USER 'service1_readonly'@'%' IDENTIFIED BY 'readonly_password';
GRANT SELECT ON service1_db.* TO 'service1_readonly'@'%';
FLUSH PRIVILEGES;
```

## 📊 모니터링

### CloudWatch 알람

다음 메트릭에 대한 알람이 자동 설정됩니다:

| 알람 | 임계값 | 설명 |
|------|--------|------|
| **CPU Utilization** | 80% | CPU 사용률 |
| **Free Storage Space** | 5GB | 여유 스토리지 |
| **Freeable Memory** | 256MB | 여유 메모리 |
| **Database Connections** | 180 | 동시 연결 수 (max 200) |
| **Read Latency** | 100ms | 읽기 지연시간 |
| **Write Latency** | 100ms | 쓰기 지연시간 |

### Performance Insights

```bash
# Performance Insights 콘솔에서 확인
https://console.aws.amazon.com/rds/home?region=ap-northeast-2#performance-insights:

# 또는 AWS CLI
aws pi get-resource-metrics \
  --service-type RDS \
  --identifier db-XXXXXXXXXXXXX \
  --metric-queries '[{"Metric":"db.load.avg"}]' \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z
```

### CloudWatch Logs

로그는 자동으로 CloudWatch Logs로 전송됩니다:

- `/aws/rds/instance/prod-shared-mysql/error` - 에러 로그
- `/aws/rds/instance/prod-shared-mysql/general` - 일반 로그
- `/aws/rds/instance/prod-shared-mysql/slowquery` - 슬로우 쿼리 로그

```bash
# 슬로우 쿼리 확인
aws logs tail /aws/rds/instance/prod-shared-mysql/slowquery --follow
```

## 🔧 운영 가이드

### 백업 및 복구

#### 자동 백업
- **보존 기간**: 14일
- **백업 시간**: 매일 03:00-04:00 UTC (KST 12:00-13:00)
- **Point-in-Time Recovery**: 5분 단위로 복구 가능

#### 수동 스냅샷 생성
```bash
aws rds create-db-snapshot \
  --db-instance-identifier prod-shared-mysql \
  --db-snapshot-identifier prod-shared-mysql-manual-$(date +%Y%m%d-%H%M%S)
```

#### 복구 (Point-in-Time)
```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier prod-shared-mysql \
  --target-db-instance-identifier prod-shared-mysql-restored \
  --restore-time 2024-01-01T12:00:00Z
```

### 스케일링

#### Vertical Scaling (인스턴스 크기 변경)

```hcl
# terraform.auto.tfvars 수정
instance_class = "db.t4g.medium"  # 4 vCPU, 4GB RAM
```

```bash
terraform apply
```

**다운타임**: Multi-AZ 환경에서 약 1-2분

#### Storage Scaling

스토리지는 자동으로 확장되지만, 수동 조정도 가능합니다:

```hcl
# terraform.auto.tfvars 수정
allocated_storage     = 50   # 50GB로 증가
max_allocated_storage = 500  # 최대 500GB
```

### 유지보수

#### Maintenance Window
- **시간**: 월요일 04:00-05:00 UTC (KST 13:00-14:00)
- **자동 업데이트**: Minor version만 자동 업데이트

#### 수동 업데이트
```bash
# MySQL 마이너 버전 업데이트
aws rds modify-db-instance \
  --db-instance-identifier prod-shared-mysql \
  --engine-version 8.0.36 \
  --apply-immediately
```

### 보안 강화

#### 정기적인 비밀번호 교체
```bash
# 1. 새 비밀번호 생성 및 RDS 업데이트
NEW_PASSWORD=$(openssl rand -base64 32)
aws rds modify-db-instance \
  --db-instance-identifier prod-shared-mysql \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately

# 2. Secrets Manager 업데이트
aws secretsmanager update-secret \
  --secret-id prod-shared-mysql-master-password \
  --secret-string "{\"password\":\"$NEW_PASSWORD\"}"
```

## ⚠️ 주의사항

### 삭제 방지
- ✅ **Deletion Protection** 활성화됨
- ✅ **Final Snapshot** 자동 생성됨
- ⚠️ 삭제 시 반드시 비활성화 필요

### 비용 최적화
- 🔴 **Multi-AZ**: 약 $60-70/월 (고가용성 필요시만)
- 🟡 **Performance Insights**: 7일 무료, 그 이상 유료
- 🟢 **Storage**: gp3 사용으로 비용 절감

### 성능 고려사항
- **Connection Pooling**: 애플리케이션에서 필수
- **Max Connections**: 200 (인스턴스 크기에 따라 증가)
- **Slow Query**: 2초 이상 쿼리 자동 로깅

## 🔧 Troubleshooting

### 1. 데이터베이스 연결 실패

**증상**: 애플리케이션에서 RDS에 연결할 수 없음

**확인 방법**:
```bash
# RDS 인스턴스 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier prod-shared-mysql \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address,Endpoint.Port]'

# 보안 그룹 확인
aws ec2 describe-security-groups \
  --group-ids $(aws rds describe-db-instances \
    --db-instance-identifier prod-shared-mysql \
    --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text)
```

**해결 방법**:

1. **보안 그룹 규칙 확인**:
   - 애플리케이션 보안 그룹에서 RDS 보안 그룹으로 3306 포트 허용 확인
   ```bash
   # RDS 보안 그룹 인바운드 규칙 확인
   aws ec2 describe-security-groups \
     --group-ids <rds-security-group-id> \
     --query 'SecurityGroups[*].IpPermissions'
   ```

2. **네트워크 연결 테스트**:
   ```bash
   # 애플리케이션 서버에서 telnet으로 확인
   telnet <rds-endpoint> 3306

   # nc (netcat) 사용
   nc -zv <rds-endpoint> 3306
   ```

3. **Secrets Manager 연동 확인**:
   ```bash
   # 비밀번호가 올바른지 확인
   aws secretsmanager get-secret-value \
     --secret-id prod-shared-mysql-master-password \
     --query SecretString --output text | jq -r '.password'
   ```

4. **RDS 상태 확인**:
   - Status가 `available`인지 확인
   - Multi-AZ 페일오버 진행 중이 아닌지 확인

### 2. 느린 쿼리 성능 문제

**증상**: 쿼리 실행 시간이 길어지거나 타임아웃 발생

**확인 방법**:
```bash
# Slow Query 로그 확인
aws logs tail /aws/rds/instance/prod-shared-mysql/slowquery \
  --follow \
  --filter-pattern "Query_time" \
  --region ap-northeast-2

# Performance Insights에서 Top SQL 확인
# AWS Console > RDS > Performance Insights
```

**해결 방법**:

1. **인덱스 확인 및 생성**:
   ```sql
   -- 쿼리 실행 계획 확인
   EXPLAIN SELECT * FROM table_name WHERE column = 'value';

   -- 인덱스 생성
   CREATE INDEX idx_column_name ON table_name(column_name);

   -- 기존 인덱스 확인
   SHOW INDEX FROM table_name;
   ```

2. **쿼리 최적화**:
   - SELECT * 대신 필요한 컬럼만 조회
   - JOIN 조건 최적화
   - WHERE 절에 인덱스 활용

3. **Connection Pool 설정**:
   ```python
   # Python 예제 (SQLAlchemy)
   engine = create_engine(
       connection_string,
       pool_size=10,           # 기본 연결 수
       max_overflow=20,        # 최대 추가 연결
       pool_timeout=30,        # 연결 대기 시간
       pool_recycle=3600       # 1시간마다 연결 재생성
   )
   ```

4. **캐싱 전략**:
   - Redis/ElastiCache 도입 검토
   - 애플리케이션 레벨 캐싱

### 3. 디스크 용량 부족

**증상**: CloudWatch 알람 발생, 쓰기 작업 실패

**확인 방법**:
```bash
# 스토리지 사용량 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=prod-shared-mysql \
  --start-time $(date -u -v-1d +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average \
  --region ap-northeast-2
```

**해결 방법**:

1. **불필요한 데이터 정리**:
   ```sql
   -- 오래된 로그 데이터 삭제
   DELETE FROM logs WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);

   -- 테이블 최적화
   OPTIMIZE TABLE table_name;

   -- 바이너리 로그 정리 (주의!)
   PURGE BINARY LOGS BEFORE NOW() - INTERVAL 7 DAY;
   ```

2. **스토리지 확장** (자동 확장이 활성화되어 있음):
   - 현재 설정: 30GB → 최대 200GB 자동 확장
   - 필요시 `max_allocated_storage` 증가:
   ```hcl
   max_allocated_storage = 500  # 500GB로 증가
   ```

3. **아카이브 전략**:
   - 오래된 데이터를 S3로 이동
   - 파티셔닝 전략 도입

### 4. CPU 및 메모리 부족

**증상**: CPU 사용률 80% 이상, 응답 시간 증가

**확인 방법**:
```bash
# CPU 사용률 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=prod-shared-mysql \
  --start-time $(date -u -v-1h +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum \
  --region ap-northeast-2

# 메모리 사용률 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name FreeableMemory \
  --dimensions Name=DBInstanceIdentifier,Value=prod-shared-mysql \
  --start-time $(date -u -v-1h +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region ap-northeast-2
```

**해결 방법**:

1. **인스턴스 크기 증가** (Vertical Scaling):
   ```hcl
   # terraform.auto.tfvars 수정
   instance_class = "db.t4g.medium"  # 2GB → 4GB RAM
   # 또는
   instance_class = "db.r6g.large"   # 16GB RAM (메모리 최적화)
   ```

   ```bash
   terraform apply
   ```
   - Multi-AZ 환경에서 약 1-2분 다운타임 발생

2. **쿼리 최적화**:
   - Performance Insights에서 Top SQL 확인
   - 무거운 쿼리 최적화 또는 스케줄링

3. **Read Replica 도입** (읽기 부하 분산):
   ```hcl
   resource "aws_db_instance" "read_replica" {
     identifier             = "prod-shared-mysql-replica"
     replicate_source_db    = aws_db_instance.main.identifier
     instance_class         = "db.t4g.small"
     publicly_accessible    = false
   }
   ```

4. **MySQL 파라미터 튜닝**:
   ```sql
   -- 현재 파라미터 확인
   SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
   SHOW VARIABLES LIKE 'max_connections';
   ```

### 5. Multi-AZ 페일오버 문제

**증상**: 자동 페일오버 후 연결 불가 또는 일시적 다운타임

**확인 방법**:
```bash
# 최근 이벤트 확인
aws rds describe-events \
  --source-identifier prod-shared-mysql \
  --source-type db-instance \
  --start-time $(date -u -v-24H +%Y-%m-%dT%H:%M:%S) \
  --region ap-northeast-2

# Multi-AZ 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier prod-shared-mysql \
  --query 'DBInstances[0].[MultiAZ,SecondaryAvailabilityZone]'
```

**해결 방법**:

1. **애플리케이션 재연결 로직**:
   ```python
   # 연결 재시도 로직 구현
   import time
   from sqlalchemy import create_engine

   def get_connection(max_retries=3):
       for attempt in range(max_retries):
           try:
               engine = create_engine(connection_string)
               conn = engine.connect()
               return conn
           except Exception as e:
               if attempt < max_retries - 1:
                   time.sleep(5)  # 5초 대기 후 재시도
                   continue
               raise
   ```

2. **DNS 캐시 TTL 확인**:
   - RDS 엔드포인트의 TTL은 보통 30초
   - 애플리케이션에서 DNS 캐시를 오래 유지하지 않도록 설정

3. **페일오버 시간 확인**:
   - 정상적인 페일오버: 1-2분
   - 오래 걸리는 경우: 네트워크 또는 AZ 문제 확인

### 6. 백업 및 복구 문제

**증상**: 백업 실패, 복구 시점 찾을 수 없음

**확인 방법**:
```bash
# 자동 백업 스냅샷 확인
aws rds describe-db-snapshots \
  --db-instance-identifier prod-shared-mysql \
  --snapshot-type automated \
  --region ap-northeast-2

# 최신 복구 가능 시간 확인
aws rds describe-db-instances \
  --db-instance-identifier prod-shared-mysql \
  --query 'DBInstances[0].LatestRestorableTime'
```

**해결 방법**:

1. **백업 윈도우 충돌 확인**:
   - 백업 시간과 유지보수 시간이 겹치지 않는지 확인
   - 백업 시간: 03:00-04:00 UTC
   - 유지보수: 04:00-05:00 UTC

2. **수동 스냅샷 생성** (중요 작업 전):
   ```bash
   aws rds create-db-snapshot \
     --db-instance-identifier prod-shared-mysql \
     --db-snapshot-identifier prod-shared-mysql-before-migration-$(date +%Y%m%d)
   ```

3. **복구 테스트** (정기적으로):
   ```bash
   # 테스트용 복구
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier prod-shared-mysql-test \
     --db-snapshot-identifier <snapshot-id> \
     --db-instance-class db.t4g.micro
   ```

### 7. Too Many Connections 오류

**증상**: `ERROR 1040: Too many connections`

**확인 방법**:
```bash
# 현재 연결 수 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=prod-shared-mysql \
  --start-time $(date -u -v-1h +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum,Average \
  --region ap-northeast-2
```

```sql
-- MySQL에서 현재 프로세스 확인
SHOW PROCESSLIST;

-- 연결 수 확인
SHOW STATUS LIKE 'Threads_connected';
SHOW VARIABLES LIKE 'max_connections';
```

**해결 방법**:

1. **Connection Pool 크기 조정**:
   - 애플리케이션별 pool_size 감소
   - max_overflow 설정으로 피크 시간 대응

2. **유휴 연결 정리**:
   ```sql
   -- 유휴 연결 확인
   SELECT * FROM information_schema.processlist
   WHERE command = 'Sleep' AND time > 300;

   -- 특정 연결 종료 (주의!)
   KILL <process_id>;
   ```

3. **max_connections 증가** (인스턴스 크기에 따라 제한):
   ```hcl
   # DB Parameter Group 수정
   resource "aws_db_parameter_group" "custom" {
     parameter {
       name  = "max_connections"
       value = "500"  # 기본 200 → 500
     }
   }
   ```

4. **애플리케이션 재시작 주기 확인**:
   - 연결 누수(connection leak) 확인
   - Connection pool 라이브러리 버전 업데이트

### 8. Secrets Manager 연동 문제

**증상**: 애플리케이션에서 데이터베이스 비밀번호를 가져올 수 없음

**확인 방법**:
```bash
# Secret 존재 여부 확인
aws secretsmanager describe-secret \
  --secret-id prod-shared-mysql-connection \
  --region ap-northeast-2

# Secret 값 확인
aws secretsmanager get-secret-value \
  --secret-id prod-shared-mysql-connection \
  --query SecretString --output text | jq
```

**해결 방법**:

1. **IAM 권한 확인**:
   ```bash
   # ECS Task Role이 Secrets Manager 접근 권한이 있는지 확인
   aws iam get-role-policy \
     --role-name <ecs-task-role> \
     --policy-name secrets-manager-access
   ```

   필요한 권한:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "secretsmanager:GetSecretValue",
       "kms:Decrypt"
     ],
     "Resource": [
       "arn:aws:secretsmanager:ap-northeast-2:*:secret:prod-shared-mysql-*",
       "arn:aws:kms:ap-northeast-2:*:key/alias/secrets-manager"
     ]
   }
   ```

2. **VPC 엔드포인트 확인**:
   - Private 서브넷에서 Secrets Manager 접근 시 VPC 엔드포인트 필요
   ```bash
   # Secrets Manager VPC 엔드포인트 확인
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-2.secretsmanager" \
     --region ap-northeast-2
   ```

### 9. 하이브리드 인프라: Application VPC에서 Shared RDS 연결 실패

**증상**: Application 프로젝트(애플리케이션 레포지토리)에서 Infrastructure 프로젝트의 Shared RDS에 연결할 수 없음

**확인 방법**:
```bash
# SSM Parameter로 RDS Endpoint 확인
aws ssm get-parameter \
  --name /shared/rds/prod/endpoint \
  --region ap-northeast-2 \
  --query 'Parameter.Value' \
  --output text

# Application VPC → Infrastructure VPC 통신 확인 (Transit Gateway)
aws ec2 describe-transit-gateway-vpc-attachments \
  --filters "Name=vpc-id,Values=<application-vpc-id>" \
  --region ap-northeast-2 \
  --query 'TransitGatewayVpcAttachments[*].[State,TransitGatewayId]'

# RDS 보안 그룹 규칙 확인
aws ec2 describe-security-groups \
  --group-ids <rds-security-group-id> \
  --region ap-northeast-2 \
  --query 'SecurityGroups[*].IpPermissions[?FromPort==`3306`]'
```

**해결 방법**:

1. **SSM Parameter 데이터 소스 확인** (Application 프로젝트 `data.tf`):
   ```hcl
   # Infrastructure 프로젝트에서 생성한 RDS Endpoint 참조
   data "aws_ssm_parameter" "rds_endpoint" {
     name = "/shared/rds/${var.environment}/endpoint"
   }

   data "aws_ssm_parameter" "rds_port" {
     name = "/shared/rds/${var.environment}/port"
   }

   data "aws_ssm_parameter" "rds_database_name" {
     name = "/shared/rds/${var.environment}/database-name"
   }

   locals {
     rds_endpoint      = data.aws_ssm_parameter.rds_endpoint.value
     rds_port          = data.aws_ssm_parameter.rds_port.value
     rds_database_name = data.aws_ssm_parameter.rds_database_name.value
   }
   ```

2. **Transit Gateway 라우팅 설정** (Application 프로젝트):
   ```hcl
   # Transit Gateway ID 참조
   data "aws_ssm_parameter" "transit_gateway_id" {
     name = "/shared/network/transit-gateway-id"
   }

   # Private 서브넷 라우팅 테이블에 Infrastructure VPC CIDR 라우트 추가
   resource "aws_route" "to_infrastructure_vpc" {
     route_table_id         = aws_route_table.private.id
     destination_cidr_block = "10.0.0.0/16"  # Infrastructure VPC CIDR
     transit_gateway_id     = data.aws_ssm_parameter.transit_gateway_id.value
   }
   ```

3. **보안 그룹 규칙 설정** (Application 프로젝트):
   ```hcl
   # Application의 ECS 태스크에서 RDS로 접근
   resource "aws_security_group_rule" "app_to_rds" {
     type              = "egress"
     from_port         = 3306
     to_port           = 3306
     protocol          = "tcp"
     cidr_blocks       = ["10.0.0.0/16"]  # Infrastructure VPC CIDR
     security_group_id = aws_security_group.ecs_tasks.id
     description       = "Allow MySQL to Shared RDS in Infrastructure VPC"
   }
   ```

4. **RDS 보안 그룹 규칙 업데이트** (Infrastructure 프로젝트):
   ```hcl
   # Infrastructure 프로젝트의 RDS 보안 그룹에 Application VPC CIDR 허용
   resource "aws_security_group_rule" "rds_from_app_vpc" {
     type              = "ingress"
     from_port         = 3306
     to_port           = 3306
     protocol          = "tcp"
     cidr_blocks       = [
       "10.1.0.0/16",  # App VPC 1
       "10.2.0.0/16",  # App VPC 2
     ]
     security_group_id = aws_security_group.rds.id
     description       = "Allow MySQL from Application VPCs"
   }
   ```

5. **연결 테스트**:
   ```bash
   # Application ECS 컨테이너에서 테스트
   aws ecs execute-command \
     --cluster <app-cluster> \
     --task <task-id> \
     --container <container-name> \
     --interactive \
     --command "/bin/bash"

   # 컨테이너 내부에서
   nc -zv prod-shared-mysql.xxx.ap-northeast-2.rds.amazonaws.com 3306
   mysql -h prod-shared-mysql.xxx.ap-northeast-2.rds.amazonaws.com \
     -u app_user \
     -p \
     -D app_database
   ```

### 10. 하이브리드 인프라: RDS Proxy 연결 문제

**증상**: RDS Proxy를 통한 연결이 실패하거나 connection pooling이 작동하지 않음

**확인 방법**:
```bash
# RDS Proxy 상태 확인
aws rds describe-db-proxies \
  --db-proxy-name prod-shared-mysql-proxy \
  --region ap-northeast-2 \
  --query 'DBProxies[0].[Status,Endpoint,RequireTLS]'

# Proxy Target Group 확인
aws rds describe-db-proxy-target-groups \
  --db-proxy-name prod-shared-mysql-proxy \
  --region ap-northeast-2
```

**해결 방법**:

1. **RDS Proxy 생성** (Infrastructure 프로젝트):
   ```hcl
   resource "aws_db_proxy" "main" {
     name                   = "prod-shared-mysql-proxy"
     engine_family          = "MYSQL"
     auth {
       auth_scheme = "SECRETS"
       secret_arn  = aws_secretsmanager_secret.db_connection.arn
       iam_auth    = "DISABLED"  # 또는 REQUIRED
     }
     role_arn               = aws_iam_role.rds_proxy.arn
     vpc_subnet_ids         = local.private_subnet_ids
     require_tls            = true

     tags = merge(
       local.required_tags,
       {
         Name = "prod-shared-mysql-proxy"
       }
     )
   }

   resource "aws_db_proxy_default_target_group" "main" {
     db_proxy_name = aws_db_proxy.main.name

     connection_pool_config {
       max_connections_percent      = 100
       max_idle_connections_percent = 50
       connection_borrow_timeout    = 120
     }
   }

   resource "aws_db_proxy_target" "main" {
     db_proxy_name         = aws_db_proxy.main.name
     target_group_name     = aws_db_proxy_default_target_group.main.name
     db_instance_identifier = aws_db_instance.main.id
   }

   # SSM Parameter로 Proxy Endpoint Export
   resource "aws_ssm_parameter" "rds_proxy_endpoint" {
     name  = "/shared/rds/${var.environment}/proxy-endpoint"
     type  = "String"
     value = aws_db_proxy.main.endpoint

     tags = merge(
       local.required_tags,
       {
         Name = "rds-proxy-endpoint-export"
       }
     )
   }
   ```

2. **IAM 역할 설정** (RDS Proxy가 Secrets Manager 접근):
   ```hcl
   resource "aws_iam_role" "rds_proxy" {
     name = "rds-proxy-role"

     assume_role_policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Effect = "Allow"
         Principal = {
           Service = "rds.amazonaws.com"
         }
         Action = "sts:AssumeRole"
       }]
     })
   }

   resource "aws_iam_role_policy" "rds_proxy_secrets" {
     role = aws_iam_role.rds_proxy.id

     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [{
         Effect = "Allow"
         Action = [
           "secretsmanager:GetSecretValue",
           "kms:Decrypt"
         ]
         Resource = [
           aws_secretsmanager_secret.db_connection.arn,
           data.aws_ssm_parameter.secrets-manager-key-arn.value
         ]
       }]
     })
   }
   ```

3. **Application에서 RDS Proxy 사용**:
   ```hcl
   # Application 프로젝트에서 Proxy Endpoint 참조
   data "aws_ssm_parameter" "rds_proxy_endpoint" {
     name = "/shared/rds/${var.environment}/proxy-endpoint"
   }

   # ECS Task Definition에서 환경 변수로 설정
   resource "aws_ecs_task_definition" "app" {
     # ...
     container_definitions = jsonencode([{
       # ...
       environment = [
         {
           name  = "DB_HOST"
           value = data.aws_ssm_parameter.rds_proxy_endpoint.value
         },
         {
           name  = "DB_PORT"
           value = "3306"
         }
       ]
     }])
   }
   ```

4. **보안 그룹 규칙** (RDS Proxy):
   ```hcl
   # RDS Proxy Security Group
   resource "aws_security_group" "rds_proxy" {
     name        = "prod-shared-mysql-proxy-sg"
     description = "Security group for RDS Proxy"
     vpc_id      = local.vpc_id

     tags = merge(
       local.required_tags,
       {
         Name = "prod-shared-mysql-proxy-sg"
       }
     )
   }

   # Application VPC에서 Proxy로 접근 허용
   resource "aws_security_group_rule" "proxy_from_app_vpcs" {
     type              = "ingress"
     from_port         = 3306
     to_port           = 3306
     protocol          = "tcp"
     cidr_blocks       = [
       "10.1.0.0/16",  # App VPC 1
       "10.2.0.0/16",  # App VPC 2
     ]
     security_group_id = aws_security_group.rds_proxy.id
     description       = "Allow MySQL from Application VPCs via Proxy"
   }
   ```

### 11. 하이브리드 인프라: Secrets Manager 크로스 스택 접근 실패

**증상**: Application 프로젝트에서 Infrastructure 프로젝트의 Secrets Manager 비밀번호를 가져올 수 없음

**확인 방법**:
```bash
# Secrets Manager ARN 확인
aws ssm get-parameter \
  --name /shared/rds/prod/master-password-secret-arn \
  --region ap-northeast-2 \
  --query 'Parameter.Value' \
  --output text

# ECS Task Role 권한 확인
aws iam get-role-policy \
  --role-name <ecs-task-role> \
  --policy-name secrets-manager-access \
  --region ap-northeast-2
```

**해결 방법**:

1. **SSM Parameter로 Secrets ARN Export** (Infrastructure 프로젝트):
   ```hcl
   # Infrastructure 프로젝트에서 Secrets Manager ARN을 SSM Parameter로 Export
   resource "aws_ssm_parameter" "rds_master_password_secret_arn" {
     name  = "/shared/rds/${var.environment}/master-password-secret-arn"
     type  = "String"
     value = aws_secretsmanager_secret.master_password.arn

     tags = merge(
       local.required_tags,
       {
         Name = "rds-master-password-secret-arn-export"
       }
     )
   }

   resource "aws_ssm_parameter" "rds_connection_secret_arn" {
     name  = "/shared/rds/${var.environment}/connection-secret-arn"
     type  = "String"
     value = aws_secretsmanager_secret.db_connection.arn

     tags = merge(
       local.required_tags,
       {
         Name = "rds-connection-secret-arn-export"
       }
     )
   }
   ```

2. **Application 프로젝트에서 Secrets ARN 참조**:
   ```hcl
   # Application 프로젝트 data.tf
   data "aws_ssm_parameter" "rds_connection_secret_arn" {
     name = "/shared/rds/${var.environment}/connection-secret-arn"
   }

   locals {
     rds_connection_secret_arn = data.aws_ssm_parameter.rds_connection_secret_arn.value
   }
   ```

3. **IAM 권한 설정** (Application 프로젝트 ECS Task Role):
   ```hcl
   # ECS Task Role에 Secrets Manager 접근 권한 추가
   resource "aws_iam_role_policy" "ecs_task_secrets_manager" {
     role = aws_iam_role.ecs_task.id

     policy = jsonencode({
       Version = "2012-10-17"
       Statement = [
         {
           Effect = "Allow"
           Action = [
             "secretsmanager:GetSecretValue"
           ]
           Resource = [
             local.rds_connection_secret_arn
           ]
         },
         {
           Effect = "Allow"
           Action = [
             "kms:Decrypt"
           ]
           Resource = [
             data.aws_ssm_parameter.secrets-manager-key-arn.value
           ]
         }
       ]
     })
   }
   ```

4. **ECS Task Definition에서 Secrets 사용**:
   ```hcl
   resource "aws_ecs_task_definition" "app" {
     family                   = "app-service"
     network_mode             = "awsvpc"
     requires_compatibilities = ["FARGATE"]
     cpu                      = "256"
     memory                   = "512"
     task_role_arn            = aws_iam_role.ecs_task.arn
     execution_role_arn       = aws_iam_role.ecs_execution.arn

     container_definitions = jsonencode([{
       name  = "app"
       image = "app:latest"

       environment = [
         {
           name  = "DB_HOST"
           value = local.rds_endpoint
         },
         {
           name  = "DB_PORT"
           value = local.rds_port
         }
       ]

       secrets = [
         {
           name      = "DB_PASSWORD"
           valueFrom = "${local.rds_connection_secret_arn}:password::"
         },
         {
           name      = "DB_USERNAME"
           valueFrom = "${local.rds_connection_secret_arn}:username::"
         }
       ]
     }])
   }
   ```

5. **VPC Endpoint 확인** (Private 서브넷에서 Secrets Manager 접근):
   ```bash
   # Secrets Manager VPC Endpoint 존재 여부 확인
   aws ec2 describe-vpc-endpoints \
     --filters "Name=service-name,Values=com.amazonaws.ap-northeast-2.secretsmanager" \
     --region ap-northeast-2 \
     --query 'VpcEndpoints[*].[VpcEndpointId,State,VpcId]'
   ```

   VPC Endpoint가 없다면 Infrastructure 프로젝트에서 생성:
   ```hcl
   resource "aws_vpc_endpoint" "secrets_manager" {
     vpc_id            = local.vpc_id
     service_name      = "com.amazonaws.ap-northeast-2.secretsmanager"
     vpc_endpoint_type = "Interface"
     subnet_ids        = local.private_subnet_ids

     security_group_ids = [
       aws_security_group.vpc_endpoints.id
     ]

     private_dns_enabled = true

     tags = merge(
       local.required_tags,
       {
         Name = "secrets-manager-endpoint"
       }
     )
   }
   ```

### 12. 하이브리드 인프라: 데이터베이스 스키마 관리 및 마이그레이션

**증상**: Application별 데이터베이스 분리가 필요하거나, 스키마 마이그레이션 전략이 불명확함

**해결 방법**:

1. **데이터베이스 및 사용자 생성 스크립트** (Application 프로젝트):
   ```bash
   #!/bin/bash
   # scripts/create-database.sh

   # Secrets Manager에서 마스터 비밀번호 가져오기
   MASTER_PASSWORD=$(aws secretsmanager get-secret-value \
     --secret-id prod-shared-mysql-master-password \
     --region ap-northeast-2 \
     --query 'SecretString' --output text | jq -r '.password')

   # 애플리케이션 사용자 비밀번호 생성
   APP_PASSWORD=$(openssl rand -base64 32)

   # 데이터베이스 및 사용자 생성
   mysql -h prod-shared-mysql.xxx.ap-northeast-2.rds.amazonaws.com \
     -u admin \
     -p"$MASTER_PASSWORD" <<EOF
   CREATE DATABASE IF NOT EXISTS app_service_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER IF NOT EXISTS 'app_service_user'@'%' IDENTIFIED BY '$APP_PASSWORD';
   GRANT ALL PRIVILEGES ON app_service_db.* TO 'app_service_user'@'%';
   FLUSH PRIVILEGES;
   EOF

   # Secrets Manager에 애플리케이션 사용자 정보 저장
   aws secretsmanager create-secret \
     --name prod-app-service-db-credentials \
     --description "Database credentials for app-service" \
     --secret-string "{\"username\":\"app_service_user\",\"password\":\"$APP_PASSWORD\",\"database\":\"app_service_db\"}" \
     --kms-key-id alias/secrets-manager \
     --region ap-northeast-2
   ```

2. **Terraform으로 데이터베이스 관리** (mysql provider 사용):
   ```hcl
   # Application 프로젝트에서 mysql provider 사용
   terraform {
     required_providers {
       mysql = {
         source  = "petoju/mysql"
         version = "~> 3.0"
       }
     }
   }

   # Secrets Manager에서 마스터 비밀번호 가져오기
   data "aws_secretsmanager_secret_version" "master_password" {
     secret_id = local.rds_master_password_secret_arn
   }

   locals {
     master_password = jsondecode(data.aws_secretsmanager_secret_version.master_password.secret_string)["password"]
   }

   provider "mysql" {
     endpoint = "${local.rds_endpoint}:${local.rds_port}"
     username = "admin"
     password = local.master_password
   }

   # 애플리케이션 데이터베이스 생성
   resource "mysql_database" "app" {
     name = "app_service_db"
     default_character_set = "utf8mb4"
     default_collation     = "utf8mb4_unicode_ci"
   }

   # 애플리케이션 사용자 생성
   resource "random_password" "app_user" {
     length  = 32
     special = true
   }

   resource "mysql_user" "app" {
     user               = "app_service_user"
     host               = "%"
     plaintext_password = random_password.app_user.result
   }

   resource "mysql_grant" "app" {
     user       = mysql_user.app.user
     host       = mysql_user.app.host
     database   = mysql_database.app.name
     privileges = ["ALL"]
   }

   # 애플리케이션 사용자 정보를 Secrets Manager에 저장
   resource "aws_secretsmanager_secret" "app_db_credentials" {
     name        = "prod-app-service-db-credentials"
     description = "Database credentials for app-service"
     kms_key_id  = data.aws_ssm_parameter.secrets-manager-key-arn.value

     tags = merge(
       local.required_tags,
       {
         Name = "prod-app-service-db-credentials"
       }
     )
   }

   resource "aws_secretsmanager_secret_version" "app_db_credentials" {
     secret_id = aws_secretsmanager_secret.app_db_credentials.id
     secret_string = jsonencode({
       username = mysql_user.app.user
       password = random_password.app_user.result
       database = mysql_database.app.name
       host     = local.rds_endpoint
       port     = local.rds_port
     })
   }
   ```

3. **스키마 마이그레이션 전략** (Flyway 또는 Liquibase 사용):

   **Flyway 예제**:
   ```yaml
   # Application 프로젝트 flyway.conf
   flyway.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useSSL=true
   flyway.user=${DB_USERNAME}
   flyway.password=${DB_PASSWORD}
   flyway.locations=filesystem:./migrations
   flyway.schemas=app_service_db
   flyway.table=schema_version
   ```

   ```sql
   -- migrations/V1__initial_schema.sql
   CREATE TABLE users (
     id BIGINT AUTO_INCREMENT PRIMARY KEY,
     email VARCHAR(255) NOT NULL UNIQUE,
     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
     updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
     INDEX idx_email (email)
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
   ```

   ```bash
   # 마이그레이션 실행
   flyway migrate
   ```

4. **CI/CD에서 마이그레이션 자동화**:
   ```yaml
   # GitHub Actions 예제
   name: Database Migration

   on:
     push:
       branches: [main]
       paths:
         - 'migrations/**'

   jobs:
     migrate:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3

         - name: Configure AWS credentials
           uses: aws-actions/configure-aws-credentials@v2
           with:
             aws-region: ap-northeast-2

         - name: Get DB credentials from Secrets Manager
           id: db-creds
           run: |
             SECRET=$(aws secretsmanager get-secret-value \
               --secret-id prod-app-service-db-credentials \
               --query SecretString --output text)
             echo "::set-output name=host::$(echo $SECRET | jq -r '.host')"
             echo "::set-output name=port::$(echo $SECRET | jq -r '.port')"
             echo "::set-output name=username::$(echo $SECRET | jq -r '.username')"
             echo "::add-mask::$(echo $SECRET | jq -r '.password')"
             echo "::set-output name=password::$(echo $SECRET | jq -r '.password')"
             echo "::set-output name=database::$(echo $SECRET | jq -r '.database')"

         - name: Run Flyway migration
           run: |
             flyway migrate \
               -url="jdbc:mysql://${{ steps.db-creds.outputs.host }}:${{ steps.db-creds.outputs.port }}/${{ steps.db-creds.outputs.database }}" \
               -user="${{ steps.db-creds.outputs.username }}" \
               -password="${{ steps.db-creds.outputs.password }}"
   ```

5. **읽기 전용 사용자 생성** (분석팀, 모니터링):
   ```sql
   CREATE USER 'app_readonly'@'%' IDENTIFIED BY 'readonly_password';
   GRANT SELECT ON app_service_db.* TO 'app_readonly'@'%';
   FLUSH PRIVILEGES;
   ```

### 13. 일반적인 체크리스트

#### RDS 기본 설정
- [ ] RDS 인스턴스 상태 `available`
- [ ] Multi-AZ 활성화됨
- [ ] 보안 그룹 규칙 올바르게 설정 (3306 포트)
- [ ] Secrets Manager에 비밀번호 저장됨
- [ ] CloudWatch 알람 정상 작동
- [ ] 자동 백업 활성화 (14일 보존)
- [ ] Performance Insights 활성화
- [ ] 슬로우 쿼리 로그 CloudWatch 전송 확인
- [ ] KMS 암호화 활성화
- [ ] Deletion Protection 활성화

#### 하이브리드 인프라 (크로스 스택 연결)
- [ ] SSM Parameters가 생성됨:
  - [ ] `/shared/rds/{env}/endpoint`
  - [ ] `/shared/rds/{env}/port`
  - [ ] `/shared/rds/{env}/database-name`
  - [ ] `/shared/rds/{env}/master-password-secret-arn`
  - [ ] `/shared/rds/{env}/connection-secret-arn`
  - [ ] `/shared/rds/{env}/proxy-endpoint` (RDS Proxy 사용 시)
- [ ] Transit Gateway 라우팅 설정 완료
- [ ] Application VPC → Infrastructure VPC 라우트 추가
- [ ] RDS 보안 그룹에 Application VPC CIDR 허용 규칙 추가
- [ ] Application ECS Task Role에 Secrets Manager 접근 권한 부여
- [ ] Application ECS Task Role에 KMS 복호화 권한 부여
- [ ] VPC Endpoint (Secrets Manager) 생성 (Private 서브넷 사용 시)
- [ ] Application별 데이터베이스 사용자 생성
- [ ] 애플리케이션 사용자 자격증명 Secrets Manager에 저장

#### RDS Proxy (선택사항)
- [ ] RDS Proxy 생성 및 상태 `available`
- [ ] RDS Proxy IAM 역할에 Secrets Manager 접근 권한
- [ ] RDS Proxy 보안 그룹에 Application VPC CIDR 허용
- [ ] RDS Proxy Endpoint SSM Parameter로 Export
- [ ] Connection Pool 설정 (max_connections_percent, max_idle_connections_percent)

#### 스키마 마이그레이션
- [ ] 마이그레이션 도구 선택 (Flyway, Liquibase, etc.)
- [ ] 마이그레이션 스크립트 버전 관리 (Git)
- [ ] CI/CD에서 마이그레이션 자동화
- [ ] Rollback 전략 수립
- [ ] 마이그레이션 테스트 (Dev/Staging 환경)

## 📥 Variables

이 모듈은 다음과 같은 입력 변수를 사용합니다:

### 필수 변수
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `vpc_id` | RDS가 배포될 VPC ID | `string` | - | **Yes** |
| `private_subnet_ids` | RDS 서브넷 그룹용 Private 서브넷 ID 목록 (Multi-AZ를 위해 최소 2개) | `list(string)` | - | **Yes** |

### 기본 설정
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `aws_region` | AWS 리전 | `string` | `ap-northeast-2` | No |
| `environment` | 환경 이름 (prod, staging, dev) | `string` | `prod` | No |
| `identifier` | RDS 인스턴스 식별자 | `string` | `shared-mysql` | No |

### RDS 구성
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `mysql_version` | MySQL 엔진 버전 | `string` | `8.0.35` | No |
| `instance_class` | RDS 인스턴스 클래스 | `string` | `db.t4g.small` | No |
| `allocated_storage` | 초기 할당 스토리지 (GB) | `number` | `30` | No |
| `max_allocated_storage` | 자동 스케일링 최대 스토리지 (GB) | `number` | `200` | No |
| `storage_type` | 스토리지 타입 (gp3, gp2, io1) | `string` | `gp3` | No |

### 데이터베이스 구성
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `database_name` | 생성할 기본 데이터베이스 이름 | `string` | `shared_db` | No |
| `master_username` | 마스터 사용자 이름 | `string` | `admin` | No |

### 보안 설정
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `allowed_security_group_ids` | RDS 접근 허용할 보안 그룹 ID 목록 | `list(string)` | `[]` | No |
| `allowed_cidr_blocks` | RDS 접근 허용할 CIDR 블록 목록 | `list(string)` | `[]` | No |

### 고가용성 & 백업
| 변수 이름 | 설명 | 타입 | 기본값 | 필수 여부 |
|-----------|------|------|--------|-----------|
| `multi_az` | Multi-AZ 배포 활성화 | `bool` | `true` | No |
| `backup_retention_period` | 백업 보존 기간 (일) | `number` | `14` | No |
| `backup_window` | 백업 시간 (UTC) | `string` | `03:00-04:00` | No |
| `maintenance_window` | 유지보수 시간 (UTC) | `string` | `Mon:04:00-Mon:05:00` | No |

전체 변수 목록은 [variables.tf](./variables.tf) 파일을 참조하세요.

## 📤 Outputs

이 모듈은 다음과 같은 출력 값을 제공합니다:

### RDS 인스턴스 정보
| 출력 이름 | 설명 |
|-----------|------|
| `db_instance_id` | RDS 인스턴스 식별자 |
| `db_instance_arn` | RDS 인스턴스 ARN |
| `db_instance_endpoint` | 연결 엔드포인트 (호스트:포트) |
| `db_instance_address` | RDS 인스턴스 호스트명 |
| `db_instance_port` | RDS 포트 번호 |
| `db_instance_name` | 데이터베이스 이름 |
| `db_instance_resource_id` | RDS 리소스 ID |

### 보안 정보
| 출력 이름 | 설명 |
|-----------|------|
| `db_security_group_id` | RDS 보안 그룹 ID |
| `db_subnet_group_name` | DB 서브넷 그룹 이름 |
| `db_parameter_group_name` | DB 파라미터 그룹 이름 |

### Secrets Manager 정보
| 출력 이름 | 설명 |
|-----------|------|
| `master_password_secret_arn` | 마스터 자격증명 Secrets Manager ARN |
| `master_password_secret_name` | Secrets Manager 시크릿 이름 |

### KMS 정보
| 출력 이름 | 설명 |
|-----------|------|
| `kms_key_arn` | RDS 암호화에 사용된 KMS 키 ARN |
| `kms_key_id` | RDS 암호화 KMS 키 ID |

전체 출력 목록은 [outputs.tf](./outputs.tf) 파일을 참조하세요.

## 📚 참고 자료

- [AWS RDS MySQL 공식 문서](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html)
- [Multi-AZ 배포](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [Performance Insights](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.html)
- [RDS 보안 모범 사례](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.Security.html)

## 📝 변경 이력

- **2025-10-19**: 초기 운영용 공유 RDS 배포
  - Multi-AZ 활성화
  - db.t4g.small (2GB RAM)
  - 14일 백업 보존
  - Performance Insights 활성화

---

**Last Updated**: 2025-01-22
**Maintained By**: Platform Team
