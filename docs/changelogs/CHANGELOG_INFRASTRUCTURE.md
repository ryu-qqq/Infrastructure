# 인프라스트럭처 리포지토리 변경 로그

이 인프라스트럭처 리포지토리의 모든 주요 변경 사항은 이 파일에 기록됩니다.

형식은 [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)를 기반으로 하며,
본 프로젝트는 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 준수합니다.

---

## [Unreleased]

### 추가됨
- **문서화**: 모듈 표준 및 가이드 정리 (IN-121)
  - `docs/MODULES_DIRECTORY_STRUCTURE.md` - 모듈 디렉터리 구조 가이드
  - `docs/MODULE_STANDARDS_GUIDE.md` - 코딩 표준 및 컨벤션
  - `docs/MODULE_EXAMPLES_GUIDE.md` - 예시 구조 가이드
  - `docs/MODULE_TEMPLATE.md` - 모듈 README 템플릿
  - `docs/VERSIONING.md` - 시맨틱 버저닝 가이드
  - `docs/CHANGELOG_TEMPLATE.md` - 변경 로그 포맷 템플릿
  - `docs/PROJECT_OVERVIEW_KR.md` - 프로젝트 개요 (한글)
  - `docs/TERRAFORM_MODULES_KR.md` - Terraform 모듈 가이드 (한글)
  - `docs/SCRIPTS_GUIDE_KR.md` - 스크립트 사용 가이드 (한글)

- **모듈 카탈로그**: 모듈 목록 및 빠른 시작 포함 `terraform/modules/README.md`

- **보관 문서**: 보관 디렉터리용 README 추가
  - `terraform/archived/README.md` - 보관 정책 및 안내
  - `terraform/archived/atlantis-iam/README.md` - 보관된 IAM 구성
  - `terraform/archived/bootstrap/README.md` - 보관된 부트스트랩 구성

### 변경됨
- **디렉터리 구조**: 비활성 구성을 `terraform/archived/`로 이동
  - `terraform/atlantis-iam/` → `terraform/archived/atlantis-iam/`
  - `terraform/bootstrap/` → `terraform/archived/bootstrap/`

- **Terraform 네이밍**: `terraform/monitoring/amg.tf`의 IAM Role 리소스 네이밍 수정
  - `aws_iam_role.grafana-workspace` → `aws_iam_role.grafana_workspace`
  - Terraform snake_case 컨벤션 준수

- **README.md**: 모듈 문서 섹션 확충
  - 모듈 카탈로그 참조 추가
  - 한글 문서 링크 추가
  - 모듈 빠른 시작 예제 추가

### 제거됨
- **cleanup-kms.sh** (48 lines)
  - **이유**: 안전성을 위해 AWS 콘솔을 통한 수동 운영 선호
  - **마이그레이션**: `aws kms list-keys --region ap-northeast-2` 및 AWS 콘솔 사용
  - **영향**: 핵심 워크플로우에 포함되지 않은 선택적 유틸리티 스크립트
  - **대안**:
    ```bash
    # KMS 키 목록 조회
    aws kms list-keys --region ap-northeast-2

    # 특정 키 상세 조회
    aws kms describe-key --key-id <key-id>

    # 삭제 예약 (안전을 위해 콘솔 사용 권장)
    # 이동: https://console.aws.amazon.com/kms
    ```

- **setup-github-actions-role.sh** (51 lines)
  - **이유**: 선언적 IaC(Terraform) 선호, 명령형 스크립트 지양
  - **마이그레이션**: IAM Role 관리는 Terraform으로 전환
  - **영향**: 초기 설정용 스크립트였으며 현재는 선언형 접근으로 대체
  - **대안**:
    - [GitHub Actions 설정 가이드](./github_actions_setup.md) 참고
    - `terraform/atlantis/` 또는 보관 구성 참조
    - Terraform을 통한 AWS OIDC Provider 설정

- **update-iam-policy.sh** (18 lines)
  - **이유**: CI/CD 자동화가 수동 정책 업데이트를 대체
  - **마이그레이션**: IAM 정책은 GitHub Actions 워크플로우에서 관리
  - **영향**: 수동 업데이트 불필요
  - **대안**:
    - `.github/workflows/terraform-apply-and-deploy.yml`에 의해 정책 자동 업데이트
    - 수동 필요 시: AWS 콘솔 또는 `aws iam` CLI 사용
    - Terraform 관리 정책의 경우: .tf 파일 수정 후 apply

### 삭제된 스크립트 마이그레이션 가이드

#### 기존에 해당 스크립트를 사용하던 팀을 위한 안내

1. **KMS 키 관리** (`cleanup-kms.sh` 대체)
   - **권장**: 삭제 전 시각적 확인을 위해 AWS KMS 콘솔 사용
   - **콘솔**: https://console.aws.amazon.com/kms
   - **CLI 대안**:
     ```bash
     # 모든 KMS 키 조회
     aws kms list-keys --region ap-northeast-2

     # 키 상세 정보 조회
     aws kms describe-key --key-id alias/your-key-name

     # 키 Grant 목록 조회
     aws kms list-grants --key-id <key-id>

     # 삭제 예약 (대기 기간 30일)
     aws kms schedule-key-deletion \
       --key-id <key-id> \
       --pending-window-in-days 30
     ```

2. **GitHub Actions IAM 설정** (`setup-github-actions-role.sh` 대체)
   - **권장**: 재현 가능한 인프라를 위해 Terraform 사용
   - **문서**: [docs/github_actions_setup.md](./github_actions_setup.md)
   - **Terraform 예시**:
     ```hcl
     # GitHub Actions용 OIDC Provider 생성
     resource "aws_iam_openid_connect_provider" "github" {
       url = "https://token.actions.githubusercontent.com"
       client_id_list   = ["sts.amazonaws.com"]
       thumbprint_list  = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
     }

     # GitHub Actions용 IAM Role 생성
     resource "aws_iam_role" "github_actions" {
       name = "GitHubActionsRole"
       # ... (전체 예시는 보관 구성 참조)
     }
     ```

3. **IAM 정책 업데이트** (`update-iam-policy.sh` 대체)
   - **자동화**: GitHub Actions 워크플로우에서 정책 업데이트 처리
   - **수동 업데이트(필요 시)**:
     ```bash
     # 인라인 정책 업데이트
     aws iam put-role-policy \
       --role-name YourRoleName \
       --policy-name YourPolicyName \
       --policy-document file://policy.json

     # 관리형 정책 연결
     aws iam attach-role-policy \
       --role-name YourRoleName \
       --policy-arn arn:aws:iam::aws:policy/YourPolicy
     ```

### 하위 호환성에 영향이 있는 변경 사항

**없음** - 제거된 스크립트는 선택적 유틸리티로, 핵심 인프라 운영에 필수적이지 않았습니다.

기존 워크플로우는 계속 정상 동작합니다:
- ✅ Terraform apply/destroy 워크플로우 변화 없음
- ✅ GitHub Actions CI/CD 변화 없음
- ✅ 인프라 거버넌스 변화 없음

---

## [이전 릴리스]

### 초기 프로젝트 구성
- Atlantis용 ECR 리포지토리
- KMS 암호화 설정
- GitHub Actions 워크플로우
- 거버넌스 검증 스크립트
- 공통 태그 모듈
- CloudWatch 로그 그룹 모듈

---

## 마이그레이션 타임라인

| 날짜 | 변경 | 상태 |
|------|------|------|
| 2025-10-14 | 유틸리티 스크립트 제거 | ✅ 완료 |
| 2025-10-14 | 비활성 구성 보관 | ✅ 완료 |
| 2025-10-14 | 모듈 문서 추가 | ✅ 완료 |
| 2025-10-14 | Terraform 네이밍 수정 | ✅ 완료 |

---

**참고**: 모듈별 상세 변경 내역은 `terraform/modules/{module-name}/`의 각 모듈 `CHANGELOG.md`를 확인하세요.
