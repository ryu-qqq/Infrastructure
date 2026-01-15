# n8n Reusable Modules

> 템플릿 분석을 통해 추출한 재사용 가능한 n8n 노드 패턴들

## 모듈 구조

```
n8n-workflows/modules/
├── README.md                    # 이 문서
├── triggers/                    # 트리거 패턴
│   ├── webhook-secure.json      # HMAC 서명 검증 웹훅
│   └── schedule-weekly.json     # 주간 스케줄 트리거
├── jira/                        # Jira 연동 패턴
│   ├── create-issue.json        # 이슈 생성
│   ├── search-duplicate.json    # 중복 검색 (JQL)
│   └── add-comment.json         # 코멘트 추가
├── github/                      # GitHub 연동 패턴
│   ├── create-issue.json        # Issue 생성
│   ├── webhook-receiver.json    # Webhook 수신
│   └── trigger-copilot.json     # @copilot 멘션
├── slack/                       # Slack 알림 패턴
│   ├── block-message.json       # Block Kit 메시지
│   ├── interactive-buttons.json # 인터랙티브 버튼
│   └── weekly-report.json       # 주간 리포트 포맷
├── ai/                          # AI 처리 패턴
│   ├── classify-issue.json      # 이슈 분류
│   ├── summarize-text.json      # 텍스트 요약
│   └── analyze-error.json       # 에러 분석
└── common/                      # 공통 유틸리티
    ├── dedupe-check.json        # 중복 체크 패턴
    ├── severity-router.json     # 심각도 기반 라우팅
    └── parse-webhook.json       # 웹훅 데이터 파싱
```

---

## 핵심 패턴 분석 결과

### 1. 중복 방지 패턴 (Dedupe Pattern)

**출처**: [Splunk → Jira 템플릿](https://n8n.io/workflows/1970)

```
[데이터 수신] → [식별자 추출] → [기존 검색] → [IF 존재?]
                                                  ├─ Yes → 댓글 추가
                                                  └─ No → 신규 생성
```

**핵심 노드**:
- `Set`: 데이터 정규화 (호스트명, fingerprint 등)
- `Jira Search`: JQL 쿼리로 기존 이슈 검색
- `IF`: 검색 결과 기반 분기
- `Jira Create Issue` / `Jira Add Comment`

**적용 가능 케이스**:
- Sentry 에러 → Jira (fingerprint 기반)
- 알림 → 티켓 (호스트/서비스명 기반)

---

### 2. AI 분류 라우팅 패턴 (AI Classification Router)

**출처**: [GitHub → Jira with OpenAI](https://n8n.io/workflows/8216)

```
[이벤트 수신] → [AI 분류] → [Structured Output] → [IF 분기] → [타입별 처리]
                                                        ├─ Bug → Jira Bug
                                                        ├─ Task → Jira Task
                                                        └─ Feature → Jira Story
```

**핵심 노드**:
- `OpenAI Chat`: 분류 프롬프트
- `Structured Output Parser`: JSON 형식 강제
- `IF/Switch`: 타입별 라우팅

**분류 프롬프트 예시**:
```
Classify this issue into one of: bug, task, feature, question.
Return JSON: {"type": "bug", "priority": "high", "labels": ["backend"]}
```

---

### 3. 심각도 기반 라우팅 패턴 (Severity Router)

**출처**: [Error Log Monitor](https://n8n.io/workflows/6677)

```
[에러 감지] → [로그 파싱] → [심각도 판단] → [IF Critical?]
                                              ├─ Yes → Slack + Jira
                                              └─ No → Slack Only
```

**심각도 기준 예시**:
| 레벨 | 조건 | 액션 |
|------|------|------|
| Critical | `event_count > 100` OR `level == 'fatal'` | Jira + Slack + PagerDuty |
| High | `event_count > 50` OR `level == 'error'` | Jira + Slack |
| Medium | `level == 'warning'` | Slack Only |
| Low | `level == 'info'` | 로그만 |

---

### 4. AI 자동 수정 패턴 (AI Auto-Fix)

**출처**: [Jira → GitHub Copilot](https://n8n.io/workflows/11728)

```
[Jira 업데이트] → [조건 검증] → [컨텍스트 수집] → [GitHub Issue 생성]
                                                        ↓
                                              [@copilot 코멘트]
                                                        ↓
                                              [Jira 링크 업데이트]
```

**조건 검증**:
- 상태: "In Progress"
- 라벨: `product_approved` 있음
- 라벨: `copilot_assigned` 없음 (중복 방지)

**우리 케이스 적용**:
- `@copilot` → `@claude` 또는 GitHub Action 트리거
- Port Context → 프로젝트 README, 코드 구조 정보

---

### 5. 주간 리포트 패턴 (Weekly Report)

**출처**: [Slack Weekly Report with AI](https://n8n.io/workflows/3969)

```
[Schedule: 월 9AM] → [데이터 수집] → [사용자별 집계] → [AI 요약]
                          ↓                              ↓
                    [멀티 소스]                    [계층적 요약]
                    - Jira API                    - 개별 → 팀
                    - GitHub API                  - 팀 → 전체
                    - Sentry API
                          ↓
                    [Slack 발행]
```

**AI 요약 2단계**:
1. **1차**: 각 데이터 소스별 핵심 사항 추출
2. **2차**: 전체 통합 인사이트 생성

---

### 6. GitHub Webhook 패턴 (Secure Webhook)

**출처**: [Secure GitHub Webhooks](https://n8n.io/workflows/8906)

```
[Webhook 수신] → [HMAC 검증] → [이벤트 타입 분기] → [처리]
                     ↓
              [x-hub-signature-256 헤더]
```

**HMAC 검증 코드**:
```javascript
const crypto = require('crypto');
const payload = JSON.stringify($input.first().json);
const secret = $env.GITHUB_WEBHOOK_SECRET;
const signature = 'sha256=' + crypto.createHmac('sha256', secret)
  .update(payload)
  .digest('hex');

if (signature !== $input.first().headers['x-hub-signature-256']) {
  throw new Error('Invalid signature');
}
```

---

## Phase별 필요 모듈 매핑

### Phase 1.1: Sentry → Jira

| 필요 모듈 | 상태 | 설명 |
|-----------|------|------|
| `triggers/webhook-secure.json` | 🆕 | Sentry 웹훅 수신 |
| `jira/search-duplicate.json` | 🆕 | fingerprint로 중복 검색 |
| `jira/create-issue.json` | 🆕 | 티켓 생성 |
| `jira/add-comment.json` | 🆕 | 기존 티켓에 코멘트 |
| `ai/analyze-error.json` | ✅ 있음 | GPT-4o 에러 분석 |

### Phase 1.2: GitHub 메트릭 수집

| 필요 모듈 | 상태 | 설명 |
|-----------|------|------|
| `github/webhook-receiver.json` | 🆕 | workflow_run 이벤트 |
| `common/parse-webhook.json` | 🆕 | 메트릭 추출 |
| 저장소 | 🆕 | JSON 파일 또는 DB |

### Phase 1.3: 주간 리포트

| 필요 모듈 | 상태 | 설명 |
|-----------|------|------|
| `triggers/schedule-weekly.json` | 🆕 | 매주 월요일 9AM |
| `ai/summarize-text.json` | 🆕 | 데이터 요약 |
| `slack/weekly-report.json` | 🆕 | Block Kit 포맷 |

---

## 다음 단계

1. **모듈 JSON 파일 생성** - 각 패턴을 실제 n8n 노드로 구현
2. **기존 워크플로 리팩토링** - `sentry-error-orchestrator.json`에 Jira 연동 추가
3. **신규 워크플로 생성** - 메트릭 수집, 주간 리포트
