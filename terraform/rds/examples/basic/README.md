# RDS Basic Example

MySQL RDS 인스턴스 배포 기본 예제입니다.

## 개요

이 예제에서는 다음 리소스를 생성합니다:

- **RDS Instance**: MySQL 8.0
- **Subnet Group**: Multi-AZ 배치
- **Parameter Group**: MySQL 최적화 설정
- **Security Group**: 데이터베이스 접근 제어
- **Secrets Manager**: DB 크레덴셜 관리

## 사용 방법

### terraform.tfvars

```hcl
environment         = "dev"
db_name             = "myapp"
db_master_username  = "admin"
instance_class      = "db.t3.micro"
allocated_storage   = 20
engine_version      = "8.0"

# Multi-AZ 설정
multi_az                = false  # dev: false, prod: true
backup_retention_period = 7
backup_window           = "03:00-04:00"
maintenance_window      = "mon:04:00-mon:05:00"

# 보안
storage_encrypted       = true
deletion_protection     = false  # dev: false, prod: true
skip_final_snapshot     = true   # dev: true, prod: false
```

### 배포

```bash
# 초기화
terraform init

# DB 비밀번호 설정 (Secrets Manager)
aws secretsmanager create-secret \
  --name rds/myapp/master-password \
  --secret-string "YourStrongPassword123!"

# 배포
terraform plan
terraform apply
```

## 데이터베이스 연결

배포 완료 후 엔드포인트 확인:

```bash
# RDS 엔드포인트
terraform output db_endpoint

# 포트
terraform output db_port

# Secrets Manager에서 비밀번호 가져오기
aws secretsmanager get-secret-value \
  --secret-id rds/myapp/master-password \
  --query SecretString --output text
```

### 연결 예시

```bash
mysql -h $(terraform output -raw db_endpoint | cut -d: -f1) \
      -P 3306 \
      -u admin \
      -p myapp
```

## 주요 설정

### 인스턴스 클래스 선택

**개발 환경:**
- `db.t3.micro`: 2 vCPU, 1 GB RAM (~$15/월)
- `db.t3.small`: 2 vCPU, 2 GB RAM (~$30/월)

**프로덕션 환경:**
- `db.r5.large`: 2 vCPU, 16 GB RAM (~$180/월)
- `db.r5.xlarge`: 4 vCPU, 32 GB RAM (~$360/월)

### Multi-AZ 고가용성

프로덕션 환경 필수 설정:

```hcl
multi_az               = true
backup_retention_period = 30  # 30일 백업 보관
deletion_protection    = true  # 실수 삭제 방지
skip_final_snapshot    = false # 삭제 시 최종 스냅샷
```

### 성능 최적화

```hcl
# IOPS 프로비저닝
storage_type = "io1"
iops         = 3000

# Performance Insights 활성화
enabled_cloudwatch_logs_exports = ["error", "slowquery"]
performance_insights_enabled    = true
```

## 비용 예상

서울 리전 기준 월 비용 (개발 환경):

| 항목 | 사양 | 비용 (USD) |
|------|------|------------|
| RDS Instance | db.t3.micro | ~$15 |
| Storage | 20 GB gp3 | ~$3 |
| 백업 Storage | 20 GB | ~$2 |
| KMS 암호화 | 1 key | ~$1 |
| **총 예상** | | **~$21** |

프로덕션 환경 (Multi-AZ):
- db.r5.large Multi-AZ: ~$360/월

## 보안 설정

### 1. 네트워크 격리

- Private 서브넷에만 배치
- 보안 그룹으로 특정 IP/SG만 접근 허용

### 2. 암호화

```hcl
storage_encrypted = true
kms_key_id        = data.terraform_remote_state.kms.outputs.rds_key_arn
```

### 3. 크레덴셜 관리

- Secrets Manager에 비밀번호 저장
- IAM 역할 기반 접근 제어
- 주기적인 비밀번호 교체

## 백업 및 복구

### 자동 백업

```hcl
backup_retention_period = 7  # 7일간 자동 백업 보관
backup_window           = "03:00-04:00"  # 새벽 3-4시 백업
```

### 수동 스냅샷

```bash
# 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier myapp-dev \
  --db-snapshot-identifier myapp-dev-$(date +%Y%m%d)

# 스냅샷에서 복구
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier myapp-restored \
  --db-snapshot-identifier myapp-dev-20250101
```

## Outputs

```bash
terraform output db_endpoint
terraform output db_port
terraform output db_name
terraform output security_group_id
```

## 모니터링

### CloudWatch Logs

활성화된 로그:
- Error Log
- Slow Query Log
- General Log (선택)

### CloudWatch Alarms

권장 알람:
- CPU Utilization > 80%
- FreeableMemory < 1GB
- DatabaseConnections > 80% of max
- ReadLatency/WriteLatency

## 정리

```bash
terraform destroy
```

**주의**: `deletion_protection = true`인 경우 먼저 변수를 false로 변경 후 destroy

## 참고 자료

- [RDS 패키지 문서](../../README.md)
- [AWS RDS MySQL 문서](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/)
