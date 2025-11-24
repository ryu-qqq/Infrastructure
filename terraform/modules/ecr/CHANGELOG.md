# Changelog

이 파일은 ECR 모듈의 모든 주요 변경 사항을 기록합니다.

형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 따르며,
이 프로젝트는 [Semantic Versioning](https://semver.org/lang/ko/)을 준수합니다.

## [1.0.0] - 2025-11-23

### 추가
- AWS ECR 리포지토리 생성 기능
- KMS 암호화 지원 (고객 관리형 키 필수)
- 푸시 시 자동 이미지 스캔 기능
- 라이프사이클 정책을 통한 자동 이미지 정리
  - 태그된 이미지: 최대 개수 기반 정리
  - 태그 없는 이미지: 일수 기반 정리
- 리포지토리 정책 지원
  - 기본 동일 계정 접근 정책
  - 사용자 정의 정책 옵션
- common-tags 모듈과 통합된 표준 태그 관리
- SSM 파라미터를 통한 크로스 스택 참조 기능
- 입력 변수 유효성 검사
  - 리포지토리 이름 형식 검증
  - KMS ARN 형식 검증
  - 환경 값 검증 (dev, staging, prod)
  - kebab-case 네이밍 규칙 검증
  - 이메일 형식 검증

### 기능
- 이미지 태그 변경 가능 여부 설정 (MUTABLE/IMMUTABLE)
- 라이프사이클 정책 활성화/비활성화
- 태그 접두사 기반 라이프사이클 정책
- 리포지토리 URL, ARN, 이름 출력
- 레지스트리 ID 출력
- SSM 파라미터 ARN 출력

### 보안
- KMS 암호화 필수 적용
- 푸시 시 이미지 스캔 기본 활성화
- 최소 권한 원칙 기반 기본 리포지토리 정책

### 운영
- 자동 이미지 정리로 스토리지 비용 최적화
- 태그 기반 이미지 보존 정책
- 환경별 설정 분리 지원

### 거버넌스
- 필수 태그 자동 적용 (Owner, CostCenter, Environment, Lifecycle, DataClass, Service)
- kebab-case 네이밍 규칙 준수
- KMS 암호화 표준 준수

### 문서
- 한국어 README.md 작성
- 사용 예시 및 코드 샘플 제공
- 입력/출력 변수 상세 문서화
- 운영 가이드 및 문제 해결 가이드
- 보안 고려사항 문서화
- 비용 최적화 가이드

[1.0.0]: https://github.com/yourorg/infrastructure/releases/tag/ecr-v1.0.0
