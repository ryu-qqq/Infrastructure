# n8n Workflow Create Command

새로운 n8n 워크플로를 생성합니다.

## 사용법

```
/n8n:create <workflow-name> [options]
```

## 옵션

- `--type <type>`: 트리거 타입 (webhook|schedule|trigger)
- `--services <services>`: 사용할 서비스 (slack,github,openai 등)

## 예시

```bash
# 기본 웹훅 워크플로
/n8n:create my-alert --type webhook

# Slack + GitHub 연동
/n8n:create error-handler --type webhook --services slack,github

# 스케줄 기반 (매일 실행)
/n8n:create daily-report --type schedule

# AI 분석 포함
/n8n:create smart-alert --type webhook --services slack,openai
```

## 트리거 타입

### webhook
HTTP 요청으로 트리거 (Sentry, GitHub 등 외부 서비스 연동)

```json
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "httpMethod": "POST",
    "path": "workflow-name"
  }
}
```

### schedule
Cron 기반 정기 실행

```json
{
  "type": "n8n-nodes-base.scheduleTrigger",
  "parameters": {
    "rule": {
      "interval": [{ "field": "hours", "hoursInterval": 1 }]
    }
  }
}
```

### trigger
외부 서비스 이벤트 (GitHub, Slack 등 네이티브 트리거)

## 생성되는 파일

```
n8n-workflows/
└── <workflow-name>.json
```

## 워크플로 구조

```json
{
  "name": "Workflow Name",
  "nodes": [
    { "type": "trigger", "name": "Trigger" },
    { "type": "code", "name": "Parse Data" },
    { "type": "action", "name": "Execute" }
  ],
  "connections": {}
}
```

## 서비스별 노드 패턴

### Slack
```json
{
  "type": "n8n-nodes-base.slack",
  "parameters": {
    "channel": "#alerts",
    "text": "={{ $json.message }}"
  }
}
```

### GitHub
```json
{
  "type": "n8n-nodes-base.github",
  "parameters": {
    "resource": "issue",
    "operation": "create"
  }
}
```

### OpenAI
```json
{
  "type": "@n8n/n8n-nodes-langchain.openAi",
  "parameters": {
    "model": "gpt-4o",
    "options": { "temperature": 0.3 }
  }
}
```

## 기존 워크플로 참조

```
n8n-workflows/
├── sentry-error-orchestrator.json   # Sentry → AI → GitHub → Slack
└── infra-issue-orchestrator.json    # 인프라 이슈 처리
```

## 모듈 활용

재사용 가능한 노드 그룹은 `modules/` 디렉토리에서 참조:

```
n8n-workflows/modules/
└── slack/send-message.json
```

## 관련 커맨드

- `/n8n:search` - 템플릿 검색 (먼저 실행 권장)
