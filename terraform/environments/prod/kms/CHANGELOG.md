# 변경 이력

KMS 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 기반으로 하며,
이 프로젝트는 [Semantic Versioning](https://semver.org/lang/ko/)을 준수합니다.

## [Unreleased]

### Added
-

### Changed
-

### Fixed
-

### Security
-

## [1.0.0] - 2025-10-22

### Added
- 공통 플랫폼 KMS 키 인프라
  - **terraform_state** (alias/terraform-state): Terraform State S3 암호화
  - **rds** (alias/rds-encryption): RDS 인스턴스 암호화
  - **ecs_secrets** (alias/ecs-secrets): ECS task secrets 암호화
  - **secrets_manager** (alias/secrets-manager): Secrets Manager 암호화
- 데이터 분류 기반 키 분리
  - confidential: terraform_state, ecs_secrets
  - highly-confidential: rds, secrets_manager
- 자동 키 회전 활성화 (연간)
- 30일 삭제 대기 기간
- 서비스별 최소 권한 키 정책
  - Terraform State: S3, GitHub Actions
  - RDS: RDS 서비스, GitHub Actions
  - ECS Secrets: ECS Tasks, Secrets Manager, GitHub Actions
  - Secrets Manager: Secrets Manager, 애플리케이션 역할, GitHub Actions
- 표준 태그 규정 준수

### Architecture
- 데이터 분류 기반 키 분리 전략
- 서비스별 독립 키 관리
- 최소 권한 접근 제어

### Security
- 모든 키 자동 회전 활성화
- CloudTrail을 통한 모든 키 작업 로깅
- 최소 권한 키 정책
- 30일 삭제 대기 기간으로 실수 방지
- 하드코딩된 비밀 없음

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/kms/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/kms/v1.0.0
