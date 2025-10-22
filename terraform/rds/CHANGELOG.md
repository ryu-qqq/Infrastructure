# 변경 이력

RDS 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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

## [1.0.0] - 2025-10-19

### Added
- 운영 환경 공유 MySQL RDS 인스턴스
  - MySQL 8.0.35 (LTS)
  - db.t4g.small (2 vCPU, 2GB RAM)
  - gp3 스토리지 (30GB → 200GB 자동 확장)
- Multi-AZ 고가용성 구성 (99.95% 가용성)
- 자동 백업 및 복구
  - 14일 백업 보존
  - Point-in-Time Recovery (5분 단위)
  - 백업 시간: 매일 03:00-04:00 UTC
- KMS 암호화
  - 저장 데이터: alias/rds-encryption
  - Performance Insights: alias/rds-encryption
  - Secrets Manager: alias/secrets-manager
- Secrets Manager 통합
  - 마스터 비밀번호 안전 저장
  - 연결 정보 중앙 관리
- CloudWatch Logs 전송
  - 에러 로그: `/aws/rds/instance/prod-shared-mysql/error`
  - 일반 로그: `/aws/rds/instance/prod-shared-mysql/general`
  - 슬로우 쿼리: `/aws/rds/instance/prod-shared-mysql/slowquery`
- Performance Insights (7일 보존)
- Enhanced Monitoring
- CloudWatch 알람
  - CPU 사용률 (80% 임계값)
  - 여유 스토리지 (5GB 임계값)
  - 여유 메모리 (256MB 임계값)
  - 데이터베이스 연결 수 (180개 임계값)
  - Read/Write 지연시간 (100ms 임계값)
- Private 서브넷 배포 (Multi-AZ)
- SSM Parameter Store 내보내기
  - `/shared/rds/db-instance-id`
  - `/shared/rds/address`
  - `/shared/rds/port`
  - `/shared/rds/security-group-id`
  - `/shared/rds/master-password-secret-name`

### Architecture
- Multi-AZ 자동 페일오버
- Private 서브넷 격리
- Secrets Manager를 통한 자격증명 관리
- 성능 모니터링 및 알람 체계

### Security
- KMS 고객 관리형 키 암호화
- Secrets Manager 비밀번호 관리
- Private 서브넷 배포 (퍼블릭 접근 불가)
- 보안 그룹 기반 접근 제어
- CloudTrail 감사 추적
- 삭제 방지 (Deletion Protection) 활성화
- 표준 태그 규정 준수

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/rds/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/rds/v1.0.0
