# 🏗️ Infrastructure Management

조직 전체의 공통 인프라를 중앙에서 관리하는 프로젝트입니다. Atlantis 기반 GitOps로 모든 프로젝트의 인프라를 표준화하고 효율적으로 운영합니다.

## 📌 프로젝트 개요

**Jira Project Key**: `IN`

**GitHub Repository**: [https://github.com/ryu-qqq/infrastructure](https://github.com/ryu-qqq/infrastructure)

**담당자**: 시스템 아키텍트

**시작일**: 2025년 10월

**상태**: 기획 중

---

## 🎯 왜 필요한가?

### 현재 문제점

현재 각 프로젝트(크롤러, 인증, 파일 관리 등)가 독립적으로 인프라를 관리하면서 다음과 같은 문제가 발생하고 있습니다.

**중복된 인프라 코드**

각 프로젝트마다 비슷한 Terraform 코드를 반복 작성하고 있습니다. VPC 설정, ECS 클러스터 구성, RDS 설정 등이 프로젝트별로 중복됩니다.

**일관성 부족**

VPC CIDR, 보안 그룹 규칙, IAM 정책 등이 프로젝트마다 다르게 구성되어 있습니다. 이는 보안 감사를 어렵게 만들고, 프로젝트 간 연동 시 예상치 못한 문제를 야기합니다.

**관리 포인트 증가**

각 프로젝트마다 별도의 Terraform 배포 파이프라인을 구축하고 유지보수해야 합니다. 프로젝트가 늘어날수록 관리 부담이 기하급수적으로 증가합니다.

**보안 및 규정 준수 어려움**

보안 정책, 감사 로그, 태깅 표준이 일관되지 않아 규정 준수를 증명하기 어렵습니다.

**드리프트 감지 불가**

수동으로 변경된 인프라와 코드 간의 불일치(drift)를 감지하고 해결하기 어렵습니다.

### Infrastructure 프로젝트의 역할

**중앙 집중식 인프라 관리**

Atlantis를 통한 GitOps 기반으로 모든 프로젝트의 인프라를 하나의 워크플로우로 관리합니다.

**공유 리소스 관리**

VPC, Transit Gateway, NAT Gateway, 중앙 모니터링, 로깅, 보안 서비스 등 조직 공통 인프라를 제공합니다.

**표준화 및 재사용**

검증된 Terraform 모듈과 표준 정책을 제공하여 모든 프로젝트가 동일한 패턴과 보안 정책을 적용합니다.

**효율적인 변경 관리**

한 곳에서 모든 프로젝트의 인프라 변경을 추적하고, PR 기반으로 리뷰 및 승인할 수 있습니다.

**비용 최적화 및 거버넌스**

공유 리소스 활용, 필수 태깅, Infracost를 통한 비용 추적으로 인프라 비용을 절감하고 투명하게 관리합니다.

**보안 및 규정 준수**

중앙 집중식 보안 정책, CloudTrail/Config/Security Hub를 통한 감사, tfsec/checkov 자동 검사로 보안을 강화합니다.

---

## 🏛️ 아키텍처 원칙

### GitOps 원칙

모든 인프라 변경은 Git을 통해서만 이루어집니다. 수동 변경은 금지되며, 모든 변경은 PR과 코드 리뷰를 거쳐야 합니다.

### 표준화 원칙

네이밍, 태깅, 모듈, 보안 정책 등 모든 인프라 요소는 조직 표준을 따라야 합니다.

### 가시성 원칙

SLO/SLI, 대시보드, 알람, 런북을 통해 모든 인프라의 상태와 성능을 투명하게 관리합니다.

### 최소 권한 원칙

모든 리소스와 서비스는 필요한 최소한의 권한만 부여받습니다.

### 계층 분리 원칙

공유 인프라(Shared), 제품별 인프라(Stacks), 공용 모듈(Modules)을 명확히 분리합니다.

---

## 🗺️ 전체 로드맵

### Phase 1: 중앙 인프라 및 거버넌스 구축 (2-3주)

**목표**: Atlantis 기반 GitOps 환경을 구축하고 조직 표준을 정립합니다.

**주요 작업**

- AWS 계정 분리 전략 수립 (shared/dev/stg/prod)
- Atlantis 서버 ECS 배포 및 보안 강화
- GitHub App 연동 및 멀티 레포지토리 설정
- 거버넌스 정책 수립 (승인 규칙, 권한, PR 게이트)
- 공유 VPC 및 네트워크 구성 (Transit Gateway 기반)
- KMS 키 전략 (데이터 클래스별 분리)
- Terraform State 백엔드 표준화 (S3 + DynamoDB)
- 필수 태그 스키마 및 네이밍 규약 정의
- 보안 도구 통합 (tfsec, checkov, Infracost)

**예상 기간**: 2-3주

### Phase 2: 중앙 관측성 및 보안 체계 구축 (1-2주)

**목표**: 로깅, 모니터링, 보안 감시를 중앙에서 통합 관리합니다.

**주요 작업**

- CloudWatch 중앙 로깅 시스템 (Firehose → S3 아카이브)
- 표준 알람 세트 구축 (애플리케이션/인프라)
- OpenTelemetry 기반 추적 시스템
- 런북 템플릿 작성
- CloudTrail 중앙 수집
- AWS Config 규칙 활성화
- Security Hub 통합
- Secrets Manager 중앙 관리 체계
- DR 전략 수립 및 백업 정책

**예상 기간**: 1-2주

### Phase 3: 공통 모듈 및 골든 패스 구축 (1-2주)

**목표**: 재사용 가능한 모듈과 서비스 온보딩 자동화를 구축합니다.

**주요 작업**

- ECS Service 모듈 (SemVer 버전 관리)
- RDS 모듈 (Multi-AZ, Proxy, 백업 자동화)
- ALB/NLB 모듈
- S3 Bucket 모듈 (암호화, 버저닝, 수명주기)
- IAM 역할 모듈
- 보안 그룹 모듈
- 서비스 온보딩 스캐폴드 스크립트
- 모듈 문서화 및 예제 작성
- 샌드박스 환경 구축

**예상 기간**: 1-2주

[거버넌스 및 운영 기준](%F0%9F%8F%97%EF%B8%8F%20Infrastructure%20Management%20288b00296f3b81469005d8ee0dbd7773/%EA%B1%B0%EB%B2%84%EB%84%8C%EC%8A%A4%20%EB%B0%8F%20%EC%9A%B4%EC%98%81%20%EA%B8%B0%EC%A4%80%20288b00296f3b81f7986dc2bfa40c2483.md)

[PR 게이트 체크리스트 및 워크플로우](%F0%9F%8F%97%EF%B8%8F%20Infrastructure%20Management%20288b00296f3b81469005d8ee0dbd7773/PR%20%EA%B2%8C%EC%9D%B4%ED%8A%B8%20%EC%B2%B4%ED%81%AC%EB%A6%AC%EC%8A%A4%ED%8A%B8%20%EB%B0%8F%20%EC%9B%8C%ED%81%AC%ED%94%8C%EB%A1%9C%EC%9A%B0%20288b00296f3b8136b8ddc518dd5e369b.md)

### Phase 4: 기존 프로젝트 마이그레이션 (프로젝트당 1주)

**목표**: 크롤러, AuthHub, FileFlow 프로젝트의 인프라를 중앙 관리로 전환합니다.

**주요 작업**

- 각 프로젝트의 기존 Terraform 코드 분석
- 공유 모듈을 활용한 리팩토링
- Atlantis 워크플로우 적용
- 환경별 설정 마이그레이션 (dev, staging, prod)
- 기존 리소스 import 및 검증
- SLO/알람/런북 작성

**예상 기간**: 프로젝트당 1주

### Phase 5: 고급 기능 및 지속적 개선

**목표**: 인프라 운영의 효율성과 안정성을 더욱 향상시킵니다.

**주요 작업**

- 멀티 리전 지원
- 비용 최적화 대시보드
- 자동화된 DR 리허설
- 서비스 한도/쿼터 모니터링

**예상 기간**: 지속적 개선

---

## 🎯 기대 효과

### 개발 속도 향상

검증된 모듈과 골든 패스를 사용하여 인프라 구축 시간을 80% 단축할 수 있습니다.

### 일관성 유지

모든 프로젝트가 동일한 네트워크 구조, 보안 정책, 모니터링 체계를 적용받습니다.

### 비용 최적화

- 공유 리소스 활용
- 필수 태깅을 통한 비용 추적
- **예상 절감: 월 30% 절감**

### 보안 강화 및 규정 준수

- 중앙 집중식 보안 정책
- 자동화된 취약점 검사
- 감사 로그 자동 수집

---

## 🔗 관련 프로젝트

**현재 관리 대상**

- 🕷️ 머스트잇 크롤러 MVP
- 🔐 AuthHub
- 📦 FileFlow

---

## 📊 진행 상황

**현재 상태**: 운영 기준서 수립 완료

**다음 단계**

- Jira Phase 1 에픽 생성
- AWS 계정 구조 설계
- Infrastructure 리포지토리 생성

---

## 📚 참고 자료

- Atlantis: [https://www.runatlantis.io/docs/](https://www.runatlantis.io/docs/)
- Terraform Best Practices: [https://www.terraform-best-practices.com/](https://www.terraform-best-practices.com/)
- AWS Well-Architected: [https://aws.amazon.com/architecture/well-architected/](https://aws.amazon.com/architecture/well-architected/)
- GitHub: [https://github.com/ryu-qqq](https://github.com/ryu-qqq)