# Advanced RDS Example - Production Configuration

이 예제는 프로덕션 환경에 적합한 완전한 기능을 갖춘 RDS PostgreSQL 인스턴스를 배포하는 방법을 보여줍니다.

## 배포되는 리소스

- RDS PostgreSQL 인스턴스 (db.r5.large, 100GB 스토리지, Multi-AZ)
- KMS 키 및 별칭 (데이터 암호화용)
- DB 서브넷 그룹
- 보안 그룹
- IAM 역할 (Enhanced Monitoring용)
- DB 파라미터 그룹 (성능 최적화 설정 포함)

## 주요 기능

### 보안
- ✅ KMS 키를 사용한 저장 데이터 암호화
- ✅ 키 자동 교체 활성화
- ✅ 프라이빗 서브넷 배포
- ✅ 퍼블릭 액세스 비활성화
- ✅ 삭제 방지 활성화

### 고가용성
- ✅ Multi-AZ 배포 (자동 failover)
- ✅ 14일 자동 백업 보존
- ✅ 스냅샷에 태그 복사

### 성능 및 모니터링
- ✅ Performance Insights 활성화
- ✅ Enhanced Monitoring (60초 간격)
- ✅ CloudWatch Logs 내보내기 (PostgreSQL, Upgrade 로그)
- ✅ 성능 최적화된 파라미터 그룹
- ✅ gp3 스토리지 (250 MiB/s 처리량)
- ✅ 스토리지 자동 확장 (최대 500GB)

### 유지 관리
- ✅ 자동 마이너 버전 업그레이드
- ✅ 유지 관리 윈도우 설정 (일요일 04:00-05:00 UTC)
- ✅ 백업 윈도우 설정 (03:00-04:00 UTC)

## 사용 방법

1. **변수 설정**

`terraform.tfvars` 파일을 생성하고 다음 내용을 입력합니다:

```hcl
vpc_id              = "vpc-xxxxx"
environment         = "prod"
service_name        = "myapp"
instance_class      = "db.r5.large"
allocated_storage   = 100
max_allocated_storage = 500
multi_az            = true
deletion_protection = true
db_name             = "production"
master_username     = "pgadmin"
master_password     = "YourVerySecurePassword123!"  # AWS Secrets Manager 사용 권장
```

2. **초기화 및 배포**

```bash
terraform init
terraform plan
terraform apply
```

배포에는 약 15-20분이 소요됩니다 (Multi-AZ 설정 시).

3. **출력 확인**

```bash
terraform output db_endpoint
terraform output db_instance_resource_id  # Performance Insights용
terraform output kms_key_arn
```

## 파라미터 그룹 설정

다음 PostgreSQL 파라미터가 성능 최적화를 위해 설정됩니다:

| 파라미터 | 값 | 설명 |
|---------|-----|------|
| `max_connections` | 200 | 최대 동시 연결 수 |
| `shared_buffers` | DBInstanceClassMemory/32768 | 공유 버퍼 크기 |
| `effective_cache_size` | DBInstanceClassMemory/16384 | 효과적인 캐시 크기 |
| `maintenance_work_mem` | 2GB | 유지 관리 작업 메모리 |
| `checkpoint_completion_target` | 0.9 | 체크포인트 완료 목표 |
| `wal_buffers` | 16MB | WAL 버퍼 크기 |
| `default_statistics_target` | 100 | 통계 수집 목표 |
| `random_page_cost` | 1.1 | 랜덤 페이지 비용 (SSD 최적화) |
| `effective_io_concurrency` | 200 | I/O 동시성 |
| `work_mem` | 10MB | 작업 메모리 |

## Performance Insights 사용

Performance Insights를 통해 데이터베이스 성능을 모니터링할 수 있습니다:

```bash
# AWS CLI로 Performance Insights 데이터 조회
aws pi get-resource-metrics \
  --service-type RDS \
  --identifier $(terraform output -raw db_instance_resource_id) \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --period-in-seconds 60 \
  --metric-queries file://metrics.json
```

또는 AWS 콘솔 > RDS > Performance Insights에서 확인할 수 있습니다.

## Enhanced Monitoring

Enhanced Monitoring은 60초 간격으로 다음 메트릭을 수집합니다:

- OS 프로세스 목록
- CPU 사용률
- 메모리 사용률
- 파일 시스템 사용률
- 디스크 I/O
- 네트워크 트래픽

CloudWatch Logs에서 `/aws/rds/instance/{instance-id}/rds-monitoring` 로그 그룹을 확인하세요.

## 백업 및 복구

### 자동 백업
- 매일 03:00-04:00 UTC에 자동 백업 실행
- 14일간 보존
- Point-in-Time Recovery (PITR) 지원

### 수동 스냅샷
```bash
aws rds create-db-snapshot \
  --db-instance-identifier $(terraform output -raw db_instance_id) \
  --db-snapshot-identifier myapp-manual-snapshot-$(date +%Y%m%d)
```

### 복구
```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier $(terraform output -raw db_instance_id) \
  --target-db-instance-identifier myapp-postgres-restored \
  --restore-time $(date -u -d '1 hour ago' --iso-8601=seconds)
```

## 연결 방법

### psql 사용
```bash
psql -h $(terraform output -raw db_address) \
     -p $(terraform output -raw db_port) \
     -U pgadmin \
     -d production
```

### 애플리케이션 연결 문자열
```
postgresql://pgadmin:password@$(terraform output -raw db_address):5432/production?sslmode=require
```

## 예상 비용

db.r5.large (Multi-AZ, 100GB gp3):
- 인스턴스: ~$420/월
- 스토리지: ~$23/월 (100GB × 2 for Multi-AZ)
- 백업 스토리지: ~$20/월 (추가 백업 분)
- I/O 비용: 사용량에 따라 변동
- KMS: ~$1/월
- Enhanced Monitoring: ~$0.3/월

**총 예상 비용**: ~$460-500/월 (Seoul 리전 기준)

## 프로덕션 체크리스트

배포 전 확인사항:

- [ ] VPC와 서브넷이 올바르게 설정되었는가?
- [ ] 보안 그룹 규칙이 최소 권한 원칙을 따르는가?
- [ ] 마스터 비밀번호가 AWS Secrets Manager에 저장되었는가?
- [ ] Multi-AZ가 활성화되었는가?
- [ ] 백업 보존 기간이 요구사항을 충족하는가?
- [ ] 삭제 방지가 활성화되었는가?
- [ ] 모니터링 및 알림이 설정되었는가?
- [ ] 재해 복구 계획이 수립되었는가?

## 보안 권장사항

1. **Secrets Manager 사용**
```hcl
# AWS Secrets Manager에 비밀번호 저장
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "myapp/rds/master-password"
}

module "rds_postgres" {
  # ...
  master_password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

2. **SSL/TLS 연결 강제**
Parameter Group에 추가:
```hcl
{
  name  = "rds.force_ssl"
  value = "1"
}
```

3. **IAM 데이터베이스 인증**
```hcl
module "rds_postgres" {
  # ...
  iam_database_authentication_enabled = true
}
```

## 모니터링 및 알림

CloudWatch 알람 설정 예제:

```hcl
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.service_name}-rds-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"

  dimensions = {
    DBInstanceIdentifier = module.rds_postgres.db_instance_id
  }
}
```

## 정리

```bash
terraform destroy
```

**주의사항**:
1. 삭제 방지(`deletion_protection = true`)가 활성화되어 있으면 먼저 비활성화해야 합니다.
2. 최종 스냅샷이 생성되므로 AWS 콘솔에서 수동으로 삭제해야 합니다.
3. KMS 키는 10일의 대기 기간 후에 삭제됩니다.

## 문제 해결

### 연결 시간 초과
- 보안 그룹 인바운드 규칙 확인
- 네트워크 ACL 확인
- 라우팅 테이블 확인

### 성능 문제
- Performance Insights에서 대기 이벤트 확인
- CloudWatch 메트릭 검토 (CPU, IOPS, Connections)
- 파라미터 그룹 설정 검토

### 백업 실패
- 스토리지 공간 확인
- CloudWatch Logs에서 에러 메시지 확인
- 백업 윈도우와 유지 관리 윈도우가 겹치지 않는지 확인

## 추가 리소스

- [AWS RDS PostgreSQL 모범 사례](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [PostgreSQL 성능 튜닝](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [RDS Performance Insights 사용 가이드](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.html)
