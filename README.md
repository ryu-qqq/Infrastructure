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
│   ├── validators/         # Terraform 검증 스크립트 (7개)
│   ├── atlantis/           # Atlantis 운영 스크립트
│   ├── hooks/              # Git hooks 설정
│   └── policy/             # OPA 정책 헬퍼
├── docs/
│   ├── guides/             # 운영 가이드 (16개)
│   ├── governance/         # 거버넌스 정책 (10개)
│   ├── modules/            # 모듈 개발 가이드 (6개)
│   ├── runbooks/           # 인시던트 대응 런북 (3개)
│   ├── workflows/          # 워크플로 문서
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

### 핵심 모듈 (15개)

| 모듈 | 설명 | 버전 |
|------|------|------|
| `alb` | Application Load Balancer | 1.0.0 |
| `cloudwatch-log-group` | CloudWatch Log Group (KMS 암호화) | 1.0.0 |
| `common-tags` | 표준 리소스 태깅 | 1.0.0 |
| `ecs-service` | ECS Fargate Service | 1.0.0 |
| `elasticache` | ElastiCache Redis | 1.0.0 |
| `iam-role-policy` | IAM Role and Policy | 1.0.0 |
| `lambda` | Lambda Function 관리 | 1.0.0 |
| `messaging-pattern` | 메시징 패턴 (SNS+SQS) | 1.0.0 |
| `rds` | RDS MySQL (Multi-AZ) | 1.0.0 |
| `route53-record` | Route53 DNS 레코드 | 1.0.0 |
| `s3-bucket` | S3 Bucket (암호화, Lifecycle) | 1.0.0 |
| `security-group` | Security Group Templates | 1.0.0 |
| `sns` | SNS Topic 관리 | 1.0.0 |
| `sqs` | SQS Queue (KMS 암호화) | 1.0.0 |
| `waf` | WAF 규칙 관리 | 1.0.0 |

**📖 자세한 내용**: [Modules Directory](terraform/modules/)

---

## 🔄 워크플로

### 개발 워크플로

```bash
# 1. Feature 브랜치 생성
git checkout -b feature/KAN-XXX-description

# 2. Terraform 코드 작성
cd terraform/network
vim main.tf

# 3. 로컬 검증
terraform fmt -recursive
terraform validate
terraform plan

# 4. 커밋 및 푸시
git add .
git commit -m "feat: Add VPC peering configuration (KAN-XXX)"
git push origin feature/KAN-XXX-description

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

## 💰 비용 최적화

### 환경별 월간 예상 비용

| 환경 | ECS | RDS | 기타 | **합계** |
|------|-----|-----|------|----------|
| **Dev** | $11 | 공유 | $134 | **~$145/월** |
| **Staging** | $44 | 공유 | $278 | **~$322/월** |
| **Prod** | $132 | 공유 | $531 | **~$663/월** |
| **Shared Infrastructure** | - | $145 | $227 | **~$372/월** |
| **전체 합계** | | | | **~$1,502/월** |

### 비용 절감 전략

1. **Fargate Spot**: 70% 비용 절감 (Prod 환경 적용)
2. **S3 Lifecycle**: Standard → IA → Glacier (80% 절감)
3. **Shared RDS**: 여러 서비스가 하나의 RDS 공유 (50% 절감)
4. **VPC Endpoints**: NAT Gateway 대신 사용 (90% 절감)
5. **Reserved Instances**: 1년 약정 (30% 절감)

**📖 자세한 내용**: [운영 가이드 - 비용 최적화](docs/guides/hybrid-07-operations-guide.md#1-비용-예측-및-최적화)

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

**Slack 알림**: `#platform-alerts` 채널

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
- [ ] 관련 Jira 태스크 링크
- [ ] 문서 업데이트 (해당 시)

### 커밋 메시지 규칙

```bash
# 형식
<type>: <subject> (JIRA-XXX)

# 타입
feat: 새로운 기능
fix: 버그 수정
docs: 문서 업데이트
refactor: 코드 리팩토링
test: 테스트 추가/수정

# 예제
feat: Add Shared RDS connection for FileFlow (KAN-147)
fix: Correct KMS key reference in S3 module (KAN-155)
docs: Update hybrid infrastructure guide
```

---

## 📞 지원 및 문의

### 문제 발생 시

1. **트러블슈팅 가이드**: [hybrid-08-troubleshooting-guide.md](docs/guides/hybrid-08-troubleshooting-guide.md)
2. **FAQ**: 트러블슈팅 가이드 내 포함
3. **Slack**: `#platform-support` 채널
4. **Email**: platform@ryuqqq.com

### 긴급 인시던트

- **P0/P1**: Slack `#platform-alerts` 채널로 즉시 알림
- **Runbook**: `/docs/runbooks/` 참조
- **On-call**: PagerDuty 통해 담당자 호출

---

## 📚 추가 자료

### 내부 문서
- [CLAUDE.md](CLAUDE.md) - Claude Code 가이드
- [Documentation Hub](docs/README.md) - 전체 문서 인덱스

### 외부 링크
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Atlantis Documentation](https://www.runatlantis.io/docs/)

### Jira 프로젝트
- [IN-1 - Atlantis 서버 ECS 배포](https://ryuqqq.atlassian.net/browse/IN-1)
- [IN-100 - 재사용 가능한 표준 모듈](https://ryuqqq.atlassian.net/browse/IN-100)

---

## 📈 통계

- **Terraform 모듈**: 15개
- **KMS 암호화 키**: 9개
- **문서**: 50개 (Governance 10, Guides 16, Modules 6, Runbooks 3, Workflows 2, Changelogs 2)
- **CI/CD 워크플로**: 6개 (GitHub Actions)
- **검증 스크립트**: 7개 (tfsec, checkov, tags, encryption, naming, secrets-rotation 등)
- **OPA 정책**: 4개 (태깅, 네이밍, 보안그룹, 공개리소스)
- **월간 인프라 비용**: ~$1,502

---

## 📝 라이선스

이 프로젝트는 Ryuqqq의 내부 인프라 코드입니다. 외부 공유 금지.

---

**Last Updated**: 2025-10-24

**Maintainers**: Platform Team (@platform-team)
