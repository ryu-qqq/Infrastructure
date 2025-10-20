# 백엔드 구성 모범사례 및 트러블슈팅

Terraform 원격 상태(S3 + DynamoDB) 구성, 보안 권고, 자주 발생하는 문제와 해결 방법을 정리합니다.

## 개요
- 팀 협업과 안전한 인프라 운영을 위해 원격 상태 사용 필수
- S3 버저닝/암호화, DynamoDB 락, IAM 최소권한이 핵심

## 환경별 백엔드 구성 예시
- Dev/Staging/Prod 별 `backend.tf` 샘플 구조와 권장사항
- KMS 사용, 락 테이블 구성, 접근 제어 포인트

## 상태 파일 버저닝과 복구
- 버전 목록 조회 및 특정 버전 다운로드
- 수명주기(Lifecycle) 정책으로 비용/보호 균형 맞추기

## 보안 베스트 프랙티스
- 퍼블릭 접근 차단, KMS 암호화, S3 로깅, MFA Delete
- 서비스별 최소권한 IAM 정책 샘플 참조

## 트러블슈팅
- Backend 변경 감지 에러 → migrate/reconfigure 옵션 구분
- State Lock Timeout → 보류/강제 해제/예방 수칙
- Access Denied → IAM 권한 점검(버킷/락 테이블/KMS)

자세한 코드/명령 예시는 온보딩 원문 섹션을 참조하세요.
