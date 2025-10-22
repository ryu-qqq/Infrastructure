# Infrastructure Documentation

인프라 문서 허브에 오신 것을 환영합니다. 이 디렉터리는 모든 문서를 카테고리별로 정리해 제공합니다.

## 📚 Documentation Structure

### 🏛️ [Governance](./governance/)
인프라 거버넌스 정책과 표준
- [Infrastructure Governance](./governance/infrastructure_governance.md) - 필수 태그, KMS 전략, 네이밍 규칙
- [Tagging Standards](./governance/TAGGING_STANDARDS.md) - AWS 리소스 태깅 요구사항
- [Naming Convention](./governance/NAMING_CONVENTION.md) - 리소스 네이밍 규칙(kebab-case)
- [Logging Naming Convention](./governance/LOGGING_NAMING_CONVENTION.md) - CloudWatch 로그 그룹 네이밍 표준
- [Infrastructure PR Workflow](./governance/infrastructure_pr.md) - PR 프로세스와 게이트 체크리스트

### 📘 [Guides](./guides/)
설치 및 운영 가이드

#### [Architecture Guides](./guides/)
- [하이브리드 인프라 가이드](./guides/hybrid-infrastructure-guide.md) - 중앙 집중식 + 분산 관리 하이브리드 구조 **⭐ NEW!**
- [Atlantis Operations](./guides/atlantis-operations-guide.md) - Atlantis 서버 운영 가이드
- [CloudTrail Operations](./guides/cloudtrail-operations-guide.md) - CloudTrail 감사 로그 관리
- [KMS Strategy](./guides/kms-strategy.md) - 암호화 키 관리 전략
- [Logging System Design](./guides/logging-system-design.md) - 로깅 시스템 설계
- [Secrets Management](./guides/secrets-management-strategy.md) - 비밀 관리 전략

#### [Setup Guides](./guides/setup/)
- [GitHub Actions Setup](./guides/setup/github_actions_setup.md) - GitHub Actions 기반 CI/CD 구성
- [Slack Setup Guide](./guides/setup/SLACK_SETUP_GUIDE.md) - AWS Chatbot과 Slack 연동
- [Jira Integration](./guides/setup/JIRA_INTEGRATION.md) - GitHub Issues ↔ Jira 동기화

#### [Onboarding Guides](./guides/onboarding/)
- [Service Repository Onboarding](./guides/onboarding/SERVICE_REPO_ONBOARDING.md) - 서비스 팀의 자율 인프라 구축 온보딩 가이드

#### [Operations Guides](./guides/operations/)
- [Logs Insights Queries](./guides/operations/LOGS_INSIGHTS_QUERIES.md) - CloudWatch Logs Insights 쿼리 예시
- [Infrastructure Notion](./guides/operations/infrastructure_notion.md) - Notion 연동 상세

### 🧩 [Modules](./modules/)
Terraform 모듈 개발 가이드
- [Directory Structure](./modules/MODULES_DIRECTORY_STRUCTURE.md) - 표준 모듈 디렉터리 구조
- [Module Template](./modules/MODULE_TEMPLATE.md) - 모듈 문서 템플릿
- [Standards Guide](./modules/MODULE_STANDARDS_GUIDE.md) - 코딩 표준 및 컨벤션
- [Examples Guide](./modules/MODULE_EXAMPLES_GUIDE.md) - 예제 코드 작성 방법
- [Versioning Guide](./modules/VERSIONING.md) - 모듈의 시맨틱 버저닝

### 🚨 [Runbooks](./runbooks/)
인시던트 대응을 위한 운영 런북
- [ECS High CPU](./runbooks/ecs-high-cpu.md) - CPU 사용량 급증 대응 절차
- [ECS Memory Critical](./runbooks/ecs-memory-critical.md) - 메모리 크리티컬 알림 대응
- [ECS Task Count Zero](./runbooks/ecs-task-count-zero.md) - 태스크 실패 대응 절차

### 📝 [Changelogs](./changelogs/)
변경 내역과 템플릿
- [Infrastructure Changelog](./changelogs/CHANGELOG_INFRASTRUCTURE.md) - 인프라 변경 이력
- [Changelog Template](./changelogs/CHANGELOG_TEMPLATE.md) - 모듈 변경 내역 템플릿


---

## 🚀 Quick Links

### 신규 팀원을 위한 안내
1. [하이브리드 인프라 가이드](./guides/hybrid-infrastructure-guide.md) - 인프라 아키텍처 이해 **⭐ NEW!**
2. [Service Repository Onboarding Guide](./guides/onboarding/SERVICE_REPO_ONBOARDING.md) - 서비스 온보딩
3. [Infrastructure Governance](./governance/infrastructure_governance.md) - 거버넌스 검토
4. [GitHub Actions 설정](./guides/setup/github_actions_setup.md)
5. Git 훅 설치: `./scripts/setup-hooks.sh`

### 모듈 개발자를 위한 안내
1. [Module Standards Guide](./modules/MODULE_STANDARDS_GUIDE.md) 읽기
2. 문서는 [Module Template](./modules/MODULE_TEMPLATE.md) 사용
3. [Directory Structure](./modules/MODULES_DIRECTORY_STRUCTURE.md) 준수
4. [Examples Guide](./modules/MODULE_EXAMPLES_GUIDE.md) 검토

### 운영을 위한 안내
1. 인시던트 대응은 [Runbooks](./runbooks/) 확인
2. 트러블슈팅은 [Logs Insights Queries](./guides/operations/LOGS_INSIGHTS_QUERIES.md) 활용
3. [Slack Alerts](./guides/setup/SLACK_SETUP_GUIDE.md) 설정

### 컴플라이언스를 위한 안내
1. [Tagging Standards](./governance/TAGGING_STANDARDS.md) 검토
2. [Naming Convention](./governance/NAMING_CONVENTION.md) 확인
3. [PR Workflow](./governance/infrastructure_pr.md) 이해

---

## 📊 Document Categories

| 카테고리 | 문서 수 | 목적 |
|----------|--------|------|
| Governance | 5 | 표준, 정책, 컨벤션 |
| Architecture Guides | 6 | 아키텍처 설계 및 전략 |
| Onboarding Guides | 1 | 서비스 팀 온보딩 및 첫 PR 튜토리얼 |
| Setup Guides | 3 | 초기 구성 및 연동 |
| Operations | 2 | 일상 운영 가이드 |
| Modules | 5 | 모듈 개발 가이드라인 |
| Runbooks | 3 | 인시던트 대응 절차 |
| Changelogs | 2 | 변경 이력 추적 |

**총 문서 수**: 현재 27개 문서 운영 중

---

## 🔍 Finding Documentation

### 작업별 검색
- **하이브리드 인프라 구축**: → [하이브리드 가이드](./guides/hybrid-infrastructure-guide.md) **⭐**
- **인프라 시작하기**: → [Onboarding Guide](./guides/onboarding/SERVICE_REPO_ONBOARDING.md)
- **새 모듈 만들기**: → [Modules](./modules/)
- **알림 대응하기**: → [Runbooks](./runbooks/)
- **CI/CD 설정하기**: → [Setup Guides](./guides/setup/)
- **표준 확인하기**: → [Governance](./governance/)

### 역할별 검색
- **플랫폼 엔지니어**: Governance, Modules, Runbooks
- **DevOps 엔지니어**: Setup Guides, Operations, Runbooks
- **개발자**: Modules, Setup Guides
- **컴플라이언스 담당자**: Governance, Changelogs

---

## 📝 Contributing

새 문서를 추가할 때는 다음을 따라주세요:
1. 적절한 카테고리 디렉터리에 파일을 위치
2. 이 README.md에 링크를 업데이트
3. 네이밍 컨벤션 준수(표준 문서는 대문자, 가이드는 소문자)
4. 관련 문서를 상호 참조

---

## 🏷️ Tags

`#infrastructure` `#terraform` `#aws` `#documentation` `#governance` `#modules`

Last updated: 2025-10-22
