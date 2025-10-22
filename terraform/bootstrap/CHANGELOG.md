# 변경 이력

Bootstrap 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- Terraform Backend 인프라
- S3 Bucket (`prod-connectly`)
  - Terraform state 파일 저장소
  - 버저닝 활성화 (복구 가능)
  - KMS 암호화 (alias/terraform-state)
  - 퍼블릭 액세스 차단
  - 안전하지 않은 전송 거부 (HTTPS 강제)
  - 암호화되지 않은 업로드 거부
  - Lifecycle 정책
    - 90일 후 이전 버전 자동 삭제
    - 7일 후 미완료 멀티파트 업로드 삭제
- DynamoDB Table (`prod-connectly-tf-lock`)
  - Terraform state 잠금 메커니즘
  - PAY_PER_REQUEST 결제 모드
  - KMS 암호화
  - 특정 시점 복구 (PITR) 활성화
  - LockID 해시 키
- KMS Key (`alias/terraform-state`)
  - Terraform state 암호화
  - 자동 키 회전 활성화
  - 30일 삭제 대기 기간
- 기존 리소스 Import 가이드
- 표준 태그 규정 준수

### Architecture
- S3 + DynamoDB 기반 Terraform Backend
- KMS 암호화 계층
- 버저닝을 통한 state 복구 기능

### Security
- KMS 암호화 (S3, DynamoDB)
- 버저닝 (실수 삭제 복구)
- 퍼블릭 액세스 차단 (S3)
- HTTPS 전용 통신 (HTTP 거부)
- 암호화 강제 (S3 업로드)
- PITR (DynamoDB 복구)
- 자동 키 회전 (KMS)
- 30일 삭제 대기 기간 (KMS)

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/bootstrap/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/bootstrap/v1.0.0
