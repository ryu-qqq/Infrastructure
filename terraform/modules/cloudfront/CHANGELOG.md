# Changelog

CloudFront Distribution 모듈의 모든 주요 변경사항이 이 파일에 문서화됩니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 기반으로 하며,
이 프로젝트는 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [1.0.0] - 2025-11-23

### Added
- CloudFront Distribution 모듈 초기 릴리스
- 다중 오리진 지원 (S3 및 커스텀 오리진)
- 기본 캐시 동작 구성
- 정렬된 캐시 동작 지원 (경로 기반 라우팅)
- SSL/TLS 인증서 구성 (ACM 통합)
- Lambda@Edge 함수 연결
- CloudFront Functions 연결
- 커스텀 에러 응답 구성
- 액세스 로깅 설정
- 지역 제한 (Geo-restriction) 지원
- AWS WAF 통합
- HTTP/2 및 HTTP/3 지원
- IPv6 지원
- 가격 클래스 선택 옵션
- 커스텀 헤더 전달
- 쿠키 및 쿼리 스트링 전달 구성
- 압축 활성화 옵션
- `common-tags` 모듈 통합으로 표준 태깅

### Features
- **오리진 구성**: S3 Origin Access Identity 및 커스텀 오리진 프로토콜 정책
- **캐시 제어**: TTL 설정 (min, default, max)
- **보안**: TLS 1.2+ 지원, HTTPS 리디렉션, WAF 연결
- **성능**: 자동 압축, HTTP/2, HTTP/3, 글로벌 엣지 로케이션
- **모니터링**: CloudWatch 메트릭, 액세스 로그
- **유연성**: 동적 블록을 활용한 선택적 구성 요소
- **검증**: 모든 주요 변수에 대한 입력 검증 규칙

### Configuration
- 기본 HTTP 버전: `http2`
- 기본 TLS 버전: `TLSv1.2_2021`
- 기본 가격 클래스: `PriceClass_100` (북미, 유럽)
- 기본 뷰어 프로토콜: `redirect-to-https`
- 기본 루트 객체: `index.html`
- 기본 TTL: 3600초 (1시간)
- 최대 TTL: 86400초 (24시간)
- IPv6 기본 활성화

### Outputs
- `distribution_arn`: CloudFront 배포 ARN
- `distribution_domain_name`: 배포 도메인 이름
- `distribution_hosted_zone_id`: Route 53 호스팅 영역 ID
- `distribution_id`: 배포 ID
- `distribution_status`: 배포 상태
- `distribution_etag`: 배포 ETag
- `distribution_in_progress_validation_batches`: 진행 중인 무효화 배치 수
- `distribution_last_modified_time`: 마지막 수정 시간
- `distribution_caller_reference`: 내부 참조값

### Documentation
- 한국어 README.md 작성
- 다양한 사용 예시 제공:
  - 기본 S3 오리진 배포
  - 커스텀 오리진 (API Gateway/ALB)
  - Lambda@Edge 및 CloudFront Functions 통합
  - 다중 오리진 및 경로 기반 라우팅
  - 로깅 및 지역 제한 설정
- 입력 변수 및 출력 상세 문서화
- 거버넌스 규칙 및 운영 가이드
- 제한사항 및 모니터링 가이드

### Governance
- 필수 태그 자동 적용
- 명명 규칙 검증 (kebab-case)
- 입력 검증 규칙:
  - Comment 길이 제한 (1-128자)
  - Environment 값 제한 (dev, staging, prod)
  - HTTP 버전 검증
  - Price Class 검증
  - Geo-restriction 타입 검증
  - ACM 인증서 사용 시 기본 인증서 비활성화 검증
