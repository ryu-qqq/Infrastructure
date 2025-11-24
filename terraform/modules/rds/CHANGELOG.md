# Changelog

All notable changes to the RDS Terraform module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
-

### Changed
-

### Fixed
-

## [2.0.0] - 2025-11-23

### BREAKING CHANGES
- **Removed `var.common_tags`**: Module now uses internal `common-tags` module
- **Added Required Variables**: Must provide `environment`, `service_name`, `team`, `owner`, `cost_center`
- **Module Dependency**: Now requires `../common-tags` module to be available

### Added
- Internal integration with `common-tags` module for standardized tagging
- New required variables: `environment`, `service_name`, `team`, `owner`, `cost_center`
- New optional variables: `project`, `data_class`, `additional_tags`
- Automatic tag validation through `common-tags` module
- Support for additional custom tags via `additional_tags` variable

### Changed
- Tagging pattern: `var.common_tags` → `module.tags.tags`
- All RDS resources now use tags from internal `common-tags` module
- DB Subnet Group, DB Parameter Group, and DB Instance tags updated
- Variable organization: Separated tagging variables from RDS configuration

### Migration Guide
**Before (v1.x)**:
```hcl
module "rds" {
  source = "../../modules/rds"

  identifier = "mydb"
  engine     = "postgres"
  # ... other RDS variables ...
  common_tags = module.common_tags.tags
}
```

**After (v2.x)**:
```hcl
module "rds" {
  source = "../../modules/rds"

  identifier = "mydb"
  engine     = "postgres"
  # ... other RDS variables ...

  environment  = "prod"
  service_name = "api-server"
  team         = "platform-team"
  owner        = "platform@example.com"
  cost_center  = "engineering"
}
```

## [1.0.0] - 2024-11-13

### Added
- Initial release of RDS module
- Support for multiple database engines (MySQL, PostgreSQL, MariaDB, Oracle, SQL Server)
- DB Subnet Group management
- DB Parameter Group with custom parameters
- KMS encryption support
- Multi-AZ deployment support
- Automated backup configuration
- Performance Insights integration
- Enhanced Monitoring support
- CloudWatch Logs export
- Storage autoscaling
- Comprehensive variable validation
- Basic example (MySQL)
- Advanced example (PostgreSQL with full features)

### Features
- ✅ Engine support: MySQL, PostgreSQL, MariaDB, Oracle (SE2/SE/EE), SQL Server (Express/Web/SE/EE)
- ✅ Storage types: gp2, gp3 (default), io1, io2, standard
- ✅ Encryption at rest with KMS key support
- ✅ Automated backups with configurable retention (0-35 days)
- ✅ Multi-AZ for high availability
- ✅ Performance Insights with 7 or 731 days retention
- ✅ Enhanced Monitoring with 1-60 second intervals
- ✅ CloudWatch Logs export per engine type
- ✅ Custom DB Parameter Groups
- ✅ Storage autoscaling (gp3/gp2 only)
- ✅ Deletion protection
- ✅ Final snapshot on deletion (optional)
- ✅ Common tags integration

### Validation
- Database name format and reserved words
- Engine type validation
- Instance class format
- Master username rules and reserved words
- Master password minimum length
- Subnet requirements (minimum 2 for HA)
- Storage size ranges
- Backup retention period
- Time window formats
- Storage type specific requirements (IOPS, throughput)
- Performance Insights engine compatibility
- Monitoring interval values

### Outputs
- Primary identifiers (ID, ARN, endpoint, address, port)
- Database configuration (engine, version, name, username)
- Resource configuration (class, storage)
- Network configuration (subnet group, availability zone, multi-AZ)
- Parameter group information
- Monitoring and performance settings
- Security and backup configuration

## Release Notes

### Initial Release

이 릴리스는 RDS 모듈의 첫 번째 버전으로, 프로덕션 환경에서 사용 가능한 완전한 기능을 제공합니다.

#### 주요 기능
- 다양한 데이터베이스 엔진 지원
- 보안: KMS 암호화, 프라이빗 서브넷 배포
- 고가용성: Multi-AZ, 자동 백업
- 모니터링: Performance Insights, Enhanced Monitoring, CloudWatch Logs
- 성능: 스토리지 자동 확장, 커스텀 파라미터 그룹
- 안전성: 포괄적인 입력 검증, 삭제 방지

#### 사용 예제
- Basic: 최소 설정으로 MySQL 인스턴스 배포
- Advanced: 프로덕션 환경을 위한 완전한 기능의 PostgreSQL 인스턴스

#### 관련 작업

## [0.1.0] - TBD

Initial release after validation and review.
