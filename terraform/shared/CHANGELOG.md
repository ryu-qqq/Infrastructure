# 변경 이력

shared 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- SSM Parameter Store 크로스 스택 참조 아키텍처
- KMS 암호화 키 공유 패턴
  - `/shared/kms/cloudwatch-logs-key-arn` - CloudWatch Logs 암호화 키
  - `/shared/kms/secrets-manager-key-arn` - Secrets Manager 암호화 키
  - `/shared/kms/rds-key-arn` - RDS 데이터베이스 암호화 키
  - `/shared/kms/s3-key-arn` - S3 버킷 암호화 키
  - `/shared/kms/sqs-key-arn` - SQS 큐 암호화 키
  - `/shared/kms/ssm-key-arn` - SSM Parameter Store 암호화 키
  - `/shared/kms/elasticache-key-arn` - ElastiCache 암호화 키
  - `/shared/kms/ecs-secrets-key-arn` - ECS 비밀 관리 암호화 키
- 네트워크 인프라 공유 패턴
  - `/shared/network/vpc-id` - VPC ID
  - `/shared/network/public-subnet-ids` - 퍼블릭 서브넷 ID 목록
  - `/shared/network/private-subnet-ids` - 프라이빗 서브넷 ID 목록
- ECR 리포지토리 URL 공유
  - `/shared/ecr/fileflow-repository-url` - FileFlow ECR 리포지토리 URL
- RDS 데이터베이스 정보 공유
  - `/shared/rds/db-instance-id` - RDS 인스턴스 ID
  - `/shared/rds/address` - RDS 엔드포인트 주소
  - `/shared/rds/port` - RDS 포트 번호
  - `/shared/rds/security-group-id` - RDS 보안 그룹 ID
  - `/shared/rds/master-password-secret-name` - 마스터 비밀번호 Secrets Manager 이름
- Secrets Manager 비밀 공유
  - `/shared/secrets/atlantis-webhook-secret-arn` - Atlantis 웹훅 비밀 ARN
  - `/shared/secrets/atlantis-github-token-arn` - Atlantis GitHub 토큰 ARN
- 표준 태그 규정 준수
  - Owner, CostCenter, Environment, Lifecycle, DataClass
- 독립적인 스택 배포 기능
- 간접 참조를 통한 순환 종속성 방지

### Architecture
- 리소스 공유를 위한 Producer-Consumer 패턴
- 중앙 리소스 레지스트리로서의 SSM Parameter Store
- Terraform 스택 간 느슨한 결합
- 버전 독립적인 크로스 스택 참조

### Security
- 모든 공유 리소스는 고객 관리형 KMS 키로 암호화
- SSM Parameter 접근 제어를 위한 IAM 정책
- 공유 리소스에 대한 최소 권한 접근
- Terraform 코드 내 하드코딩된 비밀 없음

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/shared/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/shared/v1.0.0
