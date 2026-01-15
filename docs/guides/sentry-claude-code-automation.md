# Sentry → Claude Code 자동 수정 파이프라인

Sentry 에러 알림을 받아 **Claude Code Action**이 자동으로 수정 PR을 생성하는 자동화 파이프라인 가이드입니다.

> **공식 GitHub Action 사용**: [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)

## 아키텍처

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Sentry    │────▶│   Slack     │────▶│    n8n      │
│  (에러발생)  │     │(sentry-alerts)    │ (웹훅수신)   │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │   OpenAI    │
                                        │ (에러 분석)  │
                                        └──────┬──────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │   GitHub    │
                                        │Issue 자동생성│
                                        └──────┬──────┘
                                               │
              ┌────────────────────────────────┘
              │  'claude-code-fix' 라벨 트리거
              ▼
       ┌─────────────┐
       │GitHub Actions│
       │ (트리거)     │
       └──────┬──────┘
              │
              ▼
       ┌─────────────────────────┐
       │ anthropics/claude-code- │
       │     action@v1           │
       │  (공식 GitHub Action)    │
       └──────┬──────────────────┘
              │
              ▼
       ┌─────────────┐
       │  자동 PR    │
       │   생성      │
       └─────────────┘
```

## 사전 준비

### 1. GitHub Secrets 설정

Repository Settings → Secrets and variables → Actions에서 추가:

```
ANTHROPIC_API_KEY=sk-ant-xxxxx  # Anthropic API 키
```

### 2. Sentry Webhook 설정

Sentry 프로젝트 설정 → Integrations → Webhooks:

```
URL: https://your-n8n-instance.com/webhook/sentry-alert
```

또는 Sentry → Slack 연동 후 n8n에서 Slack 이벤트 수신

### 3. n8n 워크플로우 설정

`n8n-workflows/sentry-error-orchestrator.json` 파일을 n8n에 import 후:

1. **OpenAI 자격증명** 설정
2. **GitHub 자격증명** 설정
3. **Slack 자격증명** 설정
4. **Repository 이름** 수정 (Create GitHub Issue 노드)

### 4. GitHub Labels 생성

다음 라벨들을 미리 생성해야 합니다:

| 라벨 | 색상 | 설명 |
|------|------|------|
| `sentry-auto` | `#FF6B6B` | Sentry 자동 생성 이슈 |
| `claude-code-fix` | `#7C3AED` | Claude Code 자동 수정 대상 |
| `priority:critical` | `#DC2626` | 긴급 |
| `priority:high` | `#F59E0B` | 높음 |
| `auto-fix` | `#10B981` | 자동 수정 PR |

## 워크플로우 파일

### n8n 워크플로우
- 위치: `n8n-workflows/sentry-error-orchestrator.json`
- 역할: Sentry → 분석 → GitHub Issue 생성

### GitHub Actions
- 위치: `.github/workflows/claude-code-auto-fix.yml`
- 역할: Issue 생성 시 Claude Code 실행 → PR 생성

## 동작 흐름

### 1단계: 에러 발생
```
Sentry에서 에러 감지 → Slack sentry-alerts 채널로 알림
```

### 2단계: n8n 처리
```
1. Sentry 웹훅 수신
2. OpenAI로 에러 분석 (근본원인, 해결방안)
3. GitHub Issue 자동 생성
4. Slack에 알림
```

### 3단계: Claude Code 실행
```
1. GitHub Actions 트리거 (issue.opened + claude-code-fix 라벨)
2. Claude Code CLI 실행
3. 수정 사항 커밋
4. PR 자동 생성
```

## 주의사항

### Claude Code CLI 제한사항

1. **API 키 필요**: `ANTHROPIC_API_KEY` 환경변수 필수
2. **인터랙티브 모드**: GitHub Actions에서는 `--print` 모드 사용
3. **토큰 제한**: 복잡한 수정은 여러 번 실행 필요할 수 있음

### 보안 고려사항

1. **코드 리뷰 필수**: 자동 생성 PR은 반드시 리뷰 후 머지
2. **민감 정보**: Sentry 알림에 민감 정보 포함 주의
3. **권한 최소화**: GitHub Token 권한은 최소한으로

### 비용

| 서비스 | 예상 비용 |
|--------|----------|
| OpenAI GPT-4o | ~$0.01-0.05/분석 |
| Anthropic Claude | ~$0.01-0.10/수정 |
| GitHub Actions | 무료 (public repo) |

## 대안: Cursor Background Agent

Cursor Pro/Business 사용 시 Background Agent 활용 가능:

```yaml
# .github/workflows/cursor-auto-fix.yml
- name: Trigger Cursor Background Agent
  run: |
    curl -X POST https://api.cursor.sh/v1/background-agent \
      -H "Authorization: Bearer ${{ secrets.CURSOR_API_KEY }}" \
      -d '{
        "task": "Fix error: ${{ steps.extract.outputs.error_message }}",
        "repo": "${{ github.repository }}",
        "branch": "fix/sentry-${{ github.event.issue.number }}"
      }'
```

## 트러블슈팅

### Issue가 생성되지 않음
- n8n 웹훅 URL 확인
- GitHub 자격증명 권한 확인 (repo 스코프 필요)

### Claude Code가 실행되지 않음
- `claude-code-fix` 라벨 확인
- `ANTHROPIC_API_KEY` 시크릿 설정 확인

### PR이 생성되지 않음
- 브랜치 보호 규칙 확인
- GitHub Actions 권한 확인 (Settings → Actions → Workflow permissions)

## 관련 문서

- [Sentry Webhooks](https://docs.sentry.io/product/integrations/integration-platform/webhooks/)
- [Claude Code CLI](https://docs.anthropic.com/claude-code)
- [n8n Documentation](https://docs.n8n.io/)
