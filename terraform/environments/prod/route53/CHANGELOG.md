# 변경 이력

Route53 DNS 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 기반으로 하며,
이 프로젝트는 [Semantic Versioning](https://semver.org/lang/ko/)을 준수합니다.

## [Unreleased]

### Changed
- **[REFACTOR]** Modules v1.0.0 패턴으로 리팩토링
  - `variables.tf`: 필수 태그 변수 추가 (environment, service_name, team, owner, cost_center, project, data_class)
  - `locals.tf`: 태그 관리를 변수 기반으로 전환, 설정 값 중앙화 (health_check_config, log_config, kms_config)
  - `main.tf`: locals 값 사용으로 하드코딩 제거
  - 태그 governance 100% 준수

## [1.0.0] - 2025-10-22

### Added
- Route53 Hosted Zone (set-of.com)
  - NS 및 SOA 레코드
  - DNS 레코드 관리
- DNS 쿼리 로깅
  - CloudWatch Logs 연동 (`/aws/route53/set-of.com`)
  - 감사 추적 및 트러블슈팅
- Health Check (atlantis.set-of.com)
  - HTTPS 헬스체크
  - 엔드포인트 모니터링
- 재사용 가능한 route53-record 모듈
  - Simple records (A, AAAA, CNAME, TXT, MX)
  - Alias records (ALB, CloudFront, S3)
  - Weighted routing (Canary deployment)
  - Geolocation routing
  - Failover routing
- 기존 리소스 Import 지원
  - Hosted Zone import
  - DNS 레코드 import
- 표준 태그 규정 준수

### Architecture
- 중앙 집중식 DNS 관리
- CloudWatch Logs 쿼리 로깅
- Health Check 모니터링
- 모듈화된 DNS 레코드 관리

### Security
- DNS 쿼리 로깅 (감사 추적)
- Health Check를 통한 엔드포인트 모니터링
- `prevent_destroy` lifecycle (실수 삭제 방지)
- CloudTrail 감사 추적

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/route53/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/route53/v1.0.0
