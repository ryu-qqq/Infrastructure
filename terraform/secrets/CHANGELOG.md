# 변경 이력

Secrets Manager 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- AWS Secrets Manager 중앙 집중식 시크릿 관리
- 표준화된 네이밍 규칙 (`/ryuqqq/{service}/{env}/{name}`)
- KMS 암호화 (alias/secrets-manager)
  - 저장 데이터 보호
  - 자동 키 회전
- 자동 로테이션 (90일 주기)
  - Lambda 로테이션 함수
  - 지원 타입: RDS, API 키, 일반 시크릿
- 서비스별 최소 권한 IAM 정책
  - 읽기 전용 정책 (애플리케이션)
  - 관리 정책 (DevOps)
- CloudWatch Logs 연동
  - Lambda 로테이션 로그
  - 로테이션 실패 알람
- ECS Task Definition 통합 가이드
- 애플리케이션 SDK 예제 (Python, Node.js)
- 30일 복구 기간
- 표준 태그 규정 준수

### Architecture
- 중앙 집중식 시크릿 관리
- KMS 암호화 계층
- Lambda 기반 자동 로테이션
- 서비스별 최소 권한 접근 제어

### Security
- KMS 고객 관리형 키 암호화
- 90일 자동 로테이션
- 최소 권한 IAM 정책
- CloudWatch Logs 감사 추적
- 30일 복구 기간 (실수 삭제 방지)
- CloudTrail 감사 추적
- 하드코딩된 비밀 없음
- 필수 태그 (DataClass: highly-confidential)

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/secrets/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/secrets/v1.0.0
