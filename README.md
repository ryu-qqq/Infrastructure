# Infrastructure Repository

**Ryuqqq Infrastructure as Code (IaC)** - AWS 인프라 관리를 위한 Terraform 기반 레포지토리

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions)](https://github.com/features/actions)

---

## 📖 개요

이 레포지토리는 Ryuqqq 서비스의 AWS 인프라를 Terraform으로 관리합니다. 중앙 집중식 공유 리소스와 서비스별 분산 인프라를 결합한 **하이브리드 아키텍처**를 채택하고 있습니다.

### 주요 특징

- **🏗️ 하이브리드 인프라**: 중앙 관리 (VPC, KMS, RDS) + 서비스별 분산 관리 (ECS, ALB, Redis)
- **🔒 보안 강화**: 필수 태그, KMS 암호화, Security Group 규칙 자동 검증
- **📊 거버넌스 자동화**: tfsec, checkov, OPA 정책을 통한 보안/컴플라이언스 검증
- **🤖 CI/CD 통합**: GitHub Actions + Atlantis를 통한 자동화된 배포 파이프라인
- **💰 비용 최적화**: Infracost 통합으로 인프라 비용 자동 추적
- **📈 중앙 모니터링**: CloudWatch, Prometheus (AMP), Grafana (AMG)

---

## 🚀 빠른 시작

### 1. 사전 요구사항

```bash
# 필수 도구 설치
terraform >= 1.5.0
aws-cli >= 2.0
docker >= 20.10
```

### 2. AWS 자격증명 설정

```bash
aws configure
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region: ap-northeast-2
```

### 3. 첫 배포

```bash
# 레포지토리 클론
git clone https://github.com/ryuqqq/infrastructure.git
cd infrastructure

# 네트워크 인프라 배포
cd terraform/network
terraform init
terraform plan
terraform apply

# KMS 키 배포
cd ../kms
terraform init
terraform apply
```

**📚 자세한 가이드**: [하이브리드 인프라 가이드](docs/guides/hybrid-infrastructure-guide.md) 참조

---

## 🔗 GitHub App 설치 및 Atlantis 연동

Atlantis를 배포한 후, **PR 기반 Terraform 자동화**를 사용하려면 GitHub App을 생성하고 설치해야 합니다.

### 1. Atlantis 서버 배포

먼저 Atlantis 인프라를 배포합니다:

```bash
cd terraform/atlantis
terraform init
terraform plan
terraform apply
```

배포 완료 후 ALB DNS Name을 확인합니다:

```bash
terraform output alb_dns_name
# 예시: atlantis-prod-123456789.ap-northeast-2.elb.amazonaws.com
```

### 2. GitHub App 생성

**⚠️ 중요**: 각 사용자는 자신의 Organization/계정에 맞는 GitHub App을 새로 생성해야 합니다.

1. **GitHub Settings 접속**
   - Organization 사용 시: `https://github.com/organizations/{your-org}/settings/apps`
   - 개인 계정: `https://github.com/settings/apps`

2. **"New GitHub App" 클릭**

3. **기본 정보 입력**
   ```
   App name: Atlantis (또는 원하는 이름)
   Homepage URL: https://{your-atlantis-domain}
   Webhook URL: https://{your-atlantis-domain}/events
   Webhook secret: (생성한 Secret 값 입력, Secrets Manager에서 확인)
   ```

4. **Repository permissions 설정**
   - **Contents**: Read & Write
   - **Pull requests**: Read & Write
   - **Issues**: Write
   - **Webhooks**: Read & Write

5. **Subscribe to events 선택**
   - ✅ Pull request
   - ✅ Pull request review
   - ✅ Pull request review comment
   - ✅ Push
   - ✅ Issue comment

6. **"Create GitHub App" 클릭**

### 3. GitHub App 설치

GitHub App 생성 후 설치:

1. App 설정 페이지에서 **"Install App"** 클릭
2. Organization 또는 개인 계정 선택
3. **Repository access** 선택:
   - "All repositories" 또는
   - "Only select repositories" (infrastructure, 서비스 레포지토리 선택)
4. **"Install"** 클릭

### 4. Secrets Manager 업데이트

GitHub App 생성 후 다음 정보를 Secrets Manager에 저장:

```bash
# App ID 확인 (GitHub App 설정 페이지에서)
APP_ID="your-app-id"

# Installation ID 확인
# https://github.com/settings/installations → 설치한 App 클릭 → URL에서 확인
# 예: github.com/settings/installations/12345678
INSTALLATION_ID="your-installation-id"

# Private Key 생성
# GitHub App 설정 → "Generate a private key" → .pem 파일 다운로드

# Secrets Manager 업데이트
aws secretsmanager put-secret-value \
  --secret-id atlantis/github-app-v2-prod \
  --secret-string '{
    "app_id": "'$APP_ID'",
    "installation_id": "'$INSTALLATION_ID'",
    "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
  }' \
  --region ap-northeast-2
```

### 5. Atlantis 재시작

Secrets 업데이트 후 Atlantis 서비스 재시작:

```bash
aws ecs update-service \
  --cluster atlantis-prod \
  --service atlantis-prod \
  --force-new-deployment \
  --region ap-northeast-2
```

### 6. 동작 확인

테스트 PR 생성 후 확인:

1. Infrastructure 레포지토리에서 테스트 브랜치 생성
2. 사소한 변경 후 PR 생성
3. PR에 코멘트 작성: `atlantis plan`
4. Atlantis가 자동으로 `terraform plan` 실행하고 결과를 PR 코멘트로 남기는지 확인

**📖 자세한 내용**: [Atlantis 운영 가이드](docs/guides/atlantis-operations-guide.md)

---

## 📂 프로젝트 구조

```
infrastructure/
├── .github/
│   └── workflows/          # CI/CD 파이프라인 (6개 GitHub Actions)
├── terraform/
│   ├── network/            # VPC, Subnets, Transit Gateway (중앙 관리)
│   ├── kms/                # KMS Keys (9개 암호화 키, 중앙 관리)
│   ├── rds/                # Shared RDS (공유 데이터베이스)
│   ├── ecr/                # ECR Repositories (서비스별)
│   ├── acm/                # ACM 인증서 관리
│   ├── route53/            # Route53 DNS 관리
│   ├── logging/            # 중앙 로깅 시스템 (S3, CloudWatch)
│   ├── secrets/            # Secrets Manager 및 자동 로테이션
│   ├── shared/             # 공유 리소스 통합 (KMS, Security, Network)
│   ├── modules/            # 재사용 가능한 Terraform 모듈 (15개)
│   ├── atlantis/           # Atlantis 서버 (Terraform 자동화)
│   ├── monitoring/         # 중앙 모니터링 (CloudWatch, AMP, AMG)
│   ├── cloudtrail/         # 감사 로그
│   └── bootstrap/          # 초기 인프라 부트스트랩
├── scripts/
│   ├── validators/         # Terraform 검증 스크립트 (10개)
│   ├── atlantis/           # Atlantis 운영 및 자동화 (8개)
│   ├── hooks/              # Git hooks 설정
│   └── policy/             # OPA 정책 헬퍼
├── docs/
│   ├── guides/             # 운영 가이드 (16개)
│   ├── governance/         # 거버넌스 정책 (10개)
│   ├── modules/            # 모듈 개발 가이드 (6개)
│   ├── runbooks/           # 인시던트 대응 런북 (3개)
│   ├── workflows/          # 워크플로 문서
│   ├── claude-commands/    # Claude Code 커맨드 (3개)
│   ├── ko/                 # 한글 문서
│   └── changelogs/         # 변경 이력
└── policies/               # OPA 정책 (8개 파일, 4개 정책)
    ├── tagging/            # 태깅 정책
    ├── naming/             # 네이밍 정책
    ├── security_groups/    # 보안 그룹 정책
    └── public_resources/   # 공개 리소스 정책
```

---

## 📘 핵심 문서

### 🏛️ 거버넌스
- [Infrastructure Governance](docs/governance/infrastructure_governance.md) - 필수 태그, KMS 전략, 네이밍 규칙
- [Tagging Standards](docs/governance/TAGGING_STANDARDS.md) - AWS 리소스 태깅 요구사항
- [Naming Convention](docs/governance/NAMING_CONVENTION.md) - 리소스 네이밍 규칙 (kebab-case)
- [Logging Naming Convention](docs/governance/LOGGING_NAMING_CONVENTION.md) - CloudWatch 로그 네이밍 표준
- [Checkov Policy Guide](docs/governance/CHECKOV_POLICY_GUIDE.md) - Checkov 정책 가이드
- [Security Scan Report Template](docs/governance/SECURITY_SCAN_REPORT_TEMPLATE.md) - 보안 스캔 보고서 템플릿
- [Secrets Rotation Guide](docs/governance/README_SECRETS_ROTATION.md) - Secrets 자동 로테이션 가이드
- [Secrets Rotation Checklist](docs/governance/SECRETS_ROTATION_CHECKLIST.md) - Secrets 로테이션 체크리스트
- [Secrets Rotation Status](docs/governance/SECRETS_ROTATION_CURRENT_STATUS.md) - 현재 로테이션 상태
- [Infrastructure PR Guide](docs/governance/infrastructure_pr.md) - PR 생성 및 리뷰 가이드

### 🏗️ 하이브리드 인프라 가이드 (⭐ 필수)
중앙 집중식 + 분산 관리 하이브리드 구조 완벽 가이드:

1. [개요 및 시작하기](docs/guides/hybrid-01-overview.md) - 하이브리드 구조 소개, 빠른 시작
2. [아키텍처 설계](docs/guides/hybrid-02-architecture-design.md) - Producer-Consumer 패턴, SSM Parameter Store
3. [Infrastructure 프로젝트 설정](docs/guides/hybrid-03-infrastructure-setup.md) - VPC, KMS, Shared RDS 설정
4. [Application 프로젝트 설정](docs/guides/hybrid-04-application-setup.md) - 서비스별 인프라 구축
5. [배포 가이드](docs/guides/hybrid-05-deployment-guide.md) - CI/CD, GitHub Actions, Atlantis
6. [모니터링 가이드](docs/guides/hybrid-06-monitoring-guide.md) - CloudWatch, X-Ray, Alarms
7. [운영 가이드](docs/guides/hybrid-07-operations-guide.md) - 비용 최적화, Rollback, DR
8. [트러블슈팅 가이드](docs/guides/hybrid-08-troubleshooting-guide.md) - 문제 해결, FAQ

**📖 메인 가이드**: [하이브리드 인프라 가이드](docs/guides/hybrid-infrastructure-guide.md)

### 🧩 모듈 개발
- [Module Standards Guide](docs/modules/MODULE_STANDARDS_GUIDE.md) - 모듈 개발 표준
- [Module Template](docs/modules/MODULE_TEMPLATE.md) - 모듈 문서 템플릿
- [Directory Structure](docs/modules/MODULES_DIRECTORY_STRUCTURE.md) - 모듈 디렉토리 구조

### 🚨 운영 가이드
- [Atlantis Operations](docs/guides/atlantis-operations-guide.md) - Atlantis 서버 운영
- [CloudTrail Operations](docs/guides/cloudtrail-operations-guide.md) - 감사 로그 관리
- [Runbooks](docs/runbooks/) - 인시던트 대응 절차 (ECS High CPU, Memory Critical 등)

---

## 🛠️ 사용 가능한 Terraform 모듈

### 핵심 모듈 (17개)

| 모듈 | 설명 | 버전 |
|------|------|------|
| `alb` | Application Load Balancer | 1.0.0 |
| `cloudfront` | CloudFront Distribution | 1.0.0 |
| `cloudwatch-log-group` | CloudWatch Log Group (KMS 암호화) | 1.0.0 |
| `common-tags` | 표준 리소스 태깅 | 1.0.0 |
| `ecs-service` | ECS Fargate Service | 1.0.0 |
| `elasticache` | ElastiCache Redis | 1.0.0 |
| `iam-role-policy` | IAM Role and Policy | 1.0.0 |
| `lambda` | Lambda Function 관리 | 1.0.0 |
| `messaging-pattern` | 메시징 패턴 (SNS+SQS) | 1.0.0 |
| `rds` | RDS MySQL/PostgreSQL (Multi-AZ) | 1.0.0 |
| `route53-record` | Route53 DNS 레코드 | 1.0.0 |
| `s3-bucket` | S3 Bucket (암호화, Lifecycle) | 1.0.0 |
| `security-group` | Security Group Templates | 1.0.0 |
| `sns` | SNS Topic 관리 | 1.0.0 |
| `sqs` | SQS Queue (KMS 암호화) | 1.0.0 |
| `vpc` | VPC 및 Network 구성 | 1.0.0 |
| `waf` | WAF 규칙 관리 | 1.0.0 |

**📖 자세한 내용**: [Modules Directory](terraform/modules/)

---

## 🔄 워크플로

### 개발 워크플로

```bash
# 1. Feature 브랜치 생성
git checkout -b feature/XXX-description

# 2. Terraform 코드 작성
cd terraform/network
vim main.tf

# 3. 로컬 검증
terraform fmt -recursive
terraform validate
terraform plan

# 4. 커밋 및 푸시
git add .
git commit -m "feat: Add VPC peering configuration "
git push origin feature/XXX-description

# 5. Pull Request 생성
# GitHub에서 PR 생성 → Atlantis가 자동으로 terraform plan 실행
```

### 자동화된 검증

PR 생성 시 자동으로 다음 검증이 실행됩니다:

- ✅ **Terraform Format**: `terraform fmt` 검사
- ✅ **Terraform Validate**: 구문 검증
- ✅ **Security Scan**: tfsec, checkov (보안 취약점)
- ✅ **Policy Validation**: OPA 정책 (태깅, 암호화, 네이밍)
- ✅ **Cost Analysis**: Infracost (비용 영향 분석)

---

## 🔐 보안 및 컴플라이언스

### 필수 보안 규칙

1. **KMS 암호화**: 모든 데이터는 Customer Managed KMS Key로 암호화 (9개 키 운영)
2. **필수 태그**: Owner, CostCenter, Environment, Lifecycle, DataClass, Service
3. **Security Group**: 최소 권한 원칙, 0.0.0.0/0 개방 금지
4. **Secrets 관리**: Secrets Manager 사용, Lambda 자동 로테이션 (90일 주기)

### KMS 암호화 키 (9개)

데이터 클래스별로 분리된 암호화 키 관리:

| KMS 키 | 용도 | 데이터 클래스 |
|--------|------|---------------|
| `terraform-state` | Terraform 상태 파일 암호화 | Confidential |
| `rds` | RDS 데이터베이스 암호화 | Highly Confidential |
| `ecs-secrets` | ECS 환경 변수 및 시크릿 | Confidential |
| `secrets-manager` | Secrets Manager 암호화 | Highly Confidential |
| `cloudwatch-logs` | CloudWatch 로그 암호화 | Internal |
| `s3` | S3 버킷 암호화 | Various |
| `sqs` | SQS 메시지 암호화 | Internal |
| `ssm` | SSM Parameter Store 암호화 | Confidential |
| `elasticache` | ElastiCache 데이터 암호화 | Internal |

**모든 KMS 키는 자동 로테이션 활성화** (매년 자동 갱신)

### Secrets 자동 로테이션

Lambda 기반 자동 로테이션 시스템:

- **로테이션 주기**: 90일 자동 갱신
- **지원 시크릿**:
  - RDS 데이터베이스 자격증명
  - API Keys (외부 서비스)
  - Application Secrets
- **알림**: CloudWatch Logs + SNS 알림
- **모니터링**: 로테이션 실패 시 자동 알림

**📖 자세한 내용**: [Secrets Rotation Guide](docs/governance/README_SECRETS_ROTATION.md)

### 자동 검증 도구

- **tfsec**: AWS 보안 모범 사례
- **checkov**: 컴플라이언스 프레임워크 (CIS AWS, PCI-DSS)
- **OPA (Open Policy Agent)**: 커스텀 정책 검증 (태깅, 네이밍, 보안그룹, 공개리소스)

**📖 자세한 내용**: [Infrastructure Governance](docs/governance/infrastructure_governance.md)

---

## 📊 모니터링

### CloudWatch 알람

- **ECS**: CPU > 80%, Memory > 85%, Task Count = 0
- **RDS**: CPU > 70%, Connections > 80%, Storage < 20%
- **ALB**: 5xx Errors > 1%, Response Time > 1s

### 중앙 모니터링

- **AMP (Amazon Managed Prometheus)**: 메트릭 수집
- **AMG (Amazon Managed Grafana)**: 시각화 대시보드
- **X-Ray**: 분산 트레이싱

**📖 자세한 내용**: [모니터링 가이드](docs/guides/hybrid-06-monitoring-guide.md)

---

## 🚨 인시던트 대응

긴급 문제 발생 시 다음 런북을 참조하세요:

- [ECS High CPU](docs/runbooks/ecs-high-cpu.md) - CPU 사용량 급증 대응
- [ECS Memory Critical](docs/runbooks/ecs-memory-critical.md) - 메모리 크리티컬 알림
- [ECS Task Count Zero](docs/runbooks/ecs-task-count-zero.md) - 태스크 실패 대응

---

## 🧰 개발자 도구

### Claude Code 통합

이 프로젝트는 **Claude Code** 커맨드를 제공하여 개발 효율을 높입니다:

```bash
# Claude Commands 설치
ln -s /Users/sangwon-ryu/infrastructure/docs/claude-commands/if \
      ~/.claude/commands/if
```

**사용 가능한 커맨드**:
- `/if/validate` - 모듈 검증 (필수 파일, terraform validate, governance 체크)
- `/if/module` - 모듈 관리 및 재사용 (심볼릭 링크 생성)
- `/if/atlantis` - Atlantis 프로젝트 자동 추가

**📖 자세한 내용**: [Claude Commands 설치 가이드](docs/claude-commands/INSTALL.md)

### 자동화 스크립트

```bash
# 모든 모듈 검증
./scripts/validators/validate-modules.sh

# 특정 모듈만 검증
./scripts/validators/validate-modules.sh alb

# Atlantis에 새 프로젝트 추가 (대화형)
./scripts/atlantis/add-project.sh

# Atlantis 상태 확인
./scripts/atlantis/check-atlantis-health.sh
```

---

## 🤝 기여 가이드

### Pull Request 체크리스트

PR 생성 전 다음을 확인하세요:

- [ ] `terraform fmt -recursive` 실행 완료
- [ ] `terraform validate` 통과
- [ ] `terraform plan` 결과 검토 완료
- [ ] 보안 스캔 (tfsec, checkov) 통과
- [ ] 필수 태그 포함 (`merge(local.required_tags)`)
- [ ] KMS 암호화 적용
- [ ] 문서 업데이트 (해당 시)

### 커밋 메시지 규칙

```bash
# 형식
<type>: <subject>

# 타입
feat: 새로운 기능
fix: 버그 수정
docs: 문서 업데이트
refactor: 코드 리팩토링
test: 테스트 추가/수정

# 예제
feat: Add Shared RDS connection for FileFlow 
fix: Correct KMS key reference in S3 module
docs: Update hybrid infrastructure guide
```

---

## 📞 지원 및 문의

### 문제 발생 시

1. **트러블슈팅 가이드**: [hybrid-08-troubleshooting-guide.md](docs/guides/hybrid-08-troubleshooting-guide.md)
2. **Email**: fbtkdals2@naver.com
3. **Runbook**: `/docs/runbooks/` 참조

---

## 📚 추가 자료

### 내부 문서
- [Documentation Hub](docs/README.md) - 전체 문서 인덱스

### 외부 링크
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Atlantis Documentation](https://www.runatlantis.io/docs/)

---

## 📝 라이선스

이 프로젝트는 ryu-qqq의 인프라 관리 코드입니다.

---

**Last Updated**: 2025-11-13
**Maintainers**: ryu-qqq
