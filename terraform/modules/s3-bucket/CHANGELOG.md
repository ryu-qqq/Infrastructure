# Changelog

All notable changes to the S3 Bucket module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-23

### Added

#### Core S3 기능
- S3 버킷 생성 기본 기능
- 서버 측 암호화 설정 (KMS 또는 AES256)
- 버전 관리 지원
- 퍼블릭 액세스 차단 설정
- 강제 삭제 옵션 (`force_destroy`)

#### 고급 S3 기능
- Object Lock (WORM) 지원
  - GOVERNANCE 및 COMPLIANCE 모드
  - 일/년 단위 보존 기간 설정
- 액세스 로깅 설정
  - 대상 버킷 및 접두사 구성
- 수명 주기 정책
  - STANDARD_IA로 전환
  - GLACIER로 전환
  - 객체 만료
  - 비현재 버전 만료
  - 미완료 멀티파트 업로드 중단
- CORS 규칙 설정
  - 허용된 헤더, 메서드, 오리진 구성
  - 노출 헤더 및 캐시 시간 설정
- 정적 웹사이트 호스팅
  - 인덱스 문서 및 에러 문서 구성

#### 모니터링 및 알람
- CloudWatch 알람 통합
  - 버킷 크기 임계값 알람
  - 객체 수 임계값 알람
  - SNS 토픽 알림 설정
  - 사용자 정의 평가 기간
- S3 Request Metrics
  - 전체 버킷 또는 접두사별 메트릭
  - 상세한 성능 모니터링

#### 거버넌스 및 규정 준수
- `common-tags` 모듈 통합
  - 필수 태그 자동 적용 (Owner, CostCenter, Environment 등)
  - 추가 태그 병합 지원
- 명명 규칙 검증
  - 버킷 이름 kebab-case 강제
  - 태그 필드 kebab-case 검증
- 환경 검증 (dev, staging, prod)
- 데이터 분류 검증 (confidential, internal, public)

#### 입력 변수
- **필수 변수**: bucket_name, environment, service_name, team, owner, cost_center
- **선택 변수 (태그)**: project, data_class, additional_tags
- **선택 변수 (S3)**: kms_key_id, versioning_enabled, force_destroy, 퍼블릭 액세스 설정
- **선택 변수 (로깅)**: logging_enabled, logging_target_bucket, logging_target_prefix
- **선택 변수 (수명 주기)**: lifecycle_rules
- **선택 변수 (CORS)**: cors_rules
- **선택 변수 (웹사이트)**: enable_static_website, website_index_document, website_error_document
- **선택 변수 (모니터링)**: enable_cloudwatch_alarms, alarm 임계값 및 설정, enable_request_metrics
- **선택 변수 (Object Lock)**: enable_object_lock, object_lock_mode, retention 설정

#### 출력 값
- 버킷 정보: id, arn, domain_name, regional_domain_name, region, tags
- 웹사이트: website_endpoint, website_domain
- 모니터링: CloudWatch 알람 ARN, request_metrics_name
- Object Lock: object_lock_enabled, object_lock_configuration

#### 문서화
- 종합적인 README.md (한국어)
  - 주요 기능 설명
  - 8개의 상세한 사용 예제
  - 전체 변수 및 출력 값 문서
  - 거버넌스 준수 가이드
  - 보안 모범 사례
  - 수명 주기 관리 전략
  - 모니터링 및 알람 설정
  - 통합 예제
- CHANGELOG.md 생성

### Requirements

- Terraform >= 1.5.0
- AWS Provider >= 5.0
- common-tags 모듈 (내부 종속성)

### Notes

- 이 버전은 S3 버킷 모듈의 초기 안정 릴리스입니다
- 모든 거버넌스 규정 및 보안 요구 사항을 충족합니다
- 프로덕션 환경에서 사용 가능합니다

---

## Version Guidelines

버전 번호는 [Semantic Versioning](https://semver.org/)을 따릅니다:

- **MAJOR** (X.0.0): 호환되지 않는 API 변경
- **MINOR** (0.X.0): 하위 호환 기능 추가
- **PATCH** (0.0.X): 하위 호환 버그 수정
