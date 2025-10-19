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
