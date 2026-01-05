# 다른 레포 적용 가이드

이 문서는 Infrastructure 프로젝트의 자동화 워크플로우를 다른 레포지토리에 적용하는 단계별 가이드입니다.

## 전체 적용 순서

```
1. Organization Secrets 설정
   ↓
2. 대상 레포에 GitHub Actions 워크플로우 추가
   ↓
3. n8n 레포 설정 추가
   ↓
4. GitHub Webhook 설정
   ↓
5. Slack 채널 매핑
   ↓
6. 테스트 및 검증
```

---

## Phase 1: Organization Secrets 설정

### Jira 관련 (필수)

Organization Settings → Secrets and variables → Actions

```
JIRA_BASE_URL       = https://yourorg.atlassian.net
JIRA_USER_EMAIL     = automation@yourorg.com
JIRA_API_TOKEN      = xxxxxxxxxxxxxxxxx
```

### AWS 관련 (Docker/ECS 사용 시)

```
AWS_ACCESS_KEY_ID     = AKIA...
AWS_SECRET_ACCESS_KEY = xxxxxxxxx
AWS_REGION            = ap-northeast-2
```

### Slack 관련

```
SLACK_WEBHOOK_URL   = https://hooks.slack.com/services/...
SLACK_BOT_TOKEN     = xoxb-...
```

---

## Phase 2: Reusable Workflow 적용

### A. Jira 동기화 적용

대상 레포에 `.github/workflows/sync-jira.yml` 생성:

```yaml
name: Sync to Jira

on:
  issues:
    types: [opened, edited, closed, reopened, labeled]
  issue_comment:
    types: [created]

jobs:
  sync:
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-sync-jira.yml@main
    with:
      jira-project-key: AUTH    # 레포에 맞는 프로젝트 키
    secrets:
      JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
      JIRA_USER_EMAIL: ${{ secrets.JIRA_USER_EMAIL }}
      JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
```

### B. CI/CD 파이프라인 적용

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  build:
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-build-docker.yml@main
    with:
      ecr-repository: authhub-api
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

  deploy:
    needs: build
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-deploy-ecs.yml@main
    with:
      cluster-name: prod-cluster
      service-name: authhub-api
      image-uri: ${{ needs.build.outputs.image-uri }}
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

  notify:
    needs: [build, deploy]
    if: always()
    uses: ryu-qqq/Infrastructure/.github/workflows/reusable-notify-slack.yml@main
    with:
      project-name: AuthHub
      environment: prod
      status: ${{ needs.deploy.result }}
      components: '[{"name":"api","status":"${{ needs.build.result }}"}]'
    secrets:
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Phase 3: n8n 레포 설정 추가

### 레포 설정 테이블

n8n 워크플로우의 "Parse Action" 노드에 레포 설정 추가:

```javascript
const repoConfig = {
  // 기존
  'ryu-qqq/Infrastructure': {
    slackChannel: 'C0A5JRE5K09',
    jiraProject: 'IN',
    conventions: 'terraform'
  },

  // 새로 추가할 레포
  'ryu-qqq/AuthHub': {
    slackChannel: 'C0B6KSF6L10',    // #authhub-alerts
    jiraProject: 'AUTH',
    conventions: 'spring-boot'
  },

  'ryu-qqq/CrawlingHub': {
    slackChannel: 'C0C7LTG7M11',    // #crawlinghub-alerts
    jiraProject: 'CH',
    conventions: 'python'
  }
};
```

### 컨벤션 프롬프트 추가

"Generate Code1/Code2" 노드에 레포별 컨벤션 규칙:

```javascript
const conventionPrompts = {
  'terraform': `/* Terraform 규칙 */`,

  'spring-boot': `
    당신은 Spring Boot 코드 수정 전문가입니다.

    규칙:
    1. Controller: @RestController + @RequestMapping + @Validated
    2. Service: @Service + @Transactional(readOnly=true for queries)
    3. Repository: extends JpaRepository 또는 custom interface
    4. DTO: record 사용 권장, @Builder 어노테이션
    5. Exception: @RestControllerAdvice + custom exceptions
    6. Validation: @Valid + custom validators
    7. Naming: 메서드는 동사로 시작 (get, create, update, delete)
    8. Logging: @Slf4j + log.info/debug/error
  `,

  'python': `
    당신은 Python 코드 수정 전문가입니다.

    규칙:
    1. PEP 8 스타일 가이드 준수
    2. Type hints 필수 (def func(arg: str) -> bool:)
    3. Docstrings: Google style
    4. Import 순서: stdlib → third-party → local
    5. 함수/변수: snake_case
    6. 클래스: PascalCase
    7. 상수: UPPER_SNAKE_CASE
    8. Exception: 구체적인 예외 사용, bare except 금지
  `
};
```

---

## Phase 4: GitHub Webhook 설정

### Issue Flow Webhook

```
Repository → Settings → Webhooks → Add webhook

Payload URL: https://your-n8n-domain/webhook/infra-issue
Content type: application/json
Secret: (선택사항)

Which events:
☑ Issues
☐ Push
☐ Pull requests
☑ Issue comments
```

### PR Review Webhook

```
Payload URL: https://your-n8n-domain/webhook/pr-review
Content type: application/json

Which events:
☐ Issues
☐ Push
☑ Pull request reviews
```

---

## Phase 5: Slack 채널 설정

### 채널 ID 확인 방법

1. Slack에서 채널 우클릭 → "View channel details"
2. 하단에서 Channel ID 복사 (예: C0A5JRE5K09)

### 채널별 용도

| 채널 | 용도 | 알림 종류 |
|------|------|----------|
| #infra-alerts | Infrastructure | Issue, PR Review |
| #authhub-alerts | AuthHub | Issue, PR Review |
| #deploys | 모든 레포 | 배포 결과 |

---

## Phase 6: 테스트 및 검증

### 1. Jira 동기화 테스트

```bash
# GitHub Issue 생성
gh issue create --title "[테스트] Jira 동기화 확인" --body "테스트입니다"

# 확인 사항:
# ✅ Jira 티켓 생성됨
# ✅ GitHub Issue에 Jira 링크 코멘트
# ✅ jira-synced 라벨 추가됨
```

### 2. n8n Webhook 테스트

```bash
# Webhook 테스트 (curl)
curl -X POST https://your-n8n-domain/webhook/infra-issue \
  -H "Content-Type: application/json" \
  -d '{"action":"opened","issue":{"number":1,"title":"Test"}}'

# 확인 사항:
# ✅ n8n 워크플로우 실행됨
# ✅ Slack 메시지 전송됨
```

### 3. PR Review Flow 테스트

1. PR 생성
2. CodeRabbit/Gemini 리뷰 대기
3. Slack 메시지 확인
4. "수정 적용" 버튼 클릭
5. 커밋 생성 확인

---

## 레포별 설정 체크리스트

### ☐ AuthHub

- [ ] `.github/workflows/sync-jira.yml` 생성
- [ ] `.github/workflows/deploy.yml` 생성
- [ ] n8n repoConfig에 AuthHub 추가
- [ ] n8n conventionPrompts에 spring-boot 규칙 추가
- [ ] GitHub Webhook 2개 설정
- [ ] Slack 채널 ID 확인 및 매핑
- [ ] 테스트 Issue 생성 및 동작 확인

### ☐ CrawlingHub

- [ ] `.github/workflows/sync-jira.yml` 생성
- [ ] `.github/workflows/deploy.yml` 생성
- [ ] n8n repoConfig에 CrawlingHub 추가
- [ ] n8n conventionPrompts에 python 규칙 추가
- [ ] GitHub Webhook 2개 설정
- [ ] Slack 채널 ID 확인 및 매핑
- [ ] 테스트 Issue 생성 및 동작 확인

---

## 문제 해결

### Jira 티켓이 생성되지 않을 때

1. Organization Secrets 설정 확인
2. Jira API Token 유효성 확인
3. Jira Project Key 정확한지 확인
4. GitHub Actions 로그 확인

### Slack 메시지가 오지 않을 때

1. Slack App이 해당 채널에 추가되었는지 확인
2. Slack Channel ID가 정확한지 확인
3. n8n 워크플로우 실행 로그 확인

### AI 코드 수정이 적용되지 않을 때

1. OpenAI API 키 유효성 확인
2. GitHub Token 권한 확인 (contents: write)
3. PR Review 이벤트가 올바르게 전달되는지 확인
4. n8n "Parse Fix Files" 노드 로그 확인
