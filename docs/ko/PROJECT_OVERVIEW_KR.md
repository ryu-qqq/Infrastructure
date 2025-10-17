# Infrastructure 프로젝트 개요

## 📋 프로젝트 소개

이 저장소는 Terraform을 이용한 Infrastructure as Code(IaC) 관리 프로젝트입니다. AWS 클라우드 인프라를 코드로 정의하고, GitHub Actions를 통한 자동화된 배포 파이프라인을 구축하여 안전하고 일관된 인프라 관리를 제공합니다.

## 🎯 프로젝트 목표

1. **코드형 인프라 관리**: 모든 인프라를 Terraform 코드로 관리하여 버전 관리 및 재현 가능성 확보
2. **자동화된 배포**: GitHub Actions를 통한 CI/CD 파이프라인 구축
3. **거버넌스 준수**: 조직의 보안, 규정 준수, 비용 관리 정책 자동 적용
4. **재사용 가능한 모듈**: 표준화된 Terraform 모듈을 통한 인프라 구성 요소 재사용

## 📁 프로젝트 구조

### 핵심 디렉토리

```
infrastructure/
├── terraform/              # Terraform 인프라 코드
│   ├── atlantis/          # Atlantis 서버 인프라 (ECR, KMS)
│   ├── monitoring/        # 모니터링 인프라 (Grafana, AMP, CloudWatch)
│   └── modules/           # 재사용 가능한 Terraform 모듈
│
├── docs/                  # 프로젝트 문서 (표준, 가이드, 정책)
├── claudedocs/           # 아키텍처 및 분석 문서
├── scripts/              # 자동화 스크립트 및 유틸리티
├── policies/             # OPA 정책 파일 (거버넌스 검증)
├── docker/               # Docker 이미지 구성
└── .github/workflows/    # GitHub Actions CI/CD 워크플로우
```

### 주요 디렉토리별 역할

#### 1. `terraform/` - Terraform 인프라 코드
AWS 리소스를 정의하고 관리하는 Terraform 코드가 위치합니다.

**주요 구성 요소:**
- **atlantis/**: Atlantis 서버 배포를 위한 ECR 저장소, KMS 키, IAM 역할
- **monitoring/**: Grafana 워크스페이스, Amazon Managed Prometheus, CloudWatch 대시보드
- **modules/**: 재사용 가능한 표준 모듈 (common-tags, cloudwatch-log-group 등)

**특징:**
- 각 디렉토리는 독립적인 Terraform 프로젝트
- State 파일은 로컬 또는 S3 backend로 관리
- 모듈은 semantic versioning으로 버전 관리

#### 2. `docs/` - 표준 및 가이드 문서
프로젝트 전반에 걸친 표준, 가이드, 정책 문서가 위치합니다.

**주요 문서:**
- **인프라 거버넌스**: 태깅 표준, 네이밍 규칙, KMS 전략
- **모듈 표준**: 디렉토리 구조, 코딩 표준, 버전 관리
- **워크플로우 가이드**: GitHub Actions 설정, PR 프로세스
- **한글 문서**: 프로젝트 개요, 모듈 가이드, 스크립트 가이드

**문서 종류:**
- `*_STANDARDS.md`: 조직 전체 표준 정의
- `*_GUIDE.md`: 실무 가이드 및 사용법
- `*_TEMPLATE.md`: 문서 작성 템플릿
- `*_KR.md`: 한글 설명 문서

#### 3. `claudedocs/` - 아키텍처 및 분석 문서
시스템 아키텍처, 기술 분석, 의사결정 기록이 위치합니다.

**주요 문서:**
- **아키텍처 문서**: 시스템 설계, 컴포넌트 관계도
- **기술 분석**: 기술 선택 이유, 비교 분석
- **의사결정 기록**: ADR (Architecture Decision Records)
- **조사 및 연구**: 기술 스택 조사, PoC 결과

**특징:**
- AI 어시스턴트(Claude)가 생성한 분석 자료
- 시스템의 큰 그림 이해를 위한 문서
- 의사결정 맥락 및 근거 기록

#### 4. `scripts/` - 자동화 스크립트
개발, 검증, 배포를 위한 자동화 스크립트가 위치합니다.

**디렉토리 구조:**
```
scripts/
├── validators/           # 거버넌스 검증 스크립트
│   ├── check-tags.sh           # 필수 태그 검증
│   ├── check-encryption.sh     # KMS 암호화 검증
│   ├── check-naming.sh         # 네이밍 규칙 검증
│   └── validate-terraform-file.sh  # 단일 파일 검증 (Claude hooks용)
│
├── hooks/                # Git hooks 템플릿
│   ├── pre-commit              # 커밋 전 검증
│   └── pre-push                # 푸시 전 검증
│
├── build-and-push.sh     # ECR 이미지 빌드/푸시
└── setup-hooks.sh        # Git hooks 설치
```

**주요 스크립트:**
- **검증 스크립트**: Terraform 코드의 거버넌스 준수 검증
- **빌드 스크립트**: Docker 이미지 빌드 및 ECR 푸시 자동화
- **설정 스크립트**: 개발 환경 초기 설정

#### 5. `policies/` - OPA 정책 파일
Open Policy Agent를 사용한 Terraform plan 검증 정책이 위치합니다.

**정책 종류:**
- **태깅 정책**: 필수 태그 존재 여부 및 형식 검증
- **네이밍 정책**: 리소스 이름의 kebab-case 준수 검증
- **보안 정책**: 암호화, 접근 제어 등 보안 규칙 검증

**사용 방법:**
```bash
# Terraform plan을 JSON으로 변환
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# OPA로 정책 검증
opa eval --data policies/ --input tfplan.json "data.terraform.deny"
```

#### 6. `docker/` - Docker 이미지 구성
프로젝트에서 사용하는 커스텀 Docker 이미지의 Dockerfile이 위치합니다.

**현재 이미지:**
- **Atlantis**: Terraform PR 자동화 도구 (기본 이미지 + AWS CLI 등 추가 도구)

#### 7. `.github/workflows/` - GitHub Actions 워크플로우
CI/CD 파이프라인 정의가 위치합니다.

**주요 워크플로우:**
- **terraform-plan.yml**: PR 생성 시 Terraform plan 실행 및 코멘트
- **terraform-apply-and-deploy.yml**: main 병합 시 Terraform apply 및 Docker 이미지 배포

## 🔄 개발 워크플로우

### 1. 개발 환경 설정
```bash
# Git hooks 설치 (거버넌스 검증 자동화)
./scripts/setup-hooks.sh

# Terraform 초기화
cd terraform/atlantis
terraform init
```

### 2. 기능 개발
```bash
# Feature 브랜치 생성
git checkout -b feature/your-feature

# Terraform 코드 작성 및 테스트
terraform fmt
terraform validate
terraform plan

# 변경사항 커밋 (pre-commit hook이 자동 검증)
git add .
git commit -m "feat: your feature description"
```

### 3. Pull Request
```bash
# 푸시 (pre-push hook이 자동 검증)
git push origin feature/your-feature

# GitHub에서 PR 생성
# → terraform-plan.yml 워크플로우 자동 실행
# → Terraform plan 결과가 PR 코멘트로 자동 추가
```

### 4. 배포
```bash
# PR 승인 및 main 브랜치 병합
# → terraform-apply-and-deploy.yml 워크플로우 자동 실행
# → Terraform apply 실행
# → Docker 이미지 빌드 및 ECR 푸시
```

## 🛡️ 거버넌스 및 보안

### 검증 계층

1. **개발 시점**: Git hooks (pre-commit, pre-push)
2. **PR 시점**: GitHub Actions (terraform-plan.yml)
3. **배포 시점**: OPA 정책 검증

### 필수 준수 사항

#### 1. 태깅 표준
모든 AWS 리소스는 다음 태그를 반드시 포함해야 합니다:
- `Environment`: dev, staging, prod
- `Service`: 서비스 이름
- `Team`: 담당 팀
- `Owner`: 소유자 이메일
- `CostCenter`: 비용 센터
- `ManagedBy`: terraform, manual, cloudformation
- `Project`: 프로젝트 이름

#### 2. 네이밍 규칙
- **리소스 이름**: kebab-case (예: `prod-api-server-vpc`)
- **변수/출력**: snake_case (예: `vpc_id`, `subnet_ids`)
- **모듈 디렉토리**: kebab-case (예: `cloudwatch-log-group`)

#### 3. 암호화 표준
- KMS 암호화 필수 (AES256 사용 금지)
- 데이터 분류(DataClass)에 따른 KMS 키 분리
- 자동 키 로테이션 활성화

## 📊 모니터링 및 관찰성

### 현재 구성된 모니터링

#### 1. Grafana Workspace
- Prometheus 데이터 소스 연동
- 대시보드를 통한 메트릭 시각화
- SSO 인증 연동

#### 2. Amazon Managed Prometheus (AMP)
- 컨테이너 메트릭 수집 및 저장
- Prometheus 쿼리 언어(PromQL) 지원
- 장기 메트릭 보관

#### 3. CloudWatch
- 로그 수집 및 분석
- 알람 설정 및 알림
- 대시보드를 통한 시스템 모니터링

## 📚 주요 문서

### 시작하기
- [README.md](../README.md) - 프로젝트 전체 개요 및 빠른 시작
- [GitHub Actions Setup Guide](./github_actions_setup.md) - CI/CD 설정 가이드
- [Infrastructure PR Workflow](./infrastructure_pr.md) - PR 프로세스

### 표준 및 정책
- [Infrastructure Governance](../governance/infrastructure_governance.md) - 거버넌스 정책
- [Tagging Standards](../governance/TAGGING_STANDARDS.md) - 태깅 표준
- [Naming Convention](./NAMING_CONVENTION.md) - 네이밍 규칙

### 모듈 개발
- [Modules Directory Structure](./MODULES_DIRECTORY_STRUCTURE.md) - 모듈 구조
- [Module Standards Guide](./MODULE_STANDARDS_GUIDE.md) - 코딩 표준
- [Module Examples Guide](./MODULE_EXAMPLES_GUIDE.md) - 예제 작성 가이드
- [Versioning Guide](./VERSIONING.md) - 버전 관리
- [Terraform Modules Guide (한글)](./TERRAFORM_MODULES_KR.md) - 모듈 사용 가이드

### 운영 가이드
- [Scripts Guide (한글)](./SCRIPTS_GUIDE_KR.md) - 스크립트 사용 가이드

## 🔗 관련 Jira 이슈

### Epic
- [IN-1 - Phase 1: Atlantis 서버 ECS 배포](https://ryuqqq.atlassian.net/browse/IN-1)
- [IN-100 - EPIC 4: 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)

### Task
- [IN-10 - ECR 저장소 생성 및 Docker 이미지 푸시](https://ryuqqq.atlassian.net/browse/IN-10)
- [IN-121 - 모듈 디렉터리 구조 설계](https://ryuqqq.atlassian.net/browse/IN-121)

## 🤝 기여하기

### 코드 기여 절차

1. **이슈 확인**: Jira에서 작업할 이슈 확인
2. **브랜치 생성**: `feature/IN-XXX-description` 형식으로 브랜치 생성
3. **코드 작성**: 표준 및 가이드 준수
4. **테스트**: Terraform plan으로 변경사항 확인
5. **커밋**: 의미 있는 커밋 메시지 작성
6. **PR 생성**: 변경사항 설명 및 관련 이슈 링크
7. **리뷰**: 팀원 리뷰 및 피드백 반영
8. **병합**: 승인 후 main 브랜치로 병합

### 커밋 메시지 규칙

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type:**
- `feat`: 새로운 기능
- `fix`: 버그 수정
- `docs`: 문서 변경
- `style`: 코드 스타일 변경 (포맷팅)
- `refactor`: 리팩토링
- `test`: 테스트 추가/수정
- `chore`: 빌드/설정 변경

**예시:**
```
feat(monitoring): Add Grafana workspace with AMP integration

- Create Grafana workspace in ap-northeast-2
- Configure Prometheus data source
- Add required IAM roles and policies
- Enable CloudWatch logging

Closes IN-150
```

## 🆘 문제 해결

### 일반적인 문제

#### 1. Terraform State Lock
```bash
# DynamoDB 테이블에서 lock 확인
aws dynamodb scan --table-name terraform-lock

# 수동으로 lock 해제 (주의!)
terraform force-unlock <lock-id>
```

#### 2. 거버넌스 검증 실패
```bash
# 수동으로 검증 실행
./scripts/validators/check-tags.sh
./scripts/validators/check-encryption.sh
./scripts/validators/check-naming.sh

# 긴급 시 우회 (권장하지 않음)
git commit --no-verify
git push --no-verify
```

#### 3. Docker 빌드 실패
```bash
# Docker 캐시 정리
docker system prune -a

# 캐시 없이 재빌드
docker build --no-cache -t atlantis:v0.28.1 .
```

## 📞 연락처

- **팀**: Infrastructure Team
- **문서**: [docs/](../docs/) 디렉토리 참조
- **이슈**: [Jira - Infrastructure Project](https://ryuqqq.atlassian.net/)
