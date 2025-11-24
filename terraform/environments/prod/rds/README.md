# RDS Terraform Configuration

## 개요 (Overview)

공유 MySQL RDS 인스턴스를 AWS에 배포하기 위한 Terraform 구성입니다. Multi-AZ 고가용성, 자동 백업, Performance Insights, Enhanced Monitoring, CloudWatch 알람 등의 프로덕션 환경 필수 기능을 포함합니다.

## 구성 요소

### RDS Instance (main.tf)
- **모듈 기반**: `rds` 모듈 v1.0.0 사용
  - 엔진: MySQL 8.0.35
  - 인스턴스 클래스: db.t4g.small (기본값, 변경 가능)
  - 스토리지: gp3 30GB (최대 200GB 자동 확장)
  - KMS 암호화 활성화
- **네트워크**: Private 서브넷에 배포
- **고가용성**: Multi-AZ 활성화 (자동 장애 조치)
- **데이터베이스**: `shared_db` (UTF-8 utf8mb4)
- **파라미터 그룹**: 커스터마이징된 MySQL 8.0 설정

### Security Group (security-group.tf)
- **모듈 기반**: `security-group` 모듈 v1.0.0 사용
  - 타입: RDS 전용 보안 그룹
  - MySQL 포트 (3306) 인바운드 규칙
  - 허용된 Security Group 기반 접근 제어
  - 선택적 CIDR 기반 접근 제어
- **추가 규칙**:
  - Secrets Manager Rotation Lambda 접근 허용 (조건부)

### IAM 역할 (iam.tf)
- **Enhanced Monitoring Role**: `iam-role-policy` 모듈 v1.0.0 사용
  - RDS가 OS 레벨 메트릭을 CloudWatch에 게시
  - AWS 관리형 정책: `AmazonRDSEnhancedMonitoringRole`
  - 조건부 생성 (enable_enhanced_monitoring = true일 때)

### CloudWatch 알람 (cloudwatch.tf)
자동화된 모니터링 및 알림:

1. **CPU Utilization**: CPU 사용률 80% 초과 시 경고 (Warning)
2. **Free Storage Space**: 여유 스토리지 5GB 미만 시 크리티컬 (Critical)
3. **Freeable Memory**: 여유 메모리 256MB 미만 시 크리티컬 (Critical)
4. **Database Connections**: 연결 수 180개 초과 시 크리티컬 (Critical)
5. **Read Latency**: 읽기 지연 100ms 초과 시 경고 (Warning)
6. **Write Latency**: 쓰기 지연 100ms 초과 시 경고 (Warning)

**SNS 통합**: Monitoring 스택의 SNS 토픽 사용 (Critical, Warning, Info)

### Secrets Manager (secrets.tf)
- **마스터 비밀번호 관리**:
  - 32자 랜덤 비밀번호 자동 생성
  - Secrets Manager에 안전하게 저장
  - KMS 암호화
  - 자동 순환 지원 (30일 주기, 기본값)
  - 연결 정보 통합 시크릿 (host, port, username, password, dbname)

### 데이터베이스 설정
- **기본 데이터베이스**: `shared_db`
- **문자 인코딩**: UTF-8 (utf8mb4)
- **파라미터 그룹** 커스터마이징:
  - `character_set_server`: utf8mb4
  - `collation_server`: utf8mb4_unicode_ci
  - `max_connections`: 200
  - `innodb_buffer_pool_size`: 메모리의 75%
  - `slow_query_log`: 활성화 (2초 이상 쿼리 기록)
  - `log_queries_not_using_indexes`: 활성화

### 백업 및 유지 관리
- **백업**:
  - 자동 백업 활성화
  - 보존 기간: 14일
  - 백업 윈도우: 03:00-04:00 UTC (한국 시간 12:00-13:00)
  - 최종 스냅샷: 삭제 시 자동 생성
  - 태그 복사: 활성화
- **유지 관리**:
  - 윈도우: 월요일 04:00-05:00 UTC (한국 시간 월요일 13:00-14:00)
  - 마이너 버전 자동 업그레이드: 활성화

### 모니터링
- **CloudWatch Logs 내보내기**:
  - Error Log
  - General Log
  - Slow Query Log
- **Performance Insights**:
  - 활성화
  - 보존 기간: 7일 (무료)
- **Enhanced Monitoring**:
  - 활성화
  - 간격: 60초
  - IAM 역할 자동 생성

## 사용 방법

### 1. 사전 요구사항
- AWS CLI 구성 완료
- Terraform >= 1.5.0
- 적절한 AWS IAM 권한
- **필수 인프라**:
  - VPC 및 Private 서브넷 (최소 2개, 다른 AZ)
  - KMS 키 (RDS 암호화용)
  - Monitoring 스택 (SNS 토픽)
  - Secrets 스택 (선택 사항, 자동 순환 사용 시)

### 2. 초기화
```bash
cd terraform/environments/prod/rds
terraform init
```

### 3. 구성 검증
```bash
terraform validate
terraform fmt
```

### 4. 배포 계획 확인
```bash
terraform plan
```

### 5. 리소스 배포
```bash
terraform apply
```

## 변수 설정 (Variables)

### terraform.tfvars 생성

주요 변수는 `variables.tf`에 정의되어 있습니다. 실제 값은 `terraform.tfvars` 파일에 설정합니다:

```bash
# terraform.tfvars.example을 복사하여 시작
cp terraform.tfvars.example terraform.tfvars

# 실제 값으로 수정
vi terraform.tfvars
```

**⚠️ 주의**: `terraform.tfvars`는 민감한 정보를 포함하므로 `.gitignore`에 포함되어 있습니다.

### 필수 변수

| 변수 | 설명 | 예시 | 확인 방법 |
|------|------|------|----------|
| `vpc_id` | VPC ID | `vpc-0f162b9e588276e09` | `aws ec2 describe-vpcs` |
| `private_subnet_ids` | Private 서브넷 ID 목록 (최소 2개) | `["subnet-xxx", "subnet-yyy"]` | `aws ec2 describe-subnets --filters "Name=tag:Type,Values=private"` |

### 선택적 변수 (기본값 있음)

#### 일반 설정
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `environment` | 환경 이름 | `prod` |
| `aws_region` | AWS 리전 | `ap-northeast-2` |
| `service_name` | 서비스 이름 | `shared-database` |
| `team` | 담당 팀 | `platform-team` |
| `owner` | 리소스 소유자 | `fbtkdals2@naver.com` |
| `cost_center` | 비용 센터 | `engineering` |
| `project` | 프로젝트 이름 | `shared-infrastructure` |
| `data_class` | 데이터 분류 | `confidential` |

#### RDS 인스턴스 설정
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `identifier` | RDS 인스턴스 식별자 | `shared-mysql` |
| `mysql_version` | MySQL 버전 | `8.0.35` |
| `instance_class` | 인스턴스 클래스 | `db.t4g.small` |
| `allocated_storage` | 초기 스토리지 (GB) | `30` |
| `max_allocated_storage` | 최대 스토리지 (GB) | `200` |
| `storage_type` | 스토리지 타입 | `gp3` |
| `database_name` | 기본 데이터베이스 이름 | `shared_db` |
| `master_username` | 마스터 사용자 이름 | `admin` |
| `port` | 데이터베이스 포트 | `3306` |

#### 고가용성 및 백업
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `enable_multi_az` | Multi-AZ 활성화 | `true` |
| `backup_retention_period` | 백업 보존 기간 (일) | `14` |
| `backup_window` | 백업 윈도우 (UTC) | `03:00-04:00` |
| `maintenance_window` | 유지 관리 윈도우 (UTC) | `mon:04:00-mon:05:00` |
| `skip_final_snapshot` | 최종 스냅샷 생략 | `false` |
| `copy_tags_to_snapshot` | 스냅샷에 태그 복사 | `true` |

#### 모니터링
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `enable_performance_insights` | Performance Insights 활성화 | `true` |
| `performance_insights_retention_period` | 보존 기간 (일) | `7` |
| `enable_enhanced_monitoring` | Enhanced Monitoring 활성화 | `true` |
| `monitoring_interval` | 모니터링 간격 (초) | `60` |
| `enabled_cloudwatch_logs_exports` | CloudWatch 로그 유형 | `["error", "general", "slowquery"]` |

#### 보안
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `enable_deletion_protection` | 삭제 방지 | `true` |
| `publicly_accessible` | 퍼블릭 액세스 | `false` |
| `storage_encrypted` | 스토리지 암호화 | `true` |
| `allowed_security_group_ids` | 접근 허용 Security Group | `[]` |
| `allowed_cidr_blocks` | 접근 허용 CIDR | `[]` |

#### CloudWatch 알람
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `enable_cloudwatch_alarms` | CloudWatch 알람 활성화 | `true` |
| `cpu_utilization_threshold` | CPU 사용률 임계값 (%) | `80` |
| `free_storage_threshold` | 여유 스토리지 임계값 (bytes) | `5368709120` (5GB) |
| `freeable_memory_threshold` | 여유 메모리 임계값 (bytes) | `268435456` (256MB) |
| `database_connections_threshold` | 연결 수 임계값 | `180` |

#### Secrets 자동 순환
| 변수 | 설명 | 기본값 |
|------|------|--------|
| `enable_secrets_rotation` | 비밀번호 자동 순환 활성화 | `true` |
| `rotation_days` | 순환 주기 (일) | `30` |

### KMS 키 설정

RDS 암호화용 KMS 키:
```bash
# KMS 키 확인
aws kms list-aliases --region ap-northeast-2 \
  --query 'Aliases[?starts_with(AliasName, `alias/rds`)]'

# 키 존재 여부 확인
aws kms describe-key --key-id alias/rds-shared \
  --region ap-northeast-2
```

## 출력값 (Outputs)

배포 후 다음 값들이 출력됩니다:

### RDS 인스턴스
- **db_instance_id**: RDS 인스턴스 식별자
- **db_instance_arn**: RDS 인스턴스 ARN
- **db_instance_endpoint**: 연결 엔드포인트 (hostname:port)
- **db_instance_address**: 호스트명
- **db_instance_port**: 포트 번호
- **db_instance_name**: 데이터베이스 이름
- **db_instance_username**: 마스터 사용자 이름 (sensitive)

### 보안
- **security_group_id**: RDS Security Group ID
- **security_group_arn**: RDS Security Group ARN

### Secrets Manager
- **master_password_secret_arn**: 마스터 비밀번호 시크릿 ARN
- **master_password_secret_id**: 마스터 비밀번호 시크릿 ID

### IAM
- **monitoring_role_arn**: Enhanced Monitoring IAM 역할 ARN (조건부)
- **monitoring_role_name**: Enhanced Monitoring IAM 역할 이름 (조건부)

### 모니터링
- **performance_insights_enabled**: Performance Insights 활성화 여부
- **cloudwatch_log_groups**: CloudWatch Log Group 목록

## 주의사항

1. **AWS 자격 증명**: Terraform 실행 전 AWS 자격 증명이 올바르게 구성되어 있어야 합니다.
2. **Private 서브넷**: RDS는 반드시 Private 서브넷에 배포되어야 합니다 (publicly_accessible = false).
3. **Multi-AZ**: 프로덕션 환경에서는 반드시 Multi-AZ를 활성화해야 합니다.
4. **마스터 비밀번호**: Secrets Manager에 자동 저장되며, 순환 활성화 시 자동으로 교체됩니다.
5. **KMS 암호화**: 스토리지, Secrets, CloudWatch Logs 모두 KMS로 암호화됩니다.
6. **삭제 방지**: 기본적으로 삭제 방지가 활성화되어 있습니다 (`enable_deletion_protection = true`).
7. **비용**: Multi-AZ, Performance Insights, Enhanced Monitoring은 추가 비용이 발생합니다.

## 다음 단계

이 구성으로 생성된 리소스:
- ✅ RDS MySQL 인스턴스 (Multi-AZ)
- ✅ DB 서브넷 그룹
- ✅ DB 파라미터 그룹 (커스텀 설정)
- ✅ Security Group (RDS 타입)
- ✅ IAM 역할 (Enhanced Monitoring)
- ✅ Secrets Manager 시크릿 (마스터 비밀번호)
- ✅ CloudWatch 알람 (6개)
- ✅ CloudWatch Log Groups (자동 생성)

추가로 필요한 작업:
- [ ] 애플리케이션 Security Group에서 RDS Security Group으로 트래픽 허용
- [ ] 데이터베이스 스키마 및 테이블 생성
- [ ] 애플리케이션 사용자 및 권한 설정
- [ ] 백업 및 복원 테스트
- [ ] Failover 테스트 (Multi-AZ)

## 🔒 보안 고려사항

### 1. 네트워크 격리

**Private 서브넷 배치**:
```hcl
# RDS는 반드시 Private Subnet에 배치
publicly_accessible = false

# Private 서브넷 확인
aws ec2 describe-subnets \
  --subnet-ids subnet-xxx subnet-yyy \
  --region ap-northeast-2 \
  --query 'Subnets[*].{SubnetId:SubnetId,AZ:AvailabilityZone,Type:Tags[?Key==`Type`].Value|[0]}'
```

**NAT Gateway 확인**:
```bash
# Private 서브넷의 라우팅 테이블 확인
aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-xxx" \
  --region ap-northeast-2 \
  --query 'RouteTables[*].Routes'
```

### 2. 최소 권한 원칙

**Security Group 규칙 최소화**:
```hcl
# ✅ 권장: Security Group 참조
allowed_security_group_ids = [
  module.ecs_sg.security_group_id,
  module.lambda_sg.security_group_id
]

# ❌ 비권장: CIDR 블록 (넓은 범위)
allowed_cidr_blocks = ["0.0.0.0/0"]
```

**Security Group 규칙 확인**:
```bash
# RDS Security Group 규칙 확인
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*rds*" \
  --region ap-northeast-2 \
  --query 'SecurityGroups[*].{Name:GroupName,Ingress:IpPermissions}'
```

### 3. 암호화

**스토리지 암호화**:
```hcl
storage_encrypted = true
kms_key_id        = data.aws_kms_key.rds.arn
```

**전송 중 암호화 (SSL/TLS)**:
```sql
-- MySQL 연결 시 SSL/TLS 강제
GRANT ALL ON *.* TO 'app_user'@'%' REQUIRE SSL;
```

**Secrets Manager 암호화**:
```bash
# 마스터 비밀번호 확인
aws secretsmanager get-secret-value \
  --secret-id prod/rds/shared-mysql/master \
  --region ap-northeast-2 \
  --query SecretString --output text
```

### 4. 감사 및 로깅

**CloudWatch Logs Insights 쿼리**:
```sql
-- Slow Query 분석
fields @timestamp, @message
| filter @logStream like /slowquery/
| sort @timestamp desc
| limit 100

-- Error 로그 분석
fields @timestamp, @message
| filter @logStream like /error/
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50

-- 연결 실패 분석
fields @timestamp, @message
| filter @message like /Access denied/
| stats count() by bin(5m)
```

**Performance Insights 활용**:
```bash
# Performance Insights 데이터 조회
aws pi get-resource-metrics \
  --service-type RDS \
  --identifier db-ABCDEFGHIJKLMNOP \
  --metric-queries file://metric-queries.json \
  --start-time $(date -u -v-1H +%s) \
  --end-time $(date -u +%s) \
  --period-in-seconds 60 \
  --region ap-northeast-2
```

### 5. 백업 및 복원

**자동 백업 확인**:
```bash
# 최근 자동 백업 확인
aws rds describe-db-snapshots \
  --db-instance-identifier shared-mysql-prod \
  --snapshot-type automated \
  --region ap-northeast-2 \
  --query 'DBSnapshots[*].{SnapshotId:DBSnapshotIdentifier,CreateTime:SnapshotCreateTime,Status:Status}' \
  --output table
```

**수동 스냅샷 생성**:
```bash
# 중요 작업 전 수동 스냅샷 생성
aws rds create-db-snapshot \
  --db-instance-identifier shared-mysql-prod \
  --db-snapshot-identifier shared-mysql-prod-manual-$(date +%Y%m%d-%H%M%S) \
  --region ap-northeast-2
```

**특정 시점 복원 (Point-in-Time Recovery)**:
```bash
# 특정 시점으로 복원
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier shared-mysql-prod \
  --target-db-instance-identifier shared-mysql-prod-restored \
  --restore-time 2025-01-23T12:00:00Z \
  --region ap-northeast-2
```

### 6. 보안 체크리스트

#### 배포 전 필수 확인사항
- [ ] **Private Subnet**: RDS가 Public Subnet에 배치되지 않음
- [ ] **Public IP**: `publicly_accessible = false` 확인
- [ ] **KMS 암호화**: 스토리지 암호화 활성화 및 KMS 키 지정
- [ ] **Security Group**: 필요한 소스만 허용 (Security Group 참조 방식)
- [ ] **Multi-AZ**: 프로덕션 환경에서 활성화됨
- [ ] **삭제 방지**: `deletion_protection = true` 확인
- [ ] **백업 보존**: 적절한 백업 보존 기간 설정 (최소 7일)

#### 운영 중 주기적 점검
- [ ] **CloudWatch 알람**: 알람 상태 확인 (매일)
- [ ] **Slow Query 분석**: 성능 저하 쿼리 확인 (주간)
- [ ] **Security Group 규칙**: 불필요한 규칙 제거 (월간)
- [ ] **백업 검증**: 백업 복원 테스트 (분기별)
- [ ] **Secrets 순환**: 비밀번호 자동 순환 동작 확인 (월간)
- [ ] **Performance Insights**: 성능 병목 확인 (주간)
- [ ] **파라미터 그룹**: 최적화 파라미터 검토 (월간)

#### 보안 사고 대응 준비
- [ ] **Runbook**: RDS 장애 대응 절차 문서화
- [ ] **연락처**: DBA 및 담당자 연락처 명시
- [ ] **복원 절차**: 백업 복원 절차 수립 및 테스트
- [ ] **Failover 테스트**: Multi-AZ Failover 절차 테스트

## Troubleshooting

### 1. RDS 인스턴스가 생성되지 않는 경우

**증상**: RDS 인스턴스가 creating 상태에서 멈춤 또는 실패

**확인 방법**:
```bash
# RDS 이벤트 확인
aws rds describe-events \
  --source-identifier shared-mysql-prod \
  --source-type db-instance \
  --duration 60 \
  --region ap-northeast-2

# RDS 인스턴스 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier shared-mysql-prod \
  --region ap-northeast-2 \
  --query 'DBInstances[0].{Status:DBInstanceStatus,StatusInfos:StatusInfos}'
```

**일반적인 원인 및 해결 방법**:

1. **서브넷 구성 오류**:
   - 서브넷이 서로 다른 AZ에 있는지 확인
   - DB 서브넷 그룹 확인
   ```bash
   aws rds describe-db-subnet-groups \
     --region ap-northeast-2 \
     --query 'DBSubnetGroups[*].{Name:DBSubnetGroupName,Subnets:Subnets[*].[SubnetIdentifier,SubnetAvailabilityZone.Name]}'
   ```

2. **KMS 키 권한 문제**:
   - RDS가 KMS 키에 접근할 수 있는지 확인
   - KMS 키 정책에 RDS 서비스 권한 추가
   ```bash
   aws kms get-key-policy \
     --key-id alias/rds-shared \
     --policy-name default \
     --region ap-northeast-2
   ```

3. **파라미터 그룹 오류**:
   - 파라미터 값이 유효한지 확인
   - DB 엔진 버전과 파라미터 그룹 패밀리 일치 확인

### 2. 애플리케이션에서 RDS에 연결할 수 없는 경우

**증상**: 애플리케이션에서 DB 연결 실패

**확인 방법**:
```bash
# 엔드포인트 확인
terraform output db_instance_endpoint

# Security Group 확인
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id) \
  --region ap-northeast-2 \
  --query 'SecurityGroups[0].IpPermissions'
```

**해결 방법**:

1. **Security Group 규칙 확인**:
   - 애플리케이션 Security Group이 RDS Security Group에 허용되어 있는지 확인
   - 포트 3306이 열려 있는지 확인
   ```bash
   # 애플리케이션 SG를 RDS SG에 추가
   terraform apply -var='allowed_security_group_ids=["sg-app"]'
   ```

2. **엔드포인트 및 포트 확인**:
   - 올바른 엔드포인트 사용 확인
   - 포트 3306 확인

3. **네트워크 ACL 확인**:
   - VPC 네트워크 ACL이 트래픽을 차단하지 않는지 확인
   ```bash
   aws ec2 describe-network-acls \
     --filters "Name=association.subnet-id,Values=subnet-xxx" \
     --region ap-northeast-2
   ```

4. **라우팅 테이블 확인**:
   - Private 서브넷 라우팅 테이블 확인
   - NAT Gateway 정상 작동 확인

### 3. 성능 문제

**증상**: 쿼리가 느리거나 연결이 타임아웃됨

**확인 방법**:
```bash
# CloudWatch 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=shared-mysql-prod \
  --start-time $(date -u -v-1H +%s) \
  --end-time $(date -u +%s) \
  --period 300 \
  --statistics Average,Maximum \
  --region ap-northeast-2
```

**해결 방법**:

1. **Performance Insights 분석**:
   - AWS Console에서 Performance Insights 확인
   - 느린 쿼리 및 대기 이벤트 분석

2. **Slow Query Log 확인**:
   ```bash
   # CloudWatch Logs Insights에서 Slow Query 분석
   aws logs start-query \
     --log-group-name /aws/rds/instance/shared-mysql-prod/slowquery \
     --start-time $(date -u -v-1H +%s) \
     --end-time $(date -u +%s) \
     --query-string 'fields @timestamp, @message | sort @timestamp desc | limit 20' \
     --region ap-northeast-2
   ```

3. **연결 풀 최적화**:
   - 애플리케이션 연결 풀 설정 확인
   - `max_connections` 파라미터 조정 고려

4. **인스턴스 크기 조정**:
   ```hcl
   # 인스턴스 클래스 업그레이드
   instance_class = "db.t4g.medium"  # 또는 db.r5.large
   ```

### 4. 백업 문제

**증상**: 자동 백업이 생성되지 않음

**확인 방법**:
```bash
# 백업 설정 확인
aws rds describe-db-instances \
  --db-instance-identifier shared-mysql-prod \
  --region ap-northeast-2 \
  --query 'DBInstances[0].{BackupRetention:BackupRetentionPeriod,BackupWindow:PreferredBackupWindow}'
```

**해결 방법**:

1. **백업 보존 기간 확인**:
   - `backup_retention_period > 0` 확인
   - 최소 7일 권장

2. **백업 윈도우 충돌 확인**:
   - 백업 윈도우와 유지 관리 윈도우가 겹치지 않는지 확인
   - 백업 윈도우: 03:00-04:00 UTC
   - 유지 관리 윈도우: mon:04:00-mon:05:00 UTC

3. **스토리지 공간 확인**:
   - 스토리지가 충분한지 확인
   - 자동 확장 활성화 확인

### 5. Secrets Rotation 문제

**증상**: 비밀번호 자동 순환이 실패함

**확인 방법**:
```bash
# Secrets Manager 순환 상태 확인
aws secretsmanager describe-secret \
  --secret-id prod/rds/shared-mysql/master \
  --region ap-northeast-2 \
  --query '{RotationEnabled:RotationEnabled,LastRotated:LastRotatedDate,NextRotation:NextRotationDate}'

# Lambda 함수 로그 확인
aws logs tail /aws/lambda/SecretsManager-rotation-function \
  --follow \
  --region ap-northeast-2
```

**해결 방법**:

1. **Lambda Security Group 확인**:
   - Rotation Lambda가 RDS에 접근할 수 있는지 확인
   - RDS Security Group에 Lambda Security Group 허용 규칙 추가

2. **Lambda VPC 설정 확인**:
   - Lambda가 RDS와 같은 VPC에 있는지 확인
   - Lambda Subnet이 RDS에 접근 가능한지 확인

3. **IAM 권한 확인**:
   - Lambda 실행 역할에 필요한 권한이 있는지 확인

### 6. Multi-AZ Failover 문제

**증상**: Failover가 예상보다 오래 걸림

**확인 방법**:
```bash
# RDS 이벤트 확인
aws rds describe-events \
  --source-identifier shared-mysql-prod \
  --source-type db-instance \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --region ap-northeast-2
```

**해결 방법**:

1. **Failover 테스트**:
   ```bash
   # 강제 Failover (프로덕션 주의!)
   aws rds reboot-db-instance \
     --db-instance-identifier shared-mysql-prod \
     --force-failover \
     --region ap-northeast-2
   ```

2. **애플리케이션 재시도 로직**:
   - 연결 재시도 로직 구현
   - 연결 타임아웃 적절히 설정

### 7. 일반적인 체크리스트

배포 후 확인 사항:

- [ ] RDS 인스턴스 상태: `available`
- [ ] Multi-AZ 활성화됨
- [ ] Security Group 규칙 올바르게 설정됨
- [ ] 애플리케이션에서 연결 가능
- [ ] CloudWatch 알람 정상 작동
- [ ] CloudWatch Logs에 로그 기록됨
- [ ] Performance Insights 데이터 수집됨
- [ ] Enhanced Monitoring 메트릭 확인됨
- [ ] 자동 백업 생성됨
- [ ] Secrets Manager 비밀번호 저장됨
- [ ] Secrets 자동 순환 활성화됨 (enable_secrets_rotation = true인 경우)

## 비용 최적화

### 인스턴스 크기 조정
```hcl
# 개발/테스트 환경
instance_class = "db.t4g.micro"   # 최소 비용

# 프로덕션 환경 (소규모)
instance_class = "db.t4g.small"   # 기본값

# 프로덕션 환경 (중규모)
instance_class = "db.t4g.medium"

# 프로덕션 환경 (대규모)
instance_class = "db.r5.large"    # 메모리 최적화
```

### 스토리지 최적화
```hcl
# gp3 스토리지 사용 (gp2 대비 20% 저렴)
storage_type = "gp3"

# 자동 확장 활용 (초기 비용 절감)
allocated_storage     = 30   # 초기 작게 시작
max_allocated_storage = 200  # 필요 시 자동 확장
```

### 백업 최적화
```hcl
# 개발 환경: 백업 최소화
backup_retention_period = 7

# 프로덕션 환경: 규정 준수
backup_retention_period = 14  # 또는 30
```

### 모니터링 최적화
```hcl
# 개발 환경: 모니터링 비활성화
enable_performance_insights = false
enable_enhanced_monitoring  = false

# 프로덕션 환경: Performance Insights 보존 기간 최소화
performance_insights_retention_period = 7  # 무료 (731일은 유료)
```

### 비용 예상 (2025년 1월 기준, ap-northeast-2)

**기본 구성 (db.t4g.small, Multi-AZ)**:
- RDS 인스턴스: ~$50/월
- 스토리지 (gp3 30GB): ~$3/월
- 백업 스토리지 (14일): ~$2/월
- Performance Insights (7일 무료): $0/월
- Enhanced Monitoring: ~$2/월
- **총계**: ~$57/월

**참고**: 실제 비용은 사용량, 리전, AWS 요금 정책 변경에 따라 달라질 수 있습니다.

## 관련 문서

- [RDS Module v1.0.0](../../modules/rds/README.md)
- [Security Group Module v1.0.0](../../modules/security-group/README.md)
- [IAM Role Policy Module v1.0.0](../../modules/iam-role-policy/README.md)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [MySQL 8.0 Documentation](https://dev.mysql.com/doc/refman/8.0/en/)

---

**Last Updated**: 2025-01-23
**Maintained By**: Platform Team
