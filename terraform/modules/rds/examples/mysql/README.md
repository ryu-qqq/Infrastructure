# MySQL RDS 인스턴스 예제

이 예제는 운영 환경에서 사용 가능한 MySQL RDS 인스턴스를 배포하는 방법을 보여줍니다. Multi-AZ 고가용성, 자동 백업, KMS 암호화, Performance Insights, CloudWatch 알람 등의 운영에 필요한 모든 기능을 포함합니다.

## 아키텍처

```
VPC (Private Subnets)
    |
    v
RDS MySQL (Multi-AZ)
    |
    +--- KMS Encryption
    +--- Automated Backups
    +--- Performance Insights
    +--- CloudWatch Logs
    +--- CloudWatch Alarms
    +--- Secrets Manager (Password)
```

## 주요 기능

- ✅ MySQL 8.0 엔진
- ✅ Multi-AZ 고가용성 배포
- ✅ KMS를 이용한 저장 데이터 암호화
- ✅ 자동 백업 (7일 보존)
- ✅ 스토리지 자동 확장
- ✅ Performance Insights (7일 보존)
- ✅ CloudWatch Logs (에러, 일반, 슬로우 쿼리)
- ✅ Enhanced Monitoring (60초 간격)
- ✅ CloudWatch 알람 (CPU, 스토리지, 연결 수)
- ✅ Secrets Manager 비밀번호 관리
- ✅ 커스텀 Parameter Group
- ✅ 삭제 방지 옵션

## 사전 요구사항

1. **VPC 및 서브넷**
   - VPC ID
   - Private 서브넷 (최소 2개, Multi-AZ)

2. **서브넷 태그**
   ```hcl
   tags = {
     Type = "private"
   }
   ```

3. **보안 그룹**
   - RDS에 접근할 애플리케이션의 보안 그룹 ID

> **참고**: 마스터 비밀번호는 `random_password` 리소스로 자동 생성되어 Terraform state 파일에 평문으로 저장되지 않습니다. 생성된 비밀번호는 AWS Secrets Manager에 안전하게 저장됩니다.

## 사용 방법

### 1. terraform.tfvars 파일 생성

```hcl
# terraform.tfvars
aws_region   = "ap-northeast-2"
environment  = "prod"
service_name = "myapp"
vpc_id       = "vpc-xxxxxxxxxxxxx"

# 보안 그룹 (애플리케이션 레이어)
allowed_security_group_ids = [
  "sg-xxxxxxxxxxxxx"  # ECS Tasks 보안 그룹
]

# MySQL 설정
mysql_version  = "8.0.35"
instance_class = "db.t3.small"

# 스토리지
allocated_storage     = 20   # 초기 20GB
max_allocated_storage = 100  # 최대 100GB까지 자동 확장

# 데이터베이스
database_name   = "myappdb"
master_username = "admin"
# 참고: master_password는 자동으로 생성되어 Secrets Manager에 저장됩니다

# 고가용성
enable_multi_az = true  # 운영 환경에서는 true 권장

# 백업
backup_retention_days      = 7      # 7일간 백업 보존
skip_final_snapshot        = false  # 삭제 시 최종 스냅샷 생성
enable_deletion_protection = true   # 실수로 삭제 방지

# 파라미터
max_connections = 100

# 알람 (선택사항)
alarm_sns_topic_arn = "arn:aws:sns:ap-northeast-2:123456789012:rds-alarms"
```

### 2. Terraform 초기화 및 배포

```bash
# Terraform 초기화
terraform init

# 실행 계획 확인
terraform plan

# 리소스 배포 (약 10-15분 소요)
terraform apply
```

### 3. 배포 확인

```bash
# 출력 확인
terraform output

# RDS 엔드포인트 확인
terraform output -raw db_instance_endpoint

# 연결 테스트 (애플리케이션 서버에서)
mysql -h $(terraform output -raw db_instance_address) \
      -P $(terraform output -raw db_instance_port) \
      -u $(terraform output -raw master_username) \
      -p
```

## 출력 값

| 출력 이름 | 설명 |
|----------|------|
| `db_instance_endpoint` | RDS 엔드포인트 (호스트:포트) |
| `db_instance_address` | RDS 호스트명 |
| `db_instance_port` | RDS 포트 (기본 3306) |
| `db_name` | 데이터베이스 이름 |
| `db_password_secret_arn` | Secrets Manager ARN |
| `connection_string_example` | 연결 문자열 예시 |

전체 출력 목록은 [outputs.tf](./outputs.tf)를 참조하세요.

## 리소스 목록

이 예제는 다음 AWS 리소스를 생성합니다:

- **데이터베이스**
  - RDS MySQL Instance (Multi-AZ)
  - DB Subnet Group
  - DB Parameter Group

- **보안**
  - Security Group
  - KMS Key (암호화)
  - Secrets Manager Secret (비밀번호)

- **모니터링**
  - CloudWatch Log Groups (에러, 일반, 슬로우 쿼리)
  - CloudWatch Alarms (CPU, 스토리지, 연결 수)
  - Enhanced Monitoring IAM Role

## 비용 예상

### 월 예상 비용 (서울 리전 기준)

- **RDS MySQL** (db.t3.small, Multi-AZ, 24/7)
  - 약 $60/월

- **스토리지** (20GB gp3, Multi-AZ)
  - 약 $5/월

- **백업 스토리지** (약 20GB, 7일 보존)
  - 약 $2/월

- **Performance Insights** (7일 보존)
  - 무료

- **Enhanced Monitoring**
  - 약 $1/월

**총 예상 비용: 약 $68/월**

> 실제 비용은 사용량에 따라 달라질 수 있습니다.

## 애플리케이션 통합

### 환경 변수 설정

```bash
# 애플리케이션 환경 변수
export DB_HOST="myapp-prod.xxxxx.ap-northeast-2.rds.amazonaws.com"
export DB_PORT="3306"
export DB_NAME="myappdb"
export DB_USERNAME="admin"

# 비밀번호는 Secrets Manager에서 가져오기
export DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id myapp-db-password-prod \
  --query SecretString \
  --output text)
```

### ECS Task Definition 예시

```json
{
  "containerDefinitions": [{
    "environment": [
      { "name": "DB_HOST", "value": "myapp-prod.xxxxx.ap-northeast-2.rds.amazonaws.com" },
      { "name": "DB_PORT", "value": "3306" },
      { "name": "DB_NAME", "value": "myappdb" },
      { "name": "DB_USERNAME", "value": "admin" }
    ],
    "secrets": [
      {
        "name": "DB_PASSWORD",
        "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:myapp-db-password-prod"
      }
    ]
  }]
}
```

### Node.js 연결 예시

```javascript
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USERNAME,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

module.exports = pool;
```

## Parameter Group 설정

이 예제는 다음 MySQL 파라미터를 설정합니다:

| 파라미터 | 값 | 설명 |
|---------|-----|------|
| `character_set_server` | `utf8mb4` | 서버 문자셋 (이모지 지원) |
| `collation_server` | `utf8mb4_unicode_ci` | 정렬 순서 |
| `max_connections` | `100` (설정 가능) | 최대 동시 연결 수 |
| `slow_query_log` | `1` | 슬로우 쿼리 로그 활성화 |
| `long_query_time` | `2` | 슬로우 쿼리 기준 (2초) |
| `log_queries_not_using_indexes` | `1` | 인덱스 미사용 쿼리 로깅 |

추가 파라미터가 필요하면 `main.tf`의 `aws_db_parameter_group` 리소스를 수정하세요.

## CloudWatch 알람

이 예제는 다음 알람을 자동으로 생성합니다:

### 1. CPU 사용률
- **임계값**: 80%
- **기간**: 5분 평균, 2회 연속
- **설명**: CPU 사용률이 지속적으로 높으면 인스턴스 클래스 업그레이드 검토

### 2. 스토리지 공간
- **임계값**: 5GB 미만
- **기간**: 5분 평균
- **설명**: 여유 공간이 부족하면 스토리지 확장 필요

### 3. 연결 수
- **임계값**: max_connections의 80%
- **기간**: 5분 평균, 2회 연속
- **설명**: 연결 수가 많으면 커넥션 풀 설정 또는 max_connections 증가 검토

## 모니터링

### CloudWatch Logs 확인

```bash
# 에러 로그
aws logs tail /aws/rds/instance/myapp-prod/error --follow

# 슬로우 쿼리 로그
aws logs tail /aws/rds/instance/myapp-prod/slowquery --follow

# 일반 로그
aws logs tail /aws/rds/instance/myapp-prod/general --follow
```

### Performance Insights 확인

1. AWS Console → RDS → [인스턴스 이름]
2. "Performance Insights" 탭 클릭
3. SQL 쿼리 성능 분석 및 대기 이벤트 확인

### 슬로우 쿼리 분석

```sql
-- RDS 콘솔에서 Performance Insights 또는 CloudWatch Logs에서 확인
-- 2초 이상 걸린 쿼리가 자동으로 로깅됨
```

## 백업 및 복구

### 자동 백업

- **백업 시간**: 매일 03:00-04:00 UTC (12:00-13:00 KST)
- **보존 기간**: 7일
- **백업 방식**: 스냅샷 (트랜잭션 일관성 보장)

### 수동 스냅샷 생성

```bash
aws rds create-db-snapshot \
  --db-instance-identifier myapp-prod \
  --db-snapshot-identifier myapp-manual-snapshot-$(date +%Y%m%d)
```

### 특정 시점 복구 (PITR)

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier myapp-prod \
  --target-db-instance-identifier myapp-prod-restored \
  --restore-time 2024-01-15T10:00:00Z
```

## 보안 고려사항

1. **네트워크 격리**
   - RDS는 Private 서브넷에만 배포
   - `publicly_accessible = false` 설정

2. **접근 제어**
   - 보안 그룹으로 애플리케이션 레이어에서만 접근 허용
   - 포트 3306은 특정 보안 그룹에서만 허용

3. **데이터 암호화**
   - KMS 키를 이용한 저장 데이터 암호화
   - 자동 백업 및 스냅샷도 암호화됨

4. **비밀번호 관리**
   - Secrets Manager에 마스터 비밀번호 저장
   - IAM 권한으로 접근 제어
   - 정기적인 비밀번호 로테이션 권장

5. **삭제 방지**
   - `deletion_protection = true` 설정
   - 최종 스냅샷 자동 생성

## 트러블슈팅

### 연결 불가

1. **보안 그룹 확인**
   ```bash
   aws ec2 describe-security-groups --group-ids sg-xxx
   ```

2. **서브넷 라우팅 확인**
   - Private 서브넷의 라우트 테이블 확인
   - NAT Gateway 또는 VPC 엔드포인트 확인

3. **RDS 상태 확인**
   ```bash
   aws rds describe-db-instances --db-instance-identifier myapp-prod
   ```

### 성능 문제

1. **Performance Insights 확인**
   - 가장 느린 쿼리 식별
   - 대기 이벤트 분석

2. **슬로우 쿼리 로그 분석**
   ```bash
   aws logs filter-log-events \
     --log-group-name /aws/rds/instance/myapp-prod/slowquery \
     --start-time $(date -u -d '1 hour ago' +%s)000
   ```

3. **인스턴스 메트릭 확인**
   - CPU, 메모리, IOPS 사용률
   - 필요시 인스턴스 클래스 업그레이드

### 스토리지 부족

1. **현재 사용량 확인**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier myapp-prod \
     --query 'DBInstances[0].AllocatedStorage'
   ```

2. **자동 확장 설정 확인**
   - `max_allocated_storage`가 적절히 설정되어 있는지 확인
   - 필요시 값 증가

## 유지보수

### 인스턴스 클래스 변경

```hcl
# variables.tf 또는 terraform.tfvars 수정
instance_class = "db.t3.medium"  # small에서 medium으로 업그레이드
```

```bash
terraform apply
```

> 인스턴스 클래스 변경 시 짧은 다운타임 발생 (Multi-AZ는 장애 조치 방식으로 최소화)

### MySQL 버전 업그레이드

```hcl
# variables.tf 또는 terraform.tfvars 수정
mysql_version = "8.0.36"  # 마이너 버전 업그레이드
```

```bash
terraform apply
```

> 메이저 버전 업그레이드 시에는 사전 테스트 필수

### 파라미터 변경

```hcl
# main.tf의 aws_db_parameter_group에 파라미터 추가
parameter {
  name  = "innodb_buffer_pool_size"
  value = "{DBInstanceClassMemory*3/4}"  # 메모리의 75%
}
```

> 일부 파라미터는 재부팅 필요

## 정리

리소스를 삭제하려면:

```bash
# 삭제 방지 해제 (필요시)
terraform apply -var="enable_deletion_protection=false"

# 리소스 삭제
terraform destroy
```

> 최종 스냅샷이 생성되므로 나중에 복구 가능

## 관련 문서

- [RDS 모듈 README](../../README.md)
- [AWS RDS MySQL 모범 사례](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [MySQL 8.0 공식 문서](https://dev.mysql.com/doc/refman/8.0/en/)
- [Performance Insights 사용 가이드](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.html)

## 라이선스

Internal use only - Infrastructure Team
