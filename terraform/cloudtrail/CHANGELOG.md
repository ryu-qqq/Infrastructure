# 변경 이력

CloudTrail 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- Multi-region CloudTrail 구성
  - 모든 AWS API 활동 추적
  - 로그 파일 검증 활성화
  - 글로벌 서비스 이벤트 포함
- S3 버킷 (CloudTrail 로그 저장)
  - KMS 암호화
  - 버저닝 활성화
  - 퍼블릭 액세스 차단
  - Lifecycle 정책 (30일 후 Glacier 전환)
- CloudWatch Logs 통합 (7일 보존)
- Athena 쿼리 환경
  - Athena Workgroup (cloudtrail-analysis)
  - Glue Database 및 Table
  - 사전 구축된 Named Queries (4개)
    - unauthorized-api-calls
    - root-account-usage
    - console-login-failures
    - iam-policy-changes
- EventBridge 보안 이벤트 모니터링 (5개 규칙)
  - Root 계정 사용
  - 권한 없는 API 호출
  - IAM 정책 변경
  - 콘솔 로그인 실패
  - 보안 그룹 변경
- SNS 알림 토픽 (보안 이벤트 알람)
- KMS 암호화 키 (CloudTrail 전용)

### Architecture
- Multi-region 감사 추적
- S3 + Glacier 계층형 스토리지
- CloudWatch Logs 실시간 모니터링
- Athena 로그 분석 환경
- EventBridge 보안 이벤트 탐지

### Security
- KMS 암호화 (저장 데이터)
- SSL/TLS 강제 (S3 접근)
- 로그 파일 검증 (무결성 보장)
- 버저닝 (실수 삭제 방지)
- 퍼블릭 액세스 차단
- CloudTrail을 통한 모든 키 작업 로깅
- 컴플라이언스 지원 (CIS, GDPR, SOC 2)

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/cloudtrail/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/cloudtrail/v1.0.0
