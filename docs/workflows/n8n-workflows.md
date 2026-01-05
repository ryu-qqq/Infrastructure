# n8n 워크플로우 범용화 가이드

Infrastructure 프로젝트의 n8n 워크플로우를 다른 레포지토리에서 사용하는 방법입니다.

## 워크플로우 아키텍처

```
┌──────────────────────────────────────────────────────────────────┐
│                      n8n Server                                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐     │
│  │           infra-issue-orchestrator.json                  │     │
│  ├─────────────────────────────────────────────────────────┤     │
│  │                                                          │     │
│  │  Webhook ────┬──► Issue Flow (승인/거절/수정요청)        │     │
│  │              │                                           │     │
│  │              └──► PR Review Flow (AI 코드 수정)          │     │
│  │                                                          │     │
│  └─────────────────────────────────────────────────────────┘     │
│                              │                                    │
└──────────────────────────────┼────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
   ┌────────────┐       ┌────────────┐       ┌────────────┐
   │ Infra Repo │       │ AuthHub    │       │ 기타 레포   │
   │ Webhook    │       │ Webhook    │       │ Webhook    │
   └────────────┘       └────────────┘       └────────────┘
```

---

## 현재 지원 기능

### Issue Flow
| 기능 | 설명 | 트리거 |
|------|------|--------|
| 승인 | PR 생성 및 코드 자동 생성 | Slack "승인" 버튼 |
| 거절 | Issue 종료 및 Jira 상태 업데이트 | Slack "거절" 버튼 |
| 수정요청 | Issue에 코멘트 추가 | Slack "수정요청" 버튼 |

### PR Review Flow
| 기능 | 설명 | 트리거 |
|------|------|--------|
| AI 리뷰 분석 | CodeRabbit/Gemini 리뷰 분석 | PR Review 이벤트 |
| 코드 자동 수정 | AI 기반 코드 수정 적용 | Slack "수정 적용" 버튼 |
| 파일 삭제/생성 | 리팩토링 시 파일 재구성 | AI 응답에 따라 |

---

## 다른 레포 연동 방법

### Step 1: GitHub Webhook 설정

```
GitHub Repository
 → Settings
   → Webhooks
     → Add webhook
```

**Issue Flow Webhook:**
```
Payload URL: https://your-n8n-domain/webhook/infra-issue
Content type: application/json
Events: Issues (opened, edited, closed, reopened)
```

**PR Review Webhook:**
```
Payload URL: https://your-n8n-domain/webhook/pr-review
Content type: application/json
Events: Pull request reviews
```

### Step 2: n8n 레포 설정 추가

`infra-issue-orchestrator.json`의 "Parse Action" 노드에 레포별 설정 추가:

```javascript
// 레포별 설정 매핑
const repoConfig = {
  'ryu-qqq/Infrastructure': {
    slackChannel: 'C0A5JRE5K09',
    jiraProject: 'IN',
    conventions: 'terraform'
  },
  'ryu-qqq/AuthHub': {
    slackChannel: 'C0B6KSF6L10',
    jiraProject: 'AUTH',
    conventions: 'spring-boot'
  },
  'ryu-qqq/CrawlingHub': {
    slackChannel: 'C0C7LTG7M11',
    jiraProject: 'CH',
    conventions: 'python'
  }
};

const config = repoConfig[repoName] || {
  slackChannel: 'C0A5JRE5K09',  // 기본 채널
  jiraProject: 'DEV',
  conventions: 'default'
};
```

### Step 3: 컨벤션 프롬프트 설정

"Generate Code1/Code2" 노드에 레포별 컨벤션 규칙 추가:

```javascript
const conventionPrompts = {
  'terraform': `
    규칙:
    1. Required Tags: merge(local.required_tags, {...}) 패턴 필수
    2. KMS Encryption: 고객 관리형 KMS 키 사용 필수
    3. Naming: 리소스는 kebab-case, 변수는 snake_case
    4. Security: 하드코딩된 시크릿 금지
  `,
  'spring-boot': `
    규칙:
    1. Controller: @RestController + @RequestMapping
    2. Service: @Service + @Transactional
    3. Naming: camelCase, 메서드는 동사로 시작
    4. Exception: @ExceptionHandler 사용
    5. Validation: @Valid + @Validated 사용
  `,
  'python': `
    규칙:
    1. PEP 8 스타일 가이드 준수
    2. Type hints 필수
    3. Docstrings (Google style)
    4. 함수는 snake_case, 클래스는 PascalCase
  `,
  'default': `
    일반적인 코드 품질 규칙을 적용하세요.
  `
};
```

---

## 워크플로우 커스터마이징

### Slack 메시지 템플릿 수정

"Slack Review Suggestion" 노드에서 메시지 형식 변경:

```json
{
  "channel": "{{ $json.slackChannel }}",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "🤖 AI 리뷰 분석 - {{ $json.repoName }}"
      }
    }
    // ... 추가 블록
  ]
}
```

### AI 모델 변경

"Generate Code2" 노드에서 모델 변경:

```javascript
// 현재: gpt-4o
// 변경 가능: gpt-4-turbo, claude-3-opus 등
modelId: "gpt-4o"
```

### 파일 처리 로직 수정

"Parse Fix Files" 노드에서 파싱 패턴 수정:

```javascript
// 삭제 파일 패턴
const deleteRegex = /---DELETE:\s*(.+?)---/g;

// 생성/수정 파일 패턴
const fileRegex = /---FILE:\s*(.+?)---\n?([\s\S]*?)---END FILE---/g;
```

---

## 환경 설정

### 필요한 Credentials

n8n에 다음 credentials 설정 필요:

| Credential Type | 용도 |
|-----------------|------|
| GitHub OAuth | GitHub API 접근 |
| Slack API | Slack 메시지/버튼 |
| Jira Software | Jira 이슈 관리 |
| OpenAI | AI 코드 생성 |

### 환경 변수

```bash
# n8n 환경 변수
N8N_WEBHOOK_URL=https://your-n8n-domain
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
SLACK_BOT_TOKEN=xoxb-xxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxx
```

---

## 레포별 Webhook 설정 예시

### Infrastructure (Terraform)
```yaml
webhooks:
  - url: https://n8n.example.com/webhook/infra-issue
    events: [issues]
  - url: https://n8n.example.com/webhook/pr-review
    events: [pull_request_review]
```

### AuthHub (Spring Boot)
```yaml
webhooks:
  - url: https://n8n.example.com/webhook/infra-issue
    events: [issues]
  - url: https://n8n.example.com/webhook/pr-review
    events: [pull_request_review]
```

---

## 트러블슈팅

### Webhook이 동작하지 않을 때

1. GitHub Webhook 설정 확인
   - Payload URL이 올바른지
   - Content type이 `application/json`인지
   - Events가 올바르게 선택되었는지

2. n8n 워크플로우 상태 확인
   - 워크플로우가 Active 상태인지
   - Webhook 노드가 올바르게 설정되었는지

3. 로그 확인
   - GitHub Webhook delivery history
   - n8n 실행 로그

### AI 응답이 파싱되지 않을 때

1. OpenAI 응답 형식 확인
   ```
   ---DELETE: filepath---
   ---FILE: filepath---
   content
   ---END FILE---
   ```

2. "Parse Fix Files" 노드 로직 확인

### Slack 버튼이 작동하지 않을 때

1. Slack App의 Interactivity 설정 확인
2. Request URL이 n8n Webhook URL과 일치하는지 확인
3. Slack App 권한 확인 (chat:write, commands)

---

## 워크플로우 파일 위치

```
infrastructure/
└── n8n-workflows/
    └── infra-issue-orchestrator.json    # 메인 워크플로우
```

### 워크플로우 Import

1. n8n UI에서 Settings → Import from File
2. `infra-issue-orchestrator.json` 선택
3. Credentials 연결
4. Workflow 활성화
