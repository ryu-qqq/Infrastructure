# Changelog

All notable changes to the ALB module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-23

### Added

#### ALB 기본 기능
- Application Load Balancer 생성 및 관리
- Internet-facing 및 Internal ALB 지원
- HTTP/2 프로토콜 지원
- 유휴 연결 타임아웃 설정 (1-4000초)
- IPv4 및 Dualstack IP 주소 타입 지원
- 삭제 방지 기능 (enable_deletion_protection)
- S3 버킷으로 액세스 로그 전송 기능

#### Target Group 관리
- 다중 Target Group 생성 및 관리
- Target Type 지원: IP, Instance, Lambda
- 등록 해제 지연 시간 설정 (deregistration_delay)
- 헬스체크 구성
  - 정상/비정상 판정 횟수 설정
  - 헬스체크 간격 및 타임아웃 설정
  - 커스텀 헬스체크 경로 및 HTTP 응답 코드 매처
  - HTTP/HTTPS 프로토콜 지원
- Session Stickiness (세션 고정)
  - Load Balancer Cookie 기반 세션 유지
  - 쿠키 유지 시간 설정 (기본: 24시간)

#### Listener 관리
- HTTP Listener 생성 및 관리
  - 기본 액션: Forward, Redirect, Fixed-response
  - HTTP to HTTPS 리다이렉션 지원
- HTTPS Listener 생성 및 관리
  - ACM 인증서 통합
  - 최신 TLS 1.3 SSL 정책 기본 적용 (ELBSecurityPolicy-TLS13-1-2-2021-06)
  - 기본 액션: Forward, Fixed-response

#### Listener Rule (경로 기반 라우팅)
- Path Pattern 기반 라우팅
- Host Header 기반 라우팅
- 우선순위 기반 규칙 처리 (1-50000)
- 다중 액션 지원
  - Forward: Target Group으로 트래픽 전달
  - Redirect: 다른 URL로 리다이렉션
  - Fixed-response: 고정 응답 반환

#### 태그 관리
- common-tags 모듈 통합
- 표준화된 태그 자동 적용 (Owner, CostCenter, Environment 등)
- 추가 커스텀 태그 지원

#### 검증 및 안정성
- 입력값 검증 (Validation)
  - ALB 이름: 영숫자 및 하이픈만 허용, 최대 32자
  - 서브넷: 최소 2개 이상 (고가용성)
  - VPC ID 형식 검증
  - Environment 값 검증 (dev, staging, prod)
  - 네이밍 컨벤션 검증 (kebab-case)
  - Idle timeout 범위 검증 (1-4000초)
- Lifecycle Precondition
  - Lambda Target Type의 HTTP 프로토콜 요구사항 검증
  - Health Check timeout < interval 검증
- Target Group 무중단 교체 (create_before_destroy)

#### Outputs
- ALB 정보: ARN, ARN Suffix, DNS Name, ID, Zone ID
- Target Group 정보: ARN, ARN Suffix, ID, Name (맵 형태)
- HTTP Listener 정보: ARN, ID (맵 형태)
- HTTPS Listener 정보: ARN, ID (맵 형태)
- Listener Rule 정보: ARN, ID (맵 형태)
- CloudWatch 메트릭 수집을 위한 ARN Suffix 제공

### Dependencies
- Terraform >= 1.0
- AWS Provider >= 4.0
- common-tags 모듈 (내부 의존성)
