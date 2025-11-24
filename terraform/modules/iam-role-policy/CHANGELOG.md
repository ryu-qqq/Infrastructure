# Changelog

이 파일은 `iam-role-policy` 모듈의 모든 주요 변경사항을 문서화합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 따르며,
이 프로젝트는 [Semantic Versioning](https://semver.org/lang/ko/)을 준수합니다.

## [1.0.0] - 2025-11-23

### Added

- 초기 모듈 릴리스
- IAM 역할 생성 및 관리 기능
- ECS Task Execution Policy 지원
  - ECR 이미지 풀 권한
  - CloudWatch Logs 작성 권한
  - KMS 복호화 권한
- ECS Task Policy 지원
  - ECS 태스크 조회 권한
  - 클러스터 기반 조건부 접근 제어
- RDS Access Policy 지원
  - RDS 클러스터/인스턴스 조회
  - RDS IAM 데이터베이스 인증 (rds-db:connect)
- Secrets Manager Policy 지원
  - 시크릿 읽기 권한 (GetSecretValue, DescribeSecret)
  - 시크릿 생성 권한 (ManagedBy=terraform 태그 강제)
  - 시크릿 업데이트 권한 (PutSecretValue, UpdateSecret)
  - 시크릿 삭제 권한 (DeleteSecret)
- S3 Access Policy 지원
  - 버킷 레벨 권한 (ListBucket, GetBucketLocation)
  - 객체 읽기 권한 (GetObject, GetObjectVersion)
  - 객체 쓰기 권한 (PutObject, DeleteObject)
  - KMS 암호화/복호화 권한
- CloudWatch Logs Policy 지원
  - 로그 그룹 생성 권한 (/aws/* 프리픽스 제한)
  - 로그 스트림 생성/조회 권한
  - 로그 이벤트 작성 권한
  - KMS 암호화 권한
- AWS 관리형 정책 연결 지원 (`attach_aws_managed_policies`)
- 커스텀 인라인 정책 지원 (`custom_inline_policies`)
- 통합 KMS 키 관리 (`kms_key_arns`)
- `common-tags` 모듈 통합
- 입력 변수 검증
  - `role_name`: kebab-case, 64자 이하
  - `environment`: dev, staging, prod 제한
  - `service_name`, `team`, `cost_center`, `project`: kebab-case
  - `owner`: 이메일 또는 kebab-case
  - `max_session_duration`: 3600-43200초
  - `data_class`: confidential, internal, public 제한
- 출력값
  - `role_arn`: IAM 역할 ARN
  - `role_name`: IAM 역할 이름
  - `role_id`: IAM 역할 ID
  - `role_unique_id`: AWS 할당 고유 ID
  - `attached_policy_arns`: 연결된 AWS 관리형 정책 목록
  - `inline_policy_names`: 연결된 인라인 정책 이름 목록

### Security

- 최소 권한 원칙 준수 (모든 정책 기본 비활성화)
- ARN 기반 리소스 제한 (와일드카드 최소화)
- ECS 클러스터 조건부 접근 제어
- Secrets Manager 생성 시 태그 강제 (ManagedBy=terraform)
- CloudWatch Logs 생성 시 프리픽스 제한 (/aws/*)
- KMS 암호화/복호화 권한 통합 관리
- 권한 경계(permissions_boundary) 지원
- 세션 시간 제한 (기본 1시간, 최대 12시간)

[1.0.0]: https://github.com/your-org/infrastructure/releases/tag/iam-role-policy-v1.0.0
