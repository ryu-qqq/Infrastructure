# n8n Template Search Command

n8n.io 커뮤니티에서 워크플로 템플릿을 검색합니다.

## 사용법

```
/n8n:search <keyword>
```

## 예시

```bash
/n8n:search sentry slack          # Sentry → Slack 알림 패턴
/n8n:search github issue          # GitHub Issue 자동화
/n8n:search error notification    # 에러 알림 패턴
/n8n:search ai analysis           # AI 분석 워크플로
/n8n:search webhook automation    # Webhook 기반 자동화
```

## 검색 사이트

```
https://n8n.io/workflows/
```

## 기능별 추천 검색어

| 기능 | 검색어 | 설명 |
|------|--------|------|
| 에러 모니터링 | `sentry slack`, `error alert` | Sentry/에러 → 알림 |
| CI/CD | `github actions`, `deployment` | 배포 알림, PR 자동화 |
| 이슈 관리 | `jira`, `github issues` | 이슈 생성/관리 |
| AI 분석 | `openai`, `chatgpt`, `claude` | LLM 기반 분석 |
| 데이터 파이프라인 | `etl`, `data sync` | 데이터 동기화 |
| 스케줄링 | `cron`, `scheduled` | 정기 실행 작업 |

## 동작

1. WebSearch로 `site:n8n.io/workflows {keyword}` 검색
2. 관련 템플릿 목록 반환
3. 각 템플릿의 노드 구성, 사용 서비스 요약

## 출력 예시

```
🔍 n8n Template Search: "sentry slack"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Found Templates:

1. Sentry Error to Slack Notification
   URL: https://n8n.io/workflows/1234
   Nodes: Webhook → Code → Slack
   Services: Sentry, Slack

2. Sentry Alert with AI Analysis
   URL: https://n8n.io/workflows/5678
   Nodes: Webhook → OpenAI → Slack → GitHub
   Services: Sentry, OpenAI, Slack, GitHub

💡 Tip: /n8n:create <name> 으로 워크플로 생성
```

## 관련 커맨드

- `/n8n:create` - 검색한 패턴 기반으로 워크플로 생성
