# Infrastructure Repository

AWS 인프라를 관리하는 Terraform 기반 IaC(Infrastructure as Code) 저장소입니다.

## 📋 목차

- [개요](#개요)
- [프로젝트 구조](#프로젝트-구조)
- [정책 및 거버넌스](#정책-및-거버넌스)
- [시작하기](#시작하기)

---

## 개요

이 저장소는 AWS 클라우드 인프라를 코드로 관리하며, Terraform과 Atlantis를 통한 자동화된 배포 파이프라인을 제공합니다.

### 주요 특징

- ✅ **Infrastructure as Code**: Terraform으로 모든 인프라 관리
- ✅ **자동화된 거버넌스**: OPA 정책을 통한 자동 검증
- ✅ **PR 기반 워크플로우**: Atlantis를 통한 안전한 배포
- ✅ **재사용 가능한 모듈**: 표준화된 Terraform 모듈
- ✅ **보안 우선**: KMS 암호화, 최소 권한, 보안 스캔

---

## 프로젝트 구조

```
infrastructure/
├── terraform/              # Terraform 인프라 코드
│   ├── modules/           # 재사용 가능한 Terraform 모듈
│   ├── atlantis/          # Atlantis 서버 인프라
│   ├── kms/               # KMS 암호화 키
│   ├── network/           # VPC, 서브넷, 보안 그룹
│   └── rds/               # RDS 데이터베이스
├── policies/              # OPA 정책 (거버넌스)
├── scripts/               # 자동화 스크립트
├── docs/                  # 프로젝트 문서
└── .github/workflows/     # GitHub Actions CI/CD
```

---

## 정책 및 거버넌스

### 📂 policies/

Terraform 코드의 보안, 규정 준수, 네이밍 규약을 자동으로 검증하는 OPA(Open Policy Agent) 정책입니다.

**왜 필요한가?**
- 🛡️ 보안 취약점 사전 차단 (SSH/RDP 인터넷 노출 방지)
- 🏷️ 태그 표준 강제 (비용 추적, 리소스 관리)
- 📏 네이밍 일관성 유지 (kebab-case 강제)
- 🚫 위험한 설정 금지 (RDS public access, S3 공개 버킷)

**무엇을 검증하는가?**
- `tagging/` - 필수 태그 7개 검증
- `naming/` - 리소스 네이밍 규약 (kebab-case)
- `security_groups/` - 보안 그룹 규칙
- `public_resources/` - 공개 리소스 접근 제한

**자세한 내용**: [policies/README.md](./policies/README.md)

---

## 정책 검증 워크플로우

OPA 정책은 세 가지 레이어에서 자동 검증됩니다 (다층 방어 전략):

### 🔍 검증 레이어

| 레이어 | 시점 | 피드백 속도 | 설치/사용 |
|--------|------|------------|----------|
| **Pre-commit** | 커밋 전 | 1-2초 | `./scripts/setup-hooks.sh` |
| **Atlantis** | PR plan | 30초 | 자동 (서버에 설치됨) |
| **GitHub Actions** | PR 생성 | 1-2분 | 자동 (CI/CD 파이프라인) |

### 🚀 빠른 시작

```bash
# 1. Pre-commit hook 설치 (로컬 검증 활성화)
./scripts/setup-hooks.sh

# 2. Terraform 작업
cd terraform/your-module
terraform init
terraform plan

# 3. 커밋 시 자동 검증
git add .
git commit -m "Add resources"
# → Pre-commit hook이 자동으로 정책 검증

# 4. PR 생성
git push origin feature-branch
# → Atlantis와 GitHub Actions가 자동으로 정책 검증
```

### 📊 검증 결과 확인

- **로컬**: 커밋 시 터미널에 즉시 표시
- **Atlantis**: PR 코멘트에 plan 결과와 함께 표시
- **GitHub Actions**: PR 코멘트에 상세한 검증 리포트

**통합 가이드**: [OPA Policy Integration Guide](./docs/guides/opa-policy-integration-guide.md)

---

## 시작하기

### 필수 요구사항

- Terraform >= 1.5.0
- AWS CLI
- OPA (정책 검증용)
- Conftest (정책 테스트용)

### 설치

```bash
# Terraform
brew install terraform

# OPA
brew install opa

# Conftest
brew install conftest
```

### 기본 사용법

```bash
# 1. Terraform 초기화
cd terraform/your-module
terraform init

# 2. Plan 생성
terraform plan -out=tfplan.binary

# 3. 정책 검증 (선택사항)
terraform show -json tfplan.binary > tfplan.json
conftest test tfplan.json --config ../../conftest.toml

# 4. 적용
terraform apply
```

---

## 관련 문서

- [Terraform 모듈 개발 가이드](./docs/modules/README.md)
- [OPA 정책 가이드](./policies/README.md)
- [Atlantis 사용 가이드](./docs/guides/atlantis-setup-guide.md)
- [보안 가이드](./docs/guides/security-best-practices.md)

---

**Maintained By**: Platform Team
**Last Updated**: 2025-11-21
