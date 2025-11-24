# 변경 이력

모니터링 시스템 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- Amazon Managed Prometheus (AMP) Workspace
  - 메트릭 수집 및 저장
  - 150일 데이터 보존
  - SigV4 인증
- Amazon Managed Grafana (AMG) Workspace
  - 시각화 및 대시보드
  - AWS SSO 인증
- AWS Distro for OpenTelemetry (ADOT) Collector 설정
  - ECS Task 통합
  - 메트릭 수집 에이전트
- IAM 역할 및 정책
  - ECS Task Role (amp-writer): AMP 메트릭 전송
  - Grafana Role (amp-reader): AMP 쿼리 및 CloudWatch 조회
- SNS Topics (3단계 알림)
  - Critical: 즉시 대응 필요 (P0)
  - Warning: 30분 이내 대응 (P1)
  - Info: 정보성 알림 (P2)
- AWS Chatbot Slack 연동
  - Critical, Warning, Info 채널별 알림
- CloudWatch Alarms (ECS 서비스)
  - Task Count Zero (Critical)
  - High Memory 95% (Critical)
  - High CPU 80% (Warning)
  - High Memory 80% (Warning)
- Runbook 문서
  - ECS High CPU 대응 절차
  - ECS Memory Critical 대응 절차
  - ECS Task Count Zero 대응 절차
- 표준 태그 규정 준수

### Architecture
- AMP + AMG 기반 중앙 관측성 시스템
- ADOT Collector를 통한 메트릭 수집
- SNS + Chatbot을 통한 다단계 알림
- CloudWatch 알람 및 대시보드 통합

### Security
- SigV4 인증을 통한 AMP 접근
- AWS SSO 기반 Grafana 접근 제어
- 최소 권한 IAM 정책
- CloudTrail 감사 추적

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/monitoring/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/monitoring/v1.0.0
