# 하이브리드 Terraform 인프라 구조 가이드

**작성일**: 2025-10-22
**버전**: 2.0
**대상 독자**: DevOps 엔지니어, 플랫폼 팀, 새로운 서비스를 론칭하는 개발팀

---

## 개요

하이브리드 인프라 구조는 **중앙 집중식 관리**와 **프로젝트별 분산 관리**를 결합한 인프라 관리 방식입니다.

```
Infrastructure Repository          Application Repository
┌─────────────────────┐           ┌──────────────────────┐
│ 공유 인프라 (중앙)   │           │ 애플리케이션 인프라   │
│ - VPC, Subnets      │───────────│ - ECS, Task Def      │
│ - KMS Keys          │   SSM     │ - S3, SQS, Redis     │
│ - Shared RDS        │  Parameters│ - ALB, Auto Scaling  │
│ - ECR Repository    │           │ - Database Schema    │
└─────────────────────┘           └──────────────────────┘
```

### 왜 하이브리드 구조인가?

**✅ 장점:**
- 공유 리소스 중앙 관리 (VPC, KMS, 네트워크) - 비용 절감
- 서비스별 독립적 배포 가능 - 배포 유연성
- 애플리케이션 코드와 인프라 동기화 - 개발 생산성
- 일관성 유지 (중앙 거버넌스) - 보안 및 규정 준수

**📌 핵심 패턴:**
- Producer-Consumer 패턴을 통한 느슨한 결합
- SSM Parameter Store를 통한 크로스 스택 참조
- 공유 리소스와 애플리케이션 리소스의 명확한 분리

---

## 📚 가이드 목록

이 가이드는 다음 8개의 세부 문서로 구성되어 있습니다. 필요에 따라 해당 가이드를 참조하세요.

### 1️⃣ [개요 및 시작하기](hybrid-01-overview.md)
- **대상**: 처음 하이브리드 구조를 도입하는 팀
- **내용**: 개요, 빠른 시작 가이드, 기술 스택, 사전 요구사항
- **소요 시간**: 15분

**다루는 주제:**
- 하이브리드 인프라 구조란?
- 왜 이 구조를 사용하는가?
- 빠른 시작 체크리스트
- 필수 도구 및 버전 요구사항
- AWS 권한 및 IAM 정책

### 2️⃣ [아키텍처 설계](hybrid-02-architecture-design.md)
- **대상**: 아키텍처 이해가 필요한 팀, 새로운 서비스 설계자
- **내용**: 아키텍처 설계, 데이터 흐름, 역할 정의
- **소요 시간**: 20분

**다루는 주제:**
- Infrastructure 프로젝트 역할 (중앙 관리)
- Application 프로젝트 역할 (분산 관리)
- Producer-Consumer 패턴
- 데이터 흐름 다이어그램
- SSM Parameter Store 아키텍처

### 3️⃣ [Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md)
- **대상**: 플랫폼 팀, 중앙 인프라 관리자
- **내용**: Infrastructure 프로젝트 설정, SSM Parameters, 공유 리소스
- **소요 시간**: 30분

**다루는 주제:**
- Infrastructure 디렉토리 구조
- SSM Parameters 생성 방법
- Network 모듈 배포 (VPC, Subnets, Transit Gateway)
- KMS 모듈 배포 (7개 암호화 키)
- Shared RDS 설정 (옵션)
- ECR 레포지토리 생성

### 4️⃣ [Application 프로젝트 설정](hybrid-04-application-setup.md)
- **대상**: 서비스 개발팀, 새로운 서비스 론칭팀
- **내용**: Application 프로젝트 설정, data.tf, 환경별 구성
- **소요 시간**: 45분

**다루는 주제:**
- Application 프로젝트 구조 생성
- `data.tf` 작성 (SSM Parameter 데이터 소스)
- `locals.tf` 작성 (SSM Parameter 값 참조)
- `variables.tf` 작성
- `database.tf` 작성 (Shared RDS 연결)
- 리소스별 KMS Key 매핑
- IAM 역할 및 정책 작성
- 환경별 `terraform.tfvars` 작성

### 5️⃣ [배포 가이드](hybrid-05-deployment-guide.md)
- **대상**: 배포 담당자, DevOps 엔지니어
- **내용**: 검증, 배포, CI/CD 통합, GitHub Actions
- **소요 시간**: 30분

**다루는 주제:**
- Terraform 검증 (init, fmt, validate, plan)
- 배포 전 체크리스트
- 배포 실행 (dev/staging/prod)
- 배포 후 검증
- GitHub Actions 워크플로
- Atlantis 통합 (옵션)
- PR 자동화 전략

### 6️⃣ [모니터링 가이드](hybrid-06-monitoring-guide.md)
- **대상**: SRE, 운영팀, 모니터링 담당자
- **내용**: CloudWatch, X-Ray, 메트릭, 알람, 로그 분석
- **소요 시간**: 30분

**다루는 주제:**
- CloudWatch Logs 통합
- X-Ray 트레이싱 설정
- Application Insights 설정
- 메트릭 및 알람 설정 (CPU, Memory, 5xx, RDS)
- 로그 집계 및 분석 (S3 Export)
- 중앙 집중식 모니터링 (AMP + AMG)

### 7️⃣ [운영 가이드](hybrid-07-operations-guide.md)
- **대상**: 운영팀, SRE, DevOps 엔지니어
- **내용**: 운영, Rollback, DR, 비용 최적화
- **소요 시간**: 40분

**다루는 주제:**
- Rollback 절차 (Terraform State, RDS, ECS)
- 다중 리전 전략 (DR)
- DR Failover 시나리오
- 비용 예측 및 최적화
- Infracost 통합
- 환경별 예상 비용

### 8️⃣ [트러블슈팅 가이드](hybrid-08-troubleshooting-guide.md)
- **대상**: 모든 팀 (문제 발생 시 참조)
- **내용**: 트러블슈팅, 모범 사례, FAQ
- **소요 시간**: 필요 시 참조

**다루는 주제:**
- SSM Parameter를 찾을 수 없음
- Shared RDS 접근 권한 없음
- KMS Key 권한 오류
- Terraform State 잠금 오류
- 모듈을 찾을 수 없음
- Database 생성 스크립트 실패
- 모범 사례 (명명 규칙, 보안, 비용 최적화)
- FAQ (20개 이상의 자주 묻는 질문)

---

## 🚀 빠른 시작 (5분 요약)

### 1단계: Infrastructure 프로젝트 확인 (플랫폼 팀)

```bash
# 필수 SSM Parameters가 생성되었는지 확인
aws ssm get-parameters-by-path \
  --path /shared \
  --recursive \
  --region ap-northeast-2 \
  --query 'Parameters[*].[Name]' \
  --output table
```

**필수 Parameters (13개):**
- `/shared/network/*` (VPC, Subnets)
- `/shared/kms/*` (7개 KMS 키)
- `/shared/ecr/[service-name]-repository-url`
- `/shared/rds/[env]/*` (옵션, Shared RDS 사용 시)

### 2단계: Application 프로젝트 생성 (서비스 팀)

```bash
# 프로젝트 구조 생성
mkdir -p /Users/sangwon-ryu/[service-name]/infrastructure/terraform
cd /Users/sangwon-ryu/[service-name]/infrastructure/terraform

# 환경별 디렉토리 생성
mkdir -p environments/{dev,staging,prod}
```

### 3단계: 필수 파일 작성

1. **`data.tf`**: SSM Parameters를 데이터 소스로 참조
2. **`locals.tf`**: SSM Parameter 값을 로컬 변수로 매핑
3. **`variables.tf`**: 입력 변수 정의
4. **`environments/dev/terraform.tfvars`**: 환경별 설정

**📖 자세한 내용**: [Application 프로젝트 설정 가이드](hybrid-04-application-setup.md)

### 4단계: 배포

```bash
# 초기화 및 검증
terraform init
terraform fmt
terraform validate
terraform plan -var-file=environments/dev/terraform.tfvars

# 배포
terraform apply -var-file=environments/dev/terraform.tfvars
```

**📖 자세한 내용**: [배포 가이드](hybrid-05-deployment-guide.md)

---

## 📋 학습 경로

### 초급 (하이브리드 구조 이해)
1. [개요 및 시작하기](hybrid-01-overview.md) ⭐ **필수**
2. [아키텍처 설계](hybrid-02-architecture-design.md) ⭐ **필수**
3. FAQ 및 모범 사례 (트러블슈팅 가이드 내)

### 중급 (인프라 구축)
1. [Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md) ⭐ **필수**
2. [Application 프로젝트 설정](hybrid-04-application-setup.md) ⭐ **필수**
3. [배포 가이드](hybrid-05-deployment-guide.md)
4. [모니터링 가이드](hybrid-06-monitoring-guide.md)

### 고급 (운영 및 최적화)
1. [운영 가이드](hybrid-07-operations-guide.md)
2. [트러블슈팅 가이드](hybrid-08-troubleshooting-guide.md)
3. 비용 최적화 및 DR 전략

---

## 🎯 시나리오별 가이드 선택

### 시나리오 1: 새로운 서비스 론칭
```
1. [개요 및 시작하기](hybrid-01-overview.md) - 개념 이해
2. [Application 프로젝트 설정](hybrid-04-application-setup.md) - 프로젝트 생성
3. [배포 가이드](hybrid-05-deployment-guide.md) - 배포 실행
```

### 시나리오 2: 중앙 인프라 관리
```
1. [아키텍처 설계](hybrid-02-architecture-design.md) - 아키텍처 이해
2. [Infrastructure 프로젝트 설정](hybrid-03-infrastructure-setup.md) - 공유 리소스 관리
3. [모니터링 가이드](hybrid-06-monitoring-guide.md) - 중앙 모니터링
```

### 시나리오 3: 문제 해결
```
1. [트러블슈팅 가이드](hybrid-08-troubleshooting-guide.md) - 문제별 해결 방법
2. FAQ - 자주 묻는 질문
3. 해당 세부 가이드 참조
```

### 시나리오 4: DR 및 운영
```
1. [운영 가이드](hybrid-07-operations-guide.md) - Rollback, DR
2. [모니터링 가이드](hybrid-06-monitoring-guide.md) - 알람 및 로그
```

---

## 🔄 업데이트 및 기여

### 문서 업데이트
이 가이드는 지속적으로 업데이트됩니다. 최신 버전은 항상 이 레포지토리를 참조하세요.

**업데이트 알림:**
- 각 세부 가이드 상단에 **Last Updated** 날짜 표시
- `CHANGELOG.md` 참조

### 기여 방법
- 문제 발견 시: GitHub Issue 생성
- 개선 제안: Pull Request 제출
- 질문: FAQ에 없는 질문은 Issue로 등록

---

## 📞 지원 및 문의

### 문서 관련 문의
- **담당**: 플랫폼 팀
- **이메일**: platform@ryuqqq.com

### 긴급 지원
- **Slack 채널**: #platform-support
- **Runbook**: `/docs/runbooks/` (장애 대응)

---

## 📚 관련 문서

### 프로젝트 문서
- [Infrastructure 프로젝트 README](/terraform/shared/README.md)
- [공유 리소스 아키텍처](/terraform/shared/README.md)
- [모듈 개발 가이드](/docs/modules/MODULE_DEVELOPMENT_GUIDE.md)

### Terraform 패키지 문서
- [Network 패키지](/terraform/network/README.md) - VPC, Transit Gateway
- [KMS 패키지](/terraform/kms/README.md) - 암호화 키 관리
- [RDS 패키지](/terraform/rds/README.md) - Shared RDS
- [Monitoring 패키지](/terraform/monitoring/README.md) - AMP + AMG

### Governance 문서
- [태그 정책](/docs/governance/TAGGING_POLICY.md)
- [암호화 정책](/docs/governance/ENCRYPTION_POLICY.md)
- [명명 규칙](/docs/governance/NAMING_CONVENTIONS.md)

---

## 변경 이력

### 버전 2.0 (2025-10-22)
- 문서 구조 개편: 단일 문서 → 8개 세부 가이드로 분할
- 메인 가이드를 인덱스 역할로 재구성
- 시나리오별 가이드 선택 가이드 추가
- 학습 경로 명확화

### 버전 1.1 (2025-10-21)
- Shared RDS 상세 설정 추가
- 비용 최적화 섹션 강화
- DR 전략 추가

### 버전 1.0 (2025-10-20)
- 초기 버전 작성
- 기본 하이브리드 구조 가이드
