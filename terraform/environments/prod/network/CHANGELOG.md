# 변경 이력

네트워크 인프라의 모든 주요 변경사항은 이 파일에 문서화됩니다.

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
- VPC 인프라 (10.0.0.0/16)
- Multi-AZ 서브넷 구성
  - Public 서브넷 (ap-northeast-2a: 10.0.0.0/24, ap-northeast-2b: 10.0.1.0/24)
  - Private 서브넷 (ap-northeast-2a: 10.0.10.0/24, ap-northeast-2b: 10.0.11.0/24)
- Internet Gateway 및 NAT Gateway
- Transit Gateway (멀티 VPC 통신용)
  - Amazon Side ASN: 64512
  - DNS 지원 활성화
  - VPN ECMP 지원
  - 자동 라우트 수락
- VPC Attachment (Private 서브넷을 TGW에 연결)
- 라우팅 테이블 구성
- 표준 태그 규정 준수

### Architecture
- Multi-AZ 고가용성 구성
- Public/Private 서브넷 분리
- Transit Gateway를 통한 확장 가능한 네트워크 아키텍처
- 중앙 집중식 네트워크 허브

### Security
- Private 서브넷만 Transit Gateway 연결 (Public 서브넷 제외)
- NAT Gateway를 통한 Private 서브넷 아웃바운드 트래픽
- 보안 그룹 및 Network ACL 지원

[Unreleased]: https://github.com/ryuqqq/infrastructure/compare/network/v1.0.0...HEAD
[1.0.0]: https://github.com/ryuqqq/infrastructure/releases/tag/network/v1.0.0
