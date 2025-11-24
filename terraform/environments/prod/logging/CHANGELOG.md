# 변경 이력

로깅 시스템 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- CloudWatch Logs 기반 중앙 로깅 시스템
- Log Groups
  - `/aws/ecs/atlantis/application` (14일 보존)
  - `/aws/ecs/atlantis/errors` (90일 보존, Sentry 연동 대상)
  - `/aws/lambda/secrets-manager-rotation` (14일 보존)
- KMS 암호화 (alias/cloudwatch-logs)
  - 저장 데이터 암호화
  - 자동 키 회전
- 로그 타입별 Retention 정책
  - application: 14일
  - errors: 90일 (장기 보존)
  - llm: 60일 (향후)
- 표준화된 네이밍 규칙 (`/org/service/env/component`)
- 재사용 가능한 cloudwatch-log-group 모듈
- 90+ Logs Insights 쿼리 템플릿
- 향후 통합 준비
  - Sentry (에러 추적)
  - Langfuse (LLM 관측성)
  - S3 Export (장기 아카이브)

### Architecture
- CloudWatch Logs 중앙 허브
- 로그 타입별 차등 보존 정책
- KMS 암호화 계층
- Logs Insights 쿼리 및 분석

### Security
- KMS 암호화 (전송 중 및 저장 중)
- 자동 키 rotation
- IAM 역할 기반 접근 제어
- CloudTrail 감사 추적
- 최소 권한 원칙

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/logging/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/logging/v1.0.0
