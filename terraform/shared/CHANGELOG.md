# Shared Infrastructure Changelog

Import 기반 공유 리소스 관리를 위한 변경 이력입니다.

## [1.3.0] - 2025-11-23

### Added
- **ACM Certificate Import**: `*.set-of.com` 와일드카드 인증서 Import 완료
  - ARN: `arn:aws:acm:ap-northeast-2:646886795421:certificate/4241052f-dc09-4be1-8e4b-08902fce4729`
  - SSM Parameters: `/shared/connectly/certificate/wildcard-set-of.com/*`
  - Lifecycle management: tags, tags_all ignore로 IAM 권한 제약 우회

- **Route53 Hosted Zone Import**: `set-of.com` 퍼블릭 호스팅 존 Import 완료
  - Zone ID: `Z104656329CL6XBYE8OIJ`
  - SSM Parameters: `/shared/connectly/dns/set-of-com/*`
  - Name servers 4개 자동 추출 및 SSM 저장

### Changed
- **IAM Policy Update**: TerraformFileFlowPolicy v10으로 업데이트
  - `route53:*`, `acm:*`, `ssm:*`, `rds:*` 전체 권한 추가
  - Import 시 ListTagsForResource 권한 오류 해결

- **Provider Configuration**: Import 시나리오에 맞춰 조정
  - `skip_requesting_account_id = true` 추가
  - `default_tags` 비활성화 (tags_all 충돌 방지)

### Fixed
- **ACM Tag Validation**: 와일드카드 도메인 태그 검증 오류 수정
  - Domain 태그를 tags merge에서 제거
  - lifecycle ignore_changes에 tags, tags_all 추가

- **Route53 Permission Issues**: ListTagsForResource 권한 오류 해결
  - IAM 정책 업데이트로 완전 해결
  - ignore_tags 설정으로는 해결 불가 확인

### Documentation
- **shared/README.md**: Import 기반 아키텍처로 전면 재작성
  - 4개 Import 리소스 상세 문서화 (ACM, Route53, RDS, VPC)
  - 실제 SSM Parameter 경로 및 사용 예시 추가
  - Import 프로세스 단계별 가이드 작성
  - Troubleshooting 섹션 추가 (태그 권한, SSM 조회 실패 등)

## [1.2.0] - 2025-11-22

### Added
- **RDS Instance Import**: `prod-shared-mysql` RDS 인스턴스 Import 완료
  - MySQL 8.0.35, db.t3.medium
  - Multi-AZ 구성, 100GB gp3 스토리지
  - SSM Parameters: `/shared/connectly/rds/*`

- **VPC Import**: `prod-shared-vpc` VPC Import 완료
  - CIDR: 10.0.0.0/16
  - Multi-AZ 구성 (ap-northeast-2a, 2b, 2c)
  - SSM Parameters: `/shared/connectly/vpc/*`

### Changed
- **Backend Configuration**: S3 backend 버킷명 수정
  - `prod-connectly-tfstate` → `prod-connectly`
  - DynamoDB 테이블: `prod-connectly-tf-lock`

## [1.1.0] - 2025-11-20

### Added
- **Template Structure**: 재사용 가능한 Terraform 템플릿 구조 확립
  - `templates/` 디렉토리: 신규 리소스 생성용
  - `shared/` 디렉토리: 기존 리소스 Import용
  - Import 자동화 스크립트 (`import.sh`)

### Changed
- **SSM Parameter Naming**: 네이밍 규칙 표준화
  - 패턴: `/shared/{project}/{category}/{resource-name}/{attribute}`
  - 예시: `/shared/connectly/certificate/wildcard-set-of.com/arn`

## [1.0.0] - 2025-11-15

### Added
- **Initial Setup**: Shared 인프라 디렉토리 구조 생성
  - Terraform backend 설정 (S3 + DynamoDB)
  - 공통 변수 및 로컬 값 정의
  - 필수 태그 정책 적용

### Documentation
- Shared 리소스 관리 가이드 초안 작성
- Import vs 신규 생성 전략 문서화

---

## Legend

- **Added**: 새로운 기능 또는 리소스 추가
- **Changed**: 기존 기능 또는 구성 변경
- **Fixed**: 버그 수정 또는 오류 해결
- **Removed**: 기능 또는 리소스 제거
- **Deprecated**: 향후 제거 예정
- **Security**: 보안 관련 변경
- **Documentation**: 문서 업데이트

## Import History Summary

| 리소스 타입 | 리소스 ID | Import 날짜 | 상태 |
|-----------|----------|------------|------|
| ACM Certificate | *.set-of.com | 2025-11-23 | ✅ Active |
| Route53 Zone | set-of.com | 2025-11-23 | ✅ Active |
| RDS Instance | prod-shared-mysql | 2025-11-22 | ✅ Active |
| VPC | prod-shared-vpc | 2025-11-22 | ✅ Active |

## Versioning Policy

- **Major (X.0.0)**: Breaking changes, 아키텍처 전면 변경
- **Minor (x.X.0)**: 새로운 리소스 Import, 주요 기능 추가
- **Patch (x.x.X)**: 버그 수정, 문서 업데이트, 마이너 설정 변경
