# 변경 이력

ECR 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- 초기 ECR 인프라 구성
- KMS 암호화를 사용한 FileFlow ECR 리포지토리
- 푸시 시 이미지 스캔 활성화
- 이미지 보존 관리를 위한 라이프사이클 정책
  - v* 접두사 태그 이미지 최대 30개 유지
  - 태그 없는 이미지는 7일 후 제거
- 동일 계정 접근을 위한 리포지토리 접근 정책
- 크로스 스택 참조를 위한 SSM Parameter Store 내보내기
  - `/shared/ecr/fileflow-repository-url`
- 표준 태그 규정 준수
  - Owner, CostCenter, Environment, Lifecycle, DataClass
- 고객 관리형 키를 사용한 KMS 암호화
  - SSM Parameter Store에서 키 ARN 조회 (`/shared/kms/ecs-secrets-key-arn`)

### Security
- 모든 리포지토리는 KMS 고객 관리형 키로 암호화
- 푸시 시 이미지 취약점 스캔 활성화
- 동일 AWS 계정으로만 리포지토리 접근 제한

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/ecr/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/ecr/v1.0.0
