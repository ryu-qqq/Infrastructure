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
├── governance/            # 🛡️ 거버넌스 시스템 (품질/보안 검증)
│   ├── configs/           # 검증 도구 설정 (conftest, checkov, tfsec, infracost)
│   ├── policies/          # OPA 정책 (Rego)
│   └── hooks/             # Git hooks 참조
├── scripts/               # 자동화 스크립트
├── docs/                  # 프로젝트 문서
├── .github/workflows/     # GitHub Actions CI/CD
├── policies/              # → governance/policies/ (심볼릭 링크)
├── conftest.toml          # → governance/configs/conftest.toml (심볼릭 링크)
├── .checkov.yml           # → governance/configs/checkov.yml (심볼릭 링크)
├── .tfsec/                # → governance/configs/tfsec/ (심볼릭 링크)
└── .infracost.yml         # → governance/configs/infracost.yml (심볼릭 링크)
```

---

## 거버넌스 시스템

### 🛡️ governance/

Terraform 인프라 코드의 품질, 보안, 컴플라이언스를 **4단계 레이어**에서 자동 검증하는 통합 거버넌스 시스템입니다.

**왜 필요한가?**
- 🛡️ 보안 취약점 사전 차단 (SSH/RDP 인터넷 노출, RDS public access)
- 🏷️ 필수 태그 강제 (비용 추적, 리소스 관리, 책임 소재)
- 📏 네이밍 일관성 유지 (kebab-case 강제)
- 🔐 KMS 암호화 강제 (AES256 사용 금지)
- 💰 비용 영향 분석 (30% 증가 시 자동 차단)
- 📋 컴플라이언스 준수 (CIS AWS, PCI-DSS, HIPAA)

**무엇을 검증하는가?**
- **OPA 정책** (policies/): 필수 태그, 네이밍, 보안 그룹, 공개 리소스
- **보안 스캔** (tfsec): AWS 보안 모범 사례
- **컴플라이언스** (Checkov): CIS AWS, PCI-DSS, HIPAA
- **비용 관리** (Infracost): 비용 추적 및 임계값

**자세한 내용**: [governance/README.md](./governance/README.md)

---

## 거버넌스 검증 워크플로우

거버넌스 정책은 **4단계 레이어**에서 자동 검증됩니다 (다층 방어 전략):

### 🔍 검증 레이어

| 레이어 | 시점 | 피드백 속도 | 검증 항목 | 우회 가능 |
|--------|------|------------|----------|----------|
| **Pre-commit** | 커밋 전 | 1-2초 | fmt, secrets, validate, OPA | Yes (--no-verify) |
| **Pre-push** | 푸시 전 | 30초 | tags, encryption, naming | Yes (--no-verify) |
| **Atlantis** | PR plan | 30초-1분 | OPA 정책 | No |
| **GitHub Actions** | PR 생성 | 1-2분 | OPA, tfsec, Checkov, Infracost | No |

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

### 거버넌스
- [거버넌스 시스템 가이드](./governance/README.md) - **시작점**
- [OPA 정책 통합 가이드](./docs/guides/opa-policy-integration-guide.md)
- [Checkov 정책 가이드](./docs/governance/CHECKOV_POLICY_GUIDE.md)

### 개발
- [Terraform 모듈 개발 가이드](./docs/modules/README.md)
- [Atlantis 사용 가이드](./docs/guides/atlantis-setup-guide.md)
- [Scripts 디렉토리](./scripts/README.md)

---

**Maintained By**: Platform Team
**Last Updated**: 2025-11-21
