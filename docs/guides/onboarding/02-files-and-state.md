# 파일 구성과 상태 관리

서비스 리포지토리에서 Terraform 파일 구성 모범 사례와 상태(State) 관리 방법을 설명합니다.

## 파일 네이밍 컨벤션
- 기본 파일: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `provider.tf`, `backend.tf`
- 선택 파일: `locals.tf`, `data.tf`
- 리소스별 분리(규모가 큰 경우): `ecs.tf`, `rds.tf`, `security-groups.tf`, `iam.tf`, `monitoring.tf`
- 변수 파일: `terraform.tfvars`, `prod.tfvars`, `staging.tfvars`, `dev.tfvars`, `secrets.auto.tfvars`
- 문서 파일: `README.md`, `ARCHITECTURE.md`, `RUNBOOK.md`

## 파일 구성 모범 사례
- 소규모(<10): 표준 파일에 단일 구성 유지
- 중간(10~50): 관련 리소스를 논리적으로 파일 분리
- 대규모(>50): 하위 디렉터리/여러 모듈로 분할 고려

## 상태(State) 관리
- 원격 상태 백엔드(S3 + DynamoDB) 사용 권장
- 핵심 가이드라인:
  - 조직 공용 S3 버킷, 격리된 `key` 패턴 사용
  - KMS 암호화, DynamoDB 락, S3 버저닝 활성화

자세한 코드 예시는 온보딩 원문 섹션을 참고하세요.
