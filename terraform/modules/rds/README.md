# RDS Terraform Module

AWS RDS 데이터베이스 인스턴스를 배포하고 관리하기 위한 재사용 가능한 Terraform 모듈입니다. MySQL, PostgreSQL, MariaDB, Oracle, SQL Server 등 다양한 데이터베이스 엔진을 지원하며, 백업, 암호화, 모니터링, 고가용성 설정을 포함합니다.

## Features

- ✅ 다양한 데이터베이스 엔진 지원 (MySQL, PostgreSQL, MariaDB, Oracle, SQL Server)
- ✅ 스토리지 자동 확장 (Auto Scaling)
- ✅ 자동 백업 및 스냅샷 관리
- ✅ KMS 키를 이용한 암호화 지원
- ✅ DB Parameter Group 커스터마이징
- ✅ Multi-AZ 고가용성 배포
- ✅ Performance Insights 통합
- ✅ CloudWatch Logs 내보내기
- ✅ Enhanced Monitoring 지원
- ✅ 표준화된 태그 자동 적용 (common-tags 모듈 통합)
- ✅ 포괄적인 변수 검증

## Usage

### Basic Example (MySQL)

```hcl
# 공통 태그 모듈 (모든 모듈에서 권장)
module "common_tags" {
  source = "../../modules/common-tags"

  environment = "prod"
  service     = "main-database"
  team        = "platform-team"
  owner       = "fbtkdals2@naver.com"
  cost_center = "engineering"
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "rds-mysql-prod"
  description = "Security group for RDS MySQL instance"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  tags = module.common_tags.tags
}

# RDS Module - Basic MySQL Configuration
module "rds_mysql" {
  source = "../../modules/rds"

  # Required variables
  identifier        = "myapp-mysql-prod"
  engine            = "mysql"
  engine_version    = "8.0.35"
  instance_class    = "db.t3.small"
  allocated_storage = 20

  # Database Configuration
  db_name         = "myappdb"
  master_username = "dbadmin"
  master_password = var.db_master_password # Use AWS Secrets Manager in production

  # Network Configuration
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.rds.id]

  # Tags
  common_tags = module.common_tags.tags
}
```

### Advanced Example with Encryption and Backups

```hcl
# KMS Key for RDS Encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10

  tags = module.common_tags.tags
}

resource "aws_kms_alias" "rds" {
  name          = "alias/rds-mysql-prod"
  target_key_id = aws_kms_key.rds.key_id
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = module.common_tags.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS Module - Production PostgreSQL with Full Features
module "rds_postgres" {
  source = "../../modules/rds"

  # Database Configuration
  identifier        = "myapp-postgres-prod"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.r5.large"
  allocated_storage = 100
  max_allocated_storage = 500 # Enable storage autoscaling

  # Storage Configuration
  storage_type = "gp3"
  storage_throughput = 250
  storage_encrypted = true
  kms_key_id = aws_kms_key.rds.arn

  # Database Credentials
  db_name         = "production"
  master_username = "pgadmin"
  master_password = var.db_master_password

  # Network Configuration
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.rds.id]
  publicly_accessible = false

  # High Availability
  multi_az = true

  # Backup Configuration
  backup_retention_period = 14
  backup_window          = "03:00-04:00"
  skip_final_snapshot    = false
  final_snapshot_identifier = "myapp-postgres-prod-final-snapshot"
  copy_tags_to_snapshot  = true

  # Maintenance Configuration
  auto_minor_version_upgrade = true
  maintenance_window        = "sun:04:00-sun:05:00"

  # Parameter Group with Custom Settings
  parameter_group_family = "postgres15"
  parameters = [
    {
      name  = "max_connections"
      value = "200"
    },
    {
      name  = "shared_buffers"
      value = "{DBInstanceClassMemory/32768}"
    }
  ]

  # Monitoring Configuration
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports      = ["postgresql", "upgrade"]
  monitoring_interval                  = 60
  monitoring_role_arn                  = aws_iam_role.rds_monitoring.arn

  # Deletion Protection
  deletion_protection = true

  # Tags
  common_tags = module.common_tags.tags
}
```

### Complete Example

전체 기능을 활용한 실제 운영 시나리오는 [examples/complete](./examples/complete/) 디렉터리를 참조하세요.

## Inputs

### Required Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `common_tags` | common-tags 모듈에서 생성된 표준 태그 | `map(string)` | - | yes |
| `engine` | 데이터베이스 엔진 (mysql, postgres, mariadb, oracle-*, sqlserver-*) | `string` | - | yes |
| `engine_version` | 엔진 버전 (예: MySQL '8.0.35', PostgreSQL '15.4') | `string` | - | yes |
| `identifier` | RDS 인스턴스 이름 (고유해야 하며 소문자, 숫자, 하이픈만 허용) | `string` | - | yes |
| `instance_class` | RDS 인스턴스 타입 (예: db.t3.micro, db.r5.large) | `string` | - | yes |
| `master_username` | 마스터 DB 사용자 이름 (예약어 제외) | `string` | - | yes |
| `master_password` | 마스터 DB 비밀번호 (최소 8자) | `string` (sensitive) | - | yes |
| `security_group_ids` | DB 인스턴스에 연결할 VPC 보안 그룹 ID 목록 | `list(string)` | - | yes |
| `subnet_ids` | DB 서브넷 그룹용 서브넷 ID 목록 (최소 2개, 다른 AZ) | `list(string)` | - | yes |

### Optional Variables - Storage Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `allocated_storage` | 할당된 스토리지 (GiB, 20-65536) | `number` | `20` | no |
| `max_allocated_storage` | 스토리지 자동 확장 상한 (0이면 비활성화) | `number` | `100` | no |
| `storage_type` | 스토리지 타입 (gp2, gp3, io1, io2, standard) | `string` | `"gp3"` | no |
| `iops` | 프로비저닝된 IOPS (io1/io2 필수) | `number` | `null` | no |
| `storage_throughput` | gp3 스토리지 처리량 (125-1000 MiB/s) | `number` | `null` | no |

### Optional Variables - Backup Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `backup_retention_period` | 백업 보존 기간 (일, 0-35, 0이면 비활성화) | `number` | `7` | no |
| `backup_window` | 자동 백업 시간대 (UTC, HH:MM-HH:MM) | `string` | `"03:00-04:00"` | no |
| `skip_final_snapshot` | 삭제 시 최종 스냅샷 생략 여부 | `bool` | `false` | no |
| `final_snapshot_identifier` | 최종 스냅샷 이름 (skip_final_snapshot이 false면 필수) | `string` | `null` | no |
| `copy_tags_to_snapshot` | 스냅샷에 인스턴스 태그 복사 | `bool` | `true` | no |

### Optional Variables - Encryption Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `storage_encrypted` | DB 인스턴스 암호화 여부 | `bool` | `true` | no |
| `kms_key_id` | KMS 암호화 키 ARN (미지정시 기본 RDS KMS 키 사용) | `string` | `null` | no |

### Optional Variables - Maintenance and Updates

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `auto_minor_version_upgrade` | 마이너 엔진 업그레이드 자동 적용 여부 | `bool` | `true` | no |
| `maintenance_window` | 유지 관리 윈도우 (UTC, ddd:HH:MM-ddd:HH:MM) | `string` | `"sun:04:00-sun:05:00"` | no |
| `apply_immediately` | 변경 사항 즉시 적용 여부 (false면 유지 관리 윈도우에 적용) | `bool` | `false` | no |

### Optional Variables - High Availability

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `multi_az` | Multi-AZ 고가용성 배포 여부 | `bool` | `false` | no |

### Optional Variables - Performance and Monitoring

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `performance_insights_enabled` | Performance Insights 활성화 | `bool` | `false` | no |
| `performance_insights_retention_period` | Performance Insights 데이터 보존 기간 (7 또는 731일) | `number` | `7` | no |
| `enabled_cloudwatch_logs_exports` | CloudWatch Logs로 내보낼 로그 유형 목록 | `list(string)` | `[]` | no |
| `monitoring_interval` | Enhanced Monitoring 간격 (초, 0/1/5/10/15/30/60) | `number` | `0` | no |
| `monitoring_role_arn` | Enhanced Monitoring용 IAM 역할 ARN (monitoring_interval > 0이면 필수) | `string` | `null` | no |

### Optional Variables - Parameter Group

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `parameter_group_family` | DB 파라미터 그룹 패밀리 (예: 'mysql8.0', 'postgres15') | `string` | `null` | no |
| `parameters` | 적용할 DB 파라미터 목록 (parameter_group_family 지정시 사용) | `list(object)` | `[]` | no |

### Optional Variables - Network Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `publicly_accessible` | 퍼블릭 액세스 허용 여부 | `bool` | `false` | no |
| `port` | DB 연결 포트 (미지정시 엔진 기본 포트 사용) | `number` | `null` | no |
| `db_name` | 생성할 데이터베이스 이름 (미지정시 생성 안 함) | `string` | `null` | no |

### Optional Variables - Deletion Protection

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `deletion_protection` | 삭제 방지 기능 활성화 | `bool` | `false` | no |

## Outputs

### Primary Identifiers

| Name | Description |
|------|-------------|
| `db_instance_id` | RDS 인스턴스 식별자 |
| `db_instance_arn` | RDS 인스턴스 ARN |
| `db_instance_endpoint` | RDS 연결 엔드포인트 (address:port) |
| `db_instance_address` | RDS 호스트명 |
| `db_instance_port` | DB 연결 포트 |

### Database Configuration

| Name | Description |
|------|-------------|
| `db_instance_engine` | 데이터베이스 엔진 |
| `db_instance_engine_version` | 실행 중인 엔진 버전 |
| `db_instance_name` | 데이터베이스 이름 |
| `db_instance_username` | 마스터 사용자 이름 (sensitive) |

### Resource Configuration

| Name | Description |
|------|-------------|
| `db_instance_class` | RDS 인스턴스 클래스 |
| `db_instance_allocated_storage` | 할당된 스토리지 크기 (GB) |
| `db_instance_storage_type` | 스토리지 타입 |

### Network Configuration

| Name | Description |
|------|-------------|
| `db_subnet_group_id` | DB 서브넷 그룹 이름 |
| `db_subnet_group_arn` | DB 서브넷 그룹 ARN |
| `db_instance_availability_zone` | 인스턴스 가용 영역 |
| `db_instance_multi_az` | Multi-AZ 여부 |

### Additional Outputs

| Name | Description |
|------|-------------|
| `db_parameter_group_id` | DB 파라미터 그룹 ID (생성된 경우) |
| `db_parameter_group_arn` | DB 파라미터 그룹 ARN (생성된 경우) |
| `db_instance_resource_id` | RDS 리소스 ID (Performance Insights용) |
| `db_instance_status` | RDS 인스턴스 상태 |
| `performance_insights_enabled` | Performance Insights 활성화 여부 |
| `db_instance_storage_encrypted` | DB 암호화 여부 |
| `db_instance_kms_key_id` | 암호화 KMS 키 ID |
| `db_instance_backup_retention_period` | 백업 보존 기간 |
| `db_instance_backup_window` | 백업 윈도우 |
| `db_instance_maintenance_window` | 유지 관리 윈도우 |

## Resource Types

이 모듈은 다음 AWS 리소스를 생성합니다:

- `aws_db_instance.this` - RDS DB 인스턴스
- `aws_db_subnet_group.this` - DB 서브넷 그룹
- `aws_db_parameter_group.this` - DB 파라미터 그룹 (parameter_group_family 지정시)

## Validation Rules

모듈은 다음 항목을 자동으로 검증합니다:

- ✅ 데이터베이스 이름 규칙 (문자로 시작, 영숫자만)
- ✅ 엔진 유형 (지원되는 엔진 목록)
- ✅ 식별자 네이밍 규칙 (소문자, 숫자, 하이픈만)
- ✅ 인스턴스 클래스 형식 (db.*.* 패턴)
- ✅ 마스터 사용자 이름 규칙 및 예약어 검증
- ✅ 마스터 비밀번호 최소 길이 (8자)
- ✅ 서브넷 수 (최소 2개, 고가용성)
- ✅ 스토리지 크기 범위
- ✅ 백업 보존 기간 범위
- ✅ 시간 형식 (백업/유지 관리 윈도우)
- ✅ 스토리지 타입별 필수 파라미터 (IOPS, 처리량)
- ✅ Performance Insights 지원 엔진
- ✅ Enhanced Monitoring 설정 검증

유효하지 않은 입력은 `terraform plan` 단계에서 명확한 에러 메시지와 함께 실패합니다.

## Tags Applied

모든 리소스는 자동으로 다음 태그를 받습니다:

**common-tags 모듈로부터:**
- `Environment` - 환경 (dev, staging, prod)
- `Service` - 서비스 이름
- `Team` - 담당 팀
- `Owner` - 소유자 이메일
- `CostCenter` - 비용 센터
- `ManagedBy` - "Terraform"
- `Project` - 프로젝트 이름

**모듈별 태그:**
- `Name` - 리소스 이름
- `Description` - 리소스 설명

## Examples Directory

추가 사용 예제는 [examples/](./examples/) 디렉터리를 참조하세요:

- [basic/](./examples/basic/) - 최소 설정 예제
- [advanced/](./examples/advanced/) - 고급 기능 활용 예제 (암호화, 백업, 모니터링)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |

## Supported Database Engines

### MySQL
- **Versions**: 5.7, 8.0
- **Default Port**: 3306
- **Parameter Group Family**: `mysql5.7`, `mysql8.0`
- **CloudWatch Logs**: `error`, `general`, `slowquery`

### PostgreSQL
- **Versions**: 12, 13, 14, 15
- **Default Port**: 5432
- **Parameter Group Family**: `postgres12`, `postgres13`, `postgres14`, `postgres15`
- **CloudWatch Logs**: `postgresql`, `upgrade`

### MariaDB
- **Versions**: 10.5, 10.6, 10.11
- **Default Port**: 3306
- **Parameter Group Family**: `mariadb10.5`, `mariadb10.6`, `mariadb10.11`
- **CloudWatch Logs**: `error`, `general`, `slowquery`

### Oracle
- **Editions**: SE2, SE, EE
- **Default Port**: 1521
- **Parameter Group Family**: Engine-specific

### SQL Server
- **Editions**: Express, Web, Standard, Enterprise
- **Default Port**: 1433
- **Parameter Group Family**: Engine-specific

## Related Documentation

- [모듈 디렉터리 구조](../../../docs/MODULES_DIRECTORY_STRUCTURE.md)
- [태그 표준](../../../docs/TAGGING_STANDARDS.md)
- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

## Changelog

변경 이력은 [CHANGELOG.md](./CHANGELOG.md)를 참조하세요.

## Epic & Tasks


## License

Internal use only - Infrastructure Team

---

## Advanced Configuration

### High Availability with Multi-AZ

프로덕션 환경에서 권장되는 Multi-AZ 설정:

```hcl
module "rds" {
  source = "../../modules/rds"
  # ...

  multi_az = true
  backup_retention_period = 14
  deletion_protection = true
}
```

### Storage Autoscaling

스토리지 자동 확장 활성화:

```hcl
module "rds" {
  source = "../../modules/rds"
  # ...

  allocated_storage     = 100
  max_allocated_storage = 1000  # 최대 1TB까지 자동 확장
}
```

### Read Replica Setup

읽기 복제본 생성 (별도 모듈 인스턴스 사용):

```hcl
# Primary Instance
module "rds_primary" {
  source = "../../modules/rds"
  identifier = "myapp-primary"
  # ... other settings
}

# Read Replica
module "rds_replica" {
  source = "../../modules/rds"
  identifier = "myapp-replica"
  replicate_source_db = module.rds_primary.db_instance_id
  # ... other settings (must match primary)
}
```

## Troubleshooting

### 인스턴스가 생성되지 않음

**증상**: RDS 인스턴스가 creating 상태에서 멈춤

**해결**:
1. 서브넷이 서로 다른 AZ에 있는지 확인
2. 보안 그룹 규칙 확인
3. DB 서브넷 그룹 설정 확인
4. KMS 키 권한 확인 (암호화 사용 시)

### 연결할 수 없음

**증상**: 애플리케이션에서 DB에 연결 실패

**해결**:
1. 보안 그룹 인바운드 규칙 확인
2. DB 인스턴스 상태 확인 (available이어야 함)
3. 엔드포인트 및 포트 번호 확인
4. 네트워크 ACL 규칙 확인
5. 라우팅 테이블 확인

### 백업이 작동하지 않음

**증상**: 자동 백업이 생성되지 않음

**해결**:
1. `backup_retention_period`가 0보다 큰지 확인
2. 백업 윈도우가 유지 관리 윈도우와 겹치지 않는지 확인
3. 스토리지 공간 확인

### Performance Insights 활성화 실패

**증상**: Performance Insights를 활성화할 수 없음

**해결**:
1. 엔진이 Performance Insights를 지원하는지 확인
2. 인스턴스 클래스가 지원되는지 확인 (t2 인스턴스는 미지원)
3. KMS 키 권한 확인

## Security Considerations

- 프라이빗 서브넷에 RDS 배포 권장
- `publicly_accessible = false` 설정
- 암호화 활성화 (`storage_encrypted = true`)
- KMS 키 사용 권장 (기본 RDS 키 대신)
- 마스터 비밀번호는 AWS Secrets Manager에 저장
- 보안 그룹 규칙 최소화 (필요한 소스만 허용)
- IAM 데이터베이스 인증 고려
- SSL/TLS 연결 강제

## Performance Considerations

- 적절한 인스턴스 클래스 선택
- gp3 스토리지 사용 (비용 대비 성능 우수)
- Multi-AZ는 읽기 복제본과 다름 (failover 용도)
- Read Replica로 읽기 부하 분산
- Parameter Group으로 데이터베이스 튜닝
- Performance Insights로 성능 모니터링
- Enhanced Monitoring으로 OS 메트릭 확인

## Cost Optimization

- 개발/테스트 환경에서는 Multi-AZ 비활성화
- 적절한 인스턴스 크기 선택 (오버프로비저닝 방지)
- 스토리지 자동 확장 활용 (초기 비용 절감)
- 백업 보존 기간 최적화 (7일 vs 14일 vs 35일)
- 불필요한 CloudWatch Logs 내보내기 비활성화
- Performance Insights 보존 기간 최적화 (7일 vs 731일)
- Reserved Instances 고려 (프로덕션 환경)
