# Changelog Template

모든 Terraform 모듈은 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) 형식을 따르며, [Semantic Versioning](https://semver.org/)을 준수합니다.

## CHANGELOG.md 파일 위치

각 모듈 디렉터리에 `CHANGELOG.md` 파일을 생성합니다:

```
terraform/modules/{module-name}/CHANGELOG.md
```

## 기본 템플릿

```markdown
# Changelog

All notable changes to this module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
-

### Changed
-

### Deprecated
-

### Removed
-

### Fixed
-

### Security
-

## [1.0.0] - 2025-10-14

### Added
- Initial release
- {주요 기능 1}
- {주요 기능 2}
- {주요 기능 3}

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/modules/{module-name}/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/modules/{module-name}/v1.0.0
```

## 변경 타입 (Change Types)

### Added
새로운 기능 추가

**예시:**
- Added support for custom security groups
- Added `enable_monitoring` variable
- Added health check configuration options

### Changed
기존 기능의 변경 (하위 호환 유지)

**예시:**
- Changed default retention period from 7 to 14 days
- Changed output format to include more details
- Updated default AMI to latest version

### Deprecated
향후 제거될 예정인 기능 (아직 동작함)

**예시:**
- Deprecated `old_variable` in favor of `new_variable`
- Deprecated legacy tag format

### Removed
제거된 기능 (Breaking Change)

**예시:**
- Removed support for Terraform < 1.5.0
- Removed deprecated `old_variable`

### Fixed
버그 수정

**예시:**
- Fixed tag merging issue
- Fixed validation error for special characters
- Fixed output value typo

### Security
보안 관련 수정

**예시:**
- Fixed security group rule allowing unrestricted access
- Updated IAM policy to follow least privilege principle
- Added encryption at rest by default

## 작성 규칙

### 1. 시제와 톤
- **명령형 현재 시제 사용**: "Add feature" (not "Added feature")
- **간결하고 명확하게**: 한 줄로 변경 사항 요약
- **사용자 관점**: 사용자에게 영향을 주는 내용만 기록

### 2. 변경 사항 설명
```markdown
### Added
- Variable `custom_tags` for additional resource tagging
- Output `log_group_arn` for CloudWatch integration
- Validation for naming convention compliance

### Changed
- Default `retention_days` from 7 to 30 for compliance
- Resource naming to include environment prefix

### Fixed
- Tag merging not working with complex tag maps
- Validation error when using special characters
```

### 3. Breaking Changes 강조
```markdown
## [2.0.0] - 2025-10-20

### ⚠️ BREAKING CHANGES

- **Variable type change**: `name` is now `object` instead of `string`
  - Migration: Update `name = "foo"` to `name = { prefix = "foo", suffix = "" }`
- **Required variable**: `vpc_id` is now required
  - Migration: Add `vpc_id = "vpc-xxxxx"` to module configuration

### Added
- Support for multi-AZ deployment

### Changed
- Internal resource naming structure (requires recreation)

### Removed
- Support for Terraform < 1.5.0
```

### 4. 링크 추가
```markdown
## [1.2.0] - 2025-10-15

### Added
- Health check configuration ([#123](https://github.com/ryuqqq/infrastructure/pull/123))
- Custom alarm thresholds ([IN-142](https://ryuqqq.atlassian.net/browse/IN-142))

### Fixed
- Memory leak in log rotation ([#125](https://github.com/ryuqqq/infrastructure/pull/125))
```

## 실제 예시

### 예시 1: ECS Service Module

```markdown
# Changelog

## [Unreleased]

## [1.2.0] - 2025-11-01

### Added
- Variable `enable_circuit_breaker` for ECS deployment circuit breaker
- Variable `health_check_grace_period_seconds` for task startup time
- Output `task_definition_family` for external reference

### Changed
- Default `desired_count` from 1 to 2 for high availability
- Improved validation messages for clearer error guidance

### Fixed
- Task definition not updating when environment variables change
- Service discovery namespace creation race condition

## [1.1.0] - 2025-10-20

### Added
- Auto scaling based on CPU and memory utilization
- CloudWatch Container Insights integration
- Service discovery support via Cloud Map

### Changed
- Updated default task CPU from 256 to 512 for better performance

### Fixed
- Load balancer health check path validation

## [1.0.0] - 2025-10-10

### Added
- Initial release
- ECS service creation with Fargate launch type
- ALB target group integration
- Standard tagging via common-tags module
- Task definition with container definitions
- Security group creation

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/modules/ecs-service/v1.2.0...HEAD
[1.2.0]: https://github.com/ryuqqq/infrastructure/compare/modules/ecs-service/v1.1.0...modules/ecs-service/v1.2.0
[1.1.0]: https://github.com/ryuqqq/infrastructure/compare/modules/ecs-service/v1.0.0...modules/ecs-service/v1.1.0
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/modules/ecs-service/v1.0.0
```

### 예시 2: RDS Instance Module

```markdown
# Changelog

## [Unreleased]

### Added
- Variable `performance_insights_retention_period` for extended retention

## [2.0.0] - 2025-11-05

### ⚠️ BREAKING CHANGES

- **Required variable**: `kms_key_id` is now required for encryption at rest
  - Migration: Provide KMS key ARN via `kms_key_id = aws_kms_key.rds.arn`
- **Removed variable**: `publicly_accessible` (security best practice)
  - Migration: Remove from module configuration

### Added
- Automatic daily backups with configurable retention
- Enhanced monitoring with CloudWatch Logs export
- Automated minor version upgrades

### Changed
- Default `backup_retention_period` from 7 to 30 days
- Storage encryption is now mandatory

### Security
- Enforced SSL connections for all database connections
- Removed support for public accessibility

## [1.1.0] - 2025-10-25

### Added
- Multi-AZ deployment support
- Read replica creation option
- Parameter group customization

### Fixed
- Subnet group not respecting availability zones

## [1.0.0] - 2025-10-15

### Added
- Initial release
- RDS instance creation (PostgreSQL, MySQL)
- Standard tagging
- Security group integration
- Backup configuration

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/modules/rds-instance/v2.0.0...HEAD
[2.0.0]: https://github.com/ryuqqq/infrastructure/compare/modules/rds-instance/v1.1.0...modules/rds-instance/v2.0.0
[1.1.0]: https://github.com/ryuqqq/infrastructure/compare/modules/rds-instance/v1.0.0...modules/rds-instance/v1.1.0
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/modules/rds-instance/v1.0.0
```

## 업데이트 워크플로우

### 1. 개발 중
```markdown
## [Unreleased]

### Added
- New feature description

### Fixed
- Bug fix description
```

### 2. 릴리스 준비
```markdown
## [1.1.0] - 2025-10-20

### Added
- New feature description

### Fixed
- Bug fix description

## [1.0.0] - 2025-10-10
...
```

### 3. 링크 업데이트
```markdown
[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/modules/{module-name}/v1.1.0...HEAD
[1.1.0]: https://github.com/ryuqqq/infrastructure/compare/modules/{module-name}/v1.0.0...modules/{module-name}/v1.1.0
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/modules/{module-name}/v1.0.0
```

## 자동화 도구

### Pre-commit Hook (향후)
```bash
# .git/hooks/pre-commit
# CHANGELOG.md가 업데이트되었는지 확인
```

### CI/CD 검증 (향후)
```yaml
# .github/workflows/changelog-check.yml
# PR에 CHANGELOG 업데이트가 포함되었는지 확인
```

## 체크리스트

릴리스 전 CHANGELOG 확인:

- [ ] 버전 번호가 Semantic Versioning을 따르는가?
- [ ] 날짜가 정확한가?
- [ ] 모든 변경 사항이 적절한 섹션에 기록되었는가?
- [ ] Breaking Changes가 명확히 표시되었는가?
- [ ] 마이그레이션 가이드가 포함되었는가? (Breaking Changes의 경우)
- [ ] PR 및 Issue 링크가 추가되었는가?
- [ ] 비교 링크가 올바르게 업데이트되었는가?

## 관련 문서

- [Semantic Versioning 가이드](./VERSIONING.md)
- [모듈 디렉터리 구조](./MODULES_DIRECTORY_STRUCTURE.md)
- [Keep a Changelog](https://keepachangelog.com/)
- [Semantic Versioning](https://semver.org/)

## Epic & Task

- **Epic**: [IN-100 - 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)
- **Task**: [IN-121 - 모듈 디렉터리 구조 설계](https://ryuqqq.atlassian.net/browse/IN-121)
