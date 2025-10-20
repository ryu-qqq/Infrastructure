# 인프라 디렉터리 구조와 가이드라인

이 문서는 서비스 리포지토리의 인프라 디렉터리 구조와 각 디렉터리의 목적/가이드라인을 설명합니다. 본 내용은 기존 `SERVICE_REPO_ONBOARDING.md`의 관련 섹션을 분리한 것입니다.

## 인프라 디렉터리 구조 개요

서비스 리포지토리는 중앙 인프라 리포지토리의 구조와 컨벤션을 반영한 표준화된 `infra/` 디렉터리 아래에 인프라 코드를 구성해야 합니다. 이 구조는 다음과 같은 이점을 제공합니다:

- 명확한 분리: 애플리케이션 코드와 인프라 코드의 책임 분리
- 환경 격리: dev, staging, prod 간 안전한 배포를 위한 환경 분리
- 재사용성: 모듈화된 Terraform 구성으로 반복 사용 가능
- 발견 용이성: 일관된 네이밍과 조직화로 찾기 쉬움

### 표준 디렉터리 레이아웃

```text
service-repository/
├── infra/
│   ├── terraform/
│   │   ├── modules/
│   │   ├── environments/
│   │   └── shared/
│   ├── scripts/
│   └── docs/
├── src/
└── .github/workflows/
```

## 디렉터리 목적 및 가이드라인

### `infra/` - 인프라 루트
- 목적: 인프라 관련 코드와 문서를 담는 최상위 컨테이너
- 가이드라인: 관심사의 분리를 위해 애플리케이션 코드와 엄격히 분리 유지
- 소유권: 보통 서비스 팀과 플랫폼 팀이 협업하여 공동 관리

### `infra/terraform/modules/` - 서비스 전용 모듈
- 목적: 서비스에 특화된 재사용 가능한 Terraform 모듈 집합
- 네이밍: 케밥 케이스(예: `app-service`, `cache-layer`)
- 필수 파일: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`, `examples/`

### `infra/terraform/environments/` - 환경별 구성
- 목적: 환경(dev, staging, prod)별 인프라 배포 정의
- 파일 구성: `main.tf`, `variables.tf`, `terraform.tfvars`, `backend.tf`, `provider.tf`, `outputs.tf`, `README.md`

### `infra/terraform/shared/` - 공용 리소스(선택)
- 목적: 모든 환경에서 공통으로 사용하는 인프라(VPC, KMS, IAM 등)
- 가이드라인: 실제로 공용이 필요한 경우에만 생성, 대부분은 환경별 구성을 권장

참고: 보다 자세한 예시와 코드 블록은 기존 온보딩 문서 섹션을 확인하세요.
