# 변경 이력

Atlantis 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- ECS Fargate 기반 Atlantis 서버 인프라
  - ECS 클러스터 (Container Insights 활성화)
  - Fargate 및 Fargate Spot 용량 제공자
- ECS Task Definition
  - CPU: 512 units, Memory: 1024 MiB
  - 컨테이너 포트: 4141
  - 헬스체크: `/healthz` 엔드포인트
  - CloudWatch Logs 연동 (7일 보관)
- ECR 리포지토리
  - KMS 암호화
  - 푸시 시 이미지 스캔 활성화
  - 라이프사이클 정책 (최근 10개 버전 유지)
- Application Load Balancer 구성
  - Internet-facing ALB
  - HTTP (80) → HTTPS (443) 영구 리다이렉트
  - TLS 1.3 지원
  - Cross-zone 로드 밸런싱 활성화
  - Target Group (IP 타겟 타입)
- IAM 역할 및 정책
  - Task Execution Role (ECR 접근, 로그 게시)
  - Task Role (Terraform 작업, S3 State 접근)
- 보안 그룹
  - ALB 보안 그룹 (HTTP/HTTPS 인바운드)
  - ECS Task 보안 그룹 (ALB로부터만 접근)
- ACM 인증서 연동 (`*.set-of.com`)

### Architecture
- Fargate 서버리스 컴퓨팅 플랫폼
- Multi-AZ 고가용성 구성
- KMS 암호화 계층 (ECR, CloudWatch Logs)
- 최소 권한 IAM 정책

### Security
- ECR 이미지 KMS 암호화
- 푸시 시 보안 취약점 자동 스캔
- HTTPS 전용 통신 (HTTP → HTTPS 리다이렉트)
- Private 서브넷 배포 (ECS Tasks)
- 최소 권한 IAM 역할
- 표준 태그 규정 준수 (Owner, CostCenter, Environment 등)

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/atlantis/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/atlantis/v1.0.0
