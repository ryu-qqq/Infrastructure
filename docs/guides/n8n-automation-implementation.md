# n8n 자동화 워크플로 구현 가이드

> 최종 업데이트: 2025-01-15
> 상태: Phase 1 구현 시작

## 개요

개발 생산성 향상을 위한 n8n 기반 자동화 워크플로 구현 가이드.
Sentry, Jira, GitHub, Slack을 연동하여 에러 추적부터 리포팅까지 자동화.

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────────┐
│                        n8n Automation Hub                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐      │
│   │ Sentry  │────▶│   n8n   │────▶│  Jira   │     │  Slack  │      │
│   └─────────┘     │ Webhook │     └─────────┘     └─────────┘      │
│                   │         │           │              ▲            │
│   ┌─────────┐     │   AI    │           │              │            │
│   │ GitHub  │────▶│ 분석    │───────────┼──────────────┘            │
│   │ Actions │     │         │           │                           │
│   └─────────┘     └─────────┘           │                           │
│                        │                │                           │
│                        ▼                ▼                           │
│                   ┌─────────┐     ┌─────────┐                       │
│                   │ 메트릭  │     │ GitHub  │                       │
│                   │ 저장소  │     │ Issue   │                       │
│                   └─────────┘     └─────────┘                       │
│                        │                                            │
│                        ▼                                            │
│                   ┌─────────┐                                       │
│                   │ 주간    │                                       │
│                   │ 리포트  │                                       │
│                   └─────────┘                                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: 핵심 자동화 (구현 대상)

### 1.1 Sentry → Jira 티켓 자동 생성

**목표**: Sentry 에러 발생 시 Jira 티켓 자동 생성 (중복 방지 포함)

**워크플로**:
```
Sentry Alert
    ↓
n8n Webhook (/sentry-alert)
    ↓
Parse Sentry Data (에러 정보 추출)
    ↓
AI Analyze Error (GPT-4o 분석)
    ↓
Generate Fingerprint (중복 체크용 식별자)
    ↓
Search Jira (JQL로 기존 티켓 검색)
    ↓
┌─────────────────┐
│  티켓 존재?      │
├─────────────────┤
│ Yes → 코멘트 추가 │
│ No  → 티켓 생성   │
└─────────────────┘
    ↓
Notify Slack (결과 알림)
```

**사용 모듈**:
- `modules/jira/search-duplicate.json`
- `modules/jira/create-issue.json`
- `modules/common/dedupe-check.json`
- `modules/common/severity-router.json`

**프로젝트 → Jira 매핑**:
```yaml
project_mapping:
  product-hub: PROD
  auth-hub: AUTH
  crawler: CRAWL
  mcp-server: MCP
  infrastructure: INFRA
  default: DEV
```

**Fingerprint 생성 규칙**:
```javascript
// Sentry 에러의 고유 식별자 생성
const fingerprint = [
  project,           // 프로젝트명
  error.type,        // 에러 타입 (NullPointerException 등)
  error.culprit,     // 발생 위치 (클래스.메서드)
].join('-').replace(/[^a-zA-Z0-9-]/g, '_');

// 예: product-hub-NullPointerException-UserService_getUser
```

---

### 1.2 GitHub Actions 빌드 메트릭 수집

**목표**: 빌드/배포 메트릭 수집하여 주간 리포트에 활용

**워크플로**:
```
GitHub Webhook (workflow_run 이벤트)
    ↓
n8n Webhook (/github-workflow)
    ↓
Parse Workflow Data
    ↓
Store Metrics (JSON 파일)
```

**수집 데이터**:
```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "repository": "ryu-qqq/product-hub",
  "workflow": "CI/CD Pipeline",
  "status": "success",
  "duration_seconds": 245,
  "triggered_by": "push",
  "branch": "main",
  "commit_sha": "abc1234",
  "is_deployment": true,
  "environment": "prod"
}
```

**저장 위치**: `n8n-workflows/data/github-metrics/YYYY-MM.json`

---

### 1.3 주간 개발 리포트

**목표**: 매주 월요일 9AM에 개발 현황 리포트 Slack 발송

**워크플로**:
```
Schedule Trigger (월요일 09:00)
    ↓
Calculate Week Range (지난주 범위)
    ↓
┌─────────────────────────────────────┐
│ 병렬 데이터 수집                      │
├─────────────────────────────────────┤
│ • Jira API: 완료/생성 티켓           │
│ • GitHub API: PR/커밋 통계           │
│ • Sentry API: 에러 통계              │
│ • 메트릭 저장소: 빌드 통계            │
└─────────────────────────────────────┘
    ↓
Aggregate Data (데이터 집계)
    ↓
AI Summarize (주요 인사이트 요약)
    ↓
Format Slack Message (Block Kit)
    ↓
Send to #dev-reports
```

**리포트 포맷**:
```
📊 주간 개발 리포트 (1/6 ~ 1/12)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 빌드 & 배포
• 총 빌드: 45회 (성공률 93%)
• 평균 시간: 4분 32초
• 배포: 8회 (prod 5, stage 3)

🎫 Jira 티켓
• 완료: 12개 (버그 5, 기능 4, 태스크 3)
• 신규: 8개
• 스토리 포인트: 28 SP

🐛 Sentry 에러
• 새 이슈: 3개
• 해결: 5개
• 총 이벤트: 1,247회 (-15% 전주 대비)

🤖 AI 요약
이번 주 백엔드 안정성이 개선되었습니다...
```

---

## Phase 2: 확장 기능 (추후 검토)

### 2.1 Claude Code OTEL 연동

**현황**: Claude Code가 OTEL 메트릭 내보내기를 지원하지만,
Jira 티켓과 자동 연결은 현재 불가능 (수동 태깅 필요)

**가능한 것**:
- 세션당 토큰 사용량 추적
- 전체 비용 집계
- 주간 리포트에 AI 사용량 포함

**불가능한 것**:
- 티켓별 AI 비용 자동 추적
- 자동 ROI 계산

### 2.2 AI 자동 코드 수정

**현실적 평가**:

| 시나리오 | 자동화 가능성 | 권장 접근 |
|----------|--------------|----------|
| 린트/포맷 에러 | ✅ 높음 | GitHub Action으로 자동 수정 |
| 간단한 타입 에러 | ⚠️ 중간 | AI 제안 → 개발자 검토 |
| 비즈니스 로직 버그 | ❌ 낮음 | AI 분석만, 수정은 수동 |

**현재 구현된 기능** (sentry-error-orchestrator.json):
- AI가 에러 분석 및 해결방안 제시
- GitHub Issue 자동 생성 (AI 분석 결과 포함)
- @claude 멘션 (수동 트리거 대기)

**권장 워크플로**:
```
Sentry 에러 → AI 분석 → Jira 티켓 + GitHub Issue
                              ↓
                      개발자가 Issue 확인
                              ↓
                      수동으로 Claude Code 실행
                              ↓
                      PR 생성 및 리뷰
```

---

## 구현 현황

### 생성된 모듈

```
n8n-workflows/modules/
├── README.md                    # 패턴 분석 문서
├── triggers/
│   └── schedule-weekly.json     # 주간 스케줄 트리거
├── jira/
│   ├── search-duplicate.json    # 중복 검색 (JQL)
│   └── create-issue.json        # 이슈 생성
├── ai/
│   └── classify-issue.json      # AI 이슈 분류
├── slack/
│   └── weekly-report.json       # 주간 리포트 포맷
└── common/
    ├── dedupe-check.json        # 중복 IF 분기
    └── severity-router.json     # 심각도 라우팅
```

### 기존 워크플로

| 파일 | 상태 | 설명 |
|------|------|------|
| `sentry-error-orchestrator.json` | ✅ 있음 | Sentry → AI 분석 → GitHub Issue → Slack |
| `infra-issue-orchestrator.json` | ✅ 있음 | 인프라 변경 요청 처리 + Slack 승인 |

### 필요한 수정/생성

| 작업 | 우선순위 | 예상 시간 |
|------|----------|----------|
| sentry-error-orchestrator에 Jira 연동 추가 | 🔴 높음 | 2시간 |
| github-metrics-collector.json 신규 생성 | 🟡 중간 | 2시간 |
| weekly-dev-report.json 신규 생성 | 🟡 중간 | 3시간 |

---

## 설정 요구사항

### n8n Credentials

| 서비스 | Credential 타입 | 필요 권한 |
|--------|----------------|----------|
| Jira | Jira API | 이슈 생성/검색/코멘트 |
| GitHub | GitHub API | 레포 읽기, Issue 생성, Webhook |
| Slack | Slack API | 메시지 전송, Block Kit |
| OpenAI | OpenAI API | GPT-4o 접근 |
| Sentry | HTTP Header Auth | API 읽기 (선택) |

### Webhook 설정

**Sentry Integration**:
```yaml
type: Internal Integration
webhook_url: https://your-n8n.com/webhook/sentry-alert
events:
  - issue.created
  - issue.resolved
```

**GitHub Webhook**:
```yaml
payload_url: https://your-n8n.com/webhook/github-workflow
content_type: application/json
secret: ${GITHUB_WEBHOOK_SECRET}
events:
  - workflow_run
```

---

## 구현 현황

### Phase 1 완료 ✅

1. [x] `sentry-jira-orchestrator.json` ✅
   - Sentry webhook → AI 분석 → Jira 중복 검색 → 티켓 생성/코멘트
   - 프로젝트 → Jira 프로젝트 매핑 (PROD, AUTH, CRAWL, MCP, INFRA)
   - Fingerprint 기반 중복 방지
   - GitHub Issue 연동 + Slack 알림

2. [x] `github-metrics-collector.json` ✅
   - GitHub workflow_run 웹훅 수신
   - 빌드/배포 메트릭 파싱 (duration, status, branch, environment)
   - 배포 실패 시 #deployments 채널 알림
   - 빌드 실패 시 #builds 채널 알림

3. [x] `weekly-dev-report.json` ✅
   - 매주 월요일 9AM 스케줄 트리거
   - Jira/GitHub/Sentry 병렬 데이터 수집
   - GPT-4o 기반 한국어 요약
   - Slack Block Kit 포맷 #dev-reports 발송

### 다음 단계 (Phase 2)

- [ ] Claude Code OTEL 연동 (사용량 추적만)
- [ ] Grafana 대시보드 연동
- [ ] 더 정교한 심각도 판단 로직
- [ ] 빌드 메트릭 파일 저장소 연동 (github-metrics-collector → weekly-dev-report)

### 설정 필요 사항

n8n에서 아래 Credential을 설정해야 합니다:

| Credential ID | 서비스 | 용도 |
|--------------|--------|------|
| `JIRA_CREDENTIAL_ID` | Jira Cloud API | 티켓 검색/생성 |
| `GITHUB_CREDENTIAL_ID` | GitHub API | PR/커밋 조회 |
| `SLACK_CREDENTIAL_ID` | Slack OAuth | 메시지 전송 |
| `OPENAI_CREDENTIAL_ID` | OpenAI API | AI 분석/요약 |
| `SENTRY_CREDENTIAL_ID` | Sentry API (HTTP Header) | 에러 통계 조회 |

### Webhook 설정

**Sentry Integration**:
- URL: `https://your-n8n.com/webhook/sentry-alert`
- Events: `issue.created`, `issue.resolved`

**GitHub Webhook**:
- URL: `https://your-n8n.com/webhook/github-workflow`
- Events: `workflow_run`
- Secret: 환경변수로 관리

---

## 관련 리소스

### 템플릿 참조
- [Splunk → Jira (중복 방지)](https://n8n.io/workflows/1970)
- [GitHub → Jira with OpenAI](https://n8n.io/workflows/8216)
- [Weekly Report with AI](https://n8n.io/workflows/3969)
- [Error Log Monitor](https://n8n.io/workflows/6677)

### 프로젝트 문서
- `docs/guides/automation-workflow-roadmap.md` - 전체 로드맵
- `n8n-workflows/modules/README.md` - 모듈 패턴 분석

### 외부 문서
- [n8n Jira Node](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.jira/)
- [Sentry Webhooks](https://docs.sentry.io/product/integrations/integration-platform/webhooks/)
- [Slack Block Kit](https://api.slack.com/block-kit)
