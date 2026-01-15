# Automation Workflow Roadmap

> 최종 업데이트: 2025-01-14
> 상태: 계획 단계

## 개요

개발 생산성 및 운영 효율성 향상을 위한 자동화 워크플로 구현 로드맵.
n8n을 중심으로 Sentry, Jira, GitHub, Slack을 연동하여 통합 자동화 파이프라인 구축.

---

## Phase 1: 기본 연동 (즉시 구현 가능)

### 1.1 Sentry → n8n → Jira 티켓 자동 생성

**목표**: Sentry 에러 발생 시 자동으로 Jira 티켓 생성

```
Sentry Alert → Webhook → n8n → Jira 티켓 생성
                           ↓
                      Slack 알림 (선택)
```

**구현 항목**:
- [ ] Sentry Webhook 설정 (Internal Integration)
- [ ] n8n Webhook 트리거 노드 생성
- [ ] 에러 데이터 파싱 및 정규화
- [ ] Jira API 연동 (티켓 생성)
- [ ] 프로젝트별 Jira 프로젝트 매핑 로직
- [ ] 중복 티켓 방지 로직 (fingerprint 기반)

**데이터 매핑**:
```yaml
sentry_to_jira:
  title: "error.title"
  description: |
    ## Error Details
    - **Issue ID**: ${sentry.issue_id}
    - **Project**: ${sentry.project}
    - **Environment**: ${sentry.environment}
    - **First Seen**: ${sentry.first_seen}
    - **Event Count**: ${sentry.count}

    ## Stack Trace
    ${sentry.stacktrace}

    ## Link
    [Sentry Issue](${sentry.url})
  labels: ["sentry-auto", "bug"]
  priority: "Medium"  # 이벤트 수에 따라 동적 조정 가능
```

**예상 소요**: 2-3시간

---

### 1.2 GitHub Actions 빌드/배포 메트릭 수집

**목표**: 빌드 시간, 성공률, 배포 횟수 등 메트릭 수집

```
GitHub Actions → Webhook → n8n → 메트릭 저장 (JSON/DB)
                                      ↓
                                 주간 집계용
```

**구현 항목**:
- [ ] GitHub Webhook 설정 (workflow_run 이벤트)
- [ ] n8n Webhook 트리거 노드
- [ ] 빌드 메트릭 추출 (duration, status, branch)
- [ ] 프로젝트별 메트릭 저장
- [ ] 배포 이벤트 분리 수집

**수집 메트릭**:
```yaml
build_metrics:
  - repository: string
  - workflow_name: string
  - status: success | failure | cancelled
  - duration_seconds: number
  - triggered_by: push | pull_request | schedule | manual
  - branch: string
  - commit_sha: string
  - timestamp: datetime

deployment_metrics:
  - repository: string
  - environment: dev | staging | prod
  - status: success | failure
  - duration_seconds: number
  - deployed_at: datetime
```

**예상 소요**: 2시간

---

### 1.3 주간 Slack 리포트 (n8n Cron)

**목표**: 매주 월요일 아침 자동 리포트 발송

```
n8n Cron (월 9AM) → 데이터 집계 → Slack Block Kit → #dev-reports
```

**구현 항목**:
- [ ] n8n Schedule 트리거 설정 (매주 월요일 09:00)
- [ ] 저장된 메트릭 집계 로직
- [ ] Jira API 쿼리 (완료된 티켓)
- [ ] Sentry API 쿼리 (주간 에러 통계)
- [ ] Slack Block Kit 메시지 포맷팅
- [ ] Slack Webhook/API 전송

**리포트 포맷**:
```markdown
## 📊 주간 개발 리포트 (01/06 ~ 01/12)

### 🔧 빌드 & 배포
| 프로젝트 | 빌드 | 성공률 | 평균 시간 | 배포 |
|----------|------|--------|-----------|------|
| product-hub | 45 | 93% | 4m 32s | 8 |
| auth-hub | 23 | 100% | 2m 15s | 5 |

### 🎫 Jira 티켓
- 완료: 12개 (버그 5, 기능 4, 태스크 3)
- 신규: 8개
- 진행중: 15개

### 🐛 Sentry 에러
- 새 이슈: 3개
- 해결: 5개
- 총 이벤트: 1,247회 (전주 대비 -15%)

### 🔗 Quick Links
- [Jira Board](https://jira.example.com)
- [Sentry Dashboard](https://sentry.io)
- [GitHub Actions](https://github.com/org/repo/actions)
```

**예상 소요**: 3-4시간

---

## Phase 2: 고급 연동 (설정 및 통합 필요)

### 2.1 Claude Code OTEL 설정 및 수집

**목표**: Claude Code 사용량 메트릭 수집

```
Claude Code → OTEL Exporter → Collector → Storage
                                            ↓
                                      n8n 집계용
```

**구현 항목**:
- [ ] Claude Code OTEL 설정 활성화
- [ ] OTEL Collector 설정 (기존 Prometheus 연동 또는 별도)
- [ ] 메트릭 저장소 결정 (Prometheus / CloudWatch / Custom)
- [ ] n8n에서 메트릭 조회 연동
- [ ] 주간 리포트에 통합

**수집 가능 메트릭**:
```yaml
claude_code_otel:
  session_metrics:
    - session_id: string
    - duration_seconds: number
    - tokens_input: number
    - tokens_output: number
    - estimated_cost_usd: number
    - tools_used: string[]
    - files_modified: string[]
    - timestamp: datetime
```

**연관성 분석**:
- Jira 티켓 ID를 세션에 태깅하면 티켓당 AI 비용 추적 가능
- 단, 수동 태깅 필요 (현재 자동 연결 미지원)

**예상 소요**: 4-6시간

---

### 2.2 GitHub Issue 기반 Claude Code 자동 트리거

**목표**: 특정 라벨의 GitHub Issue 생성 시 Claude Code 자동 실행

```
GitHub Issue (label: claude-auto-fix)
        ↓
GitHub Actions Trigger
        ↓
Claude Code Action 실행
        ↓
PR 자동 생성
```

**구현 항목**:
- [ ] GitHub Action 워크플로 작성 (`claude-code-auto-fix.yml`)
- [ ] Issue 라벨 트리거 설정
- [ ] Claude Code GitHub Action 설정
- [ ] PR 템플릿 및 자동 라벨링
- [ ] 실패 시 Issue 코멘트 처리

**워크플로 예시**:
```yaml
name: Claude Code Auto Fix
on:
  issues:
    types: [labeled]

jobs:
  auto-fix:
    if: github.event.label.name == 'claude-auto-fix'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-action@v1
        with:
          prompt: |
            GitHub Issue #${{ github.event.issue.number }}를 분석하고 수정하세요.

            Issue Title: ${{ github.event.issue.title }}
            Issue Body: ${{ github.event.issue.body }}
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          title: "fix: Auto-fix for #${{ github.event.issue.number }}"
          body: |
            Closes #${{ github.event.issue.number }}

            🤖 This PR was automatically generated by Claude Code.
          labels: claude-generated
```

**예상 소요**: 3-4시간

---

### 2.3 Jira + GitHub 통합 지표

**목표**: Jira 티켓과 GitHub PR/커밋 연결 메트릭

```
Jira 티켓 → GitHub PR (티켓 번호 포함) → 연결 메트릭 집계
```

**구현 항목**:
- [ ] GitHub PR/커밋에서 Jira 티켓 번호 파싱
- [ ] Jira 티켓별 PR 수, 코드 변경량 집계
- [ ] 티켓 해결까지 리드타임 계산
- [ ] 주간 리포트에 통합

**메트릭**:
```yaml
ticket_metrics:
  - ticket_id: string
  - prs_count: number
  - commits_count: number
  - lines_added: number
  - lines_removed: number
  - time_to_first_pr: duration
  - time_to_resolution: duration
```

**예상 소요**: 4-5시간

---

## Phase 3: 고급 자동화 (추가 개발 필요)

### 3.1 자동 PR 생성 파이프라인 (End-to-End)

**목표**: Sentry 에러 → 자동 분석 → PR 생성까지 완전 자동화

```
Sentry Error
    ↓
n8n Webhook → Jira 티켓 생성
    ↓
n8n → GitHub Issue 생성 (claude-auto-fix 라벨)
    ↓
GitHub Actions → Claude Code 실행
    ↓
PR 생성 → Slack 알림
    ↓
리뷰 후 머지
```

**구현 항목**:
- [ ] Phase 1, 2 완료 전제
- [ ] n8n에서 GitHub Issue 자동 생성 노드 추가
- [ ] 에러 심각도 기반 자동 트리거 조건 설정
- [ ] PR 생성 후 Slack 알림 연동
- [ ] 실패 케이스 핸들링 및 수동 개입 플로우

**자동 트리거 조건 예시**:
```yaml
auto_trigger_conditions:
  # 자동 수정 시도
  - error_level: error
    event_count: "> 100"
    has_stacktrace: true
    project_config: auto_fix_enabled

  # 수동 검토 요청
  - error_level: critical
    action: create_issue_only
    notify: "#dev-alerts"
```

**예상 소요**: 8-10시간

---

### 3.2 AI 수정 품질 검증 시스템

**목표**: Claude Code 생성 PR의 품질 자동 검증

```
Claude PR 생성
    ↓
자동 테스트 실행 → 실패 시 재시도 또는 수동 전환
    ↓
코드 리뷰 봇 (선택)
    ↓
품질 메트릭 수집 → 피드백 루프
```

**구현 항목**:
- [ ] PR 생성 후 자동 테스트 워크플로
- [ ] 테스트 실패 시 Claude Code 재시도 로직
- [ ] 최대 재시도 횟수 설정 및 수동 전환
- [ ] AI 생성 PR 성공률 메트릭 수집
- [ ] 피드백 루프 (실패 패턴 분석)

**품질 메트릭**:
```yaml
ai_pr_quality:
  - pr_id: string
  - source: sentry_auto | manual_issue
  - test_passed: boolean
  - retry_count: number
  - review_comments: number
  - time_to_merge: duration
  - reverted: boolean
```

**예상 소요**: 10-15시간

---

### 3.3 전체 ROI 대시보드

**목표**: 개발 생산성 통합 대시보드

```
┌─────────────────────────────────────────────────────────┐
│                   ROI Dashboard                          │
├──────────────┬──────────────┬──────────────┬────────────┤
│ Jira Metrics │ GitHub Stats │ AI Metrics   │ Error Rate │
├──────────────┼──────────────┼──────────────┼────────────┤
│ 12 tickets   │ 8 PRs        │ $18.50 cost  │ -15%       │
│ 28 SP        │ +2,340 lines │ 6 AI PRs     │ 3 new      │
└──────────────┴──────────────┴──────────────┴────────────┘
```

**구현 옵션**:
1. **Grafana 대시보드** - 기존 모니터링 스택 활용
2. **Notion 자동 업데이트** - n8n → Notion API
3. **커스텀 웹 대시보드** - 별도 개발 필요

**구현 항목**:
- [ ] 메트릭 데이터 통합 저장소 구성
- [ ] 대시보드 플랫폼 선택
- [ ] 시각화 컴포넌트 설계
- [ ] 실시간 업데이트 연동
- [ ] 주간/월간 트렌드 뷰

**예상 소요**: 15-20시간

---

## 진행 현황 추적

### Phase 1 진행률: 0%
| 항목 | 상태 | 담당 | 완료일 |
|------|------|------|--------|
| 1.1 Sentry → Jira | ⬜ 대기 | - | - |
| 1.2 빌드 메트릭 수집 | ⬜ 대기 | - | - |
| 1.3 주간 리포트 | ⬜ 대기 | - | - |

### Phase 2 진행률: 0%
| 항목 | 상태 | 담당 | 완료일 |
|------|------|------|--------|
| 2.1 Claude OTEL | ⬜ 대기 | - | - |
| 2.2 Issue → Claude | ⬜ 대기 | - | - |
| 2.3 Jira+GitHub 통합 | ⬜ 대기 | - | - |

### Phase 3 진행률: 0%
| 항목 | 상태 | 담당 | 완료일 |
|------|------|------|--------|
| 3.1 E2E 파이프라인 | ⬜ 대기 | - | - |
| 3.2 품질 검증 | ⬜ 대기 | - | - |
| 3.3 ROI 대시보드 | ⬜ 대기 | - | - |

---

## 관련 리소스

### 기존 워크플로
- `n8n-workflows/sentry-error-orchestrator.json` - Sentry 연동 기반
- `n8n-workflows/infra-issue-orchestrator.json` - 인프라 이슈 처리

### 참고 문서
- `docs/guides/sentry-claude-code-automation.md` - Sentry + Claude 연동 가이드
- `docs/guides/monitoring-stack-integration-strategy.md` - 모니터링 전략

### 외부 참고
- [Claude Code GitHub Action](https://github.com/anthropics/claude-code-action)
- [n8n Documentation](https://docs.n8n.io/)
- [Sentry Webhooks](https://docs.sentry.io/product/integrations/integration-platform/webhooks/)
- [Jira REST API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)

---

## 의사결정 로그

| 날짜 | 결정 사항 | 이유 |
|------|----------|------|
| 2025-01-14 | 로드맵 문서 작성 | Phase별 구현 계획 정리 |

---

## 다음 액션

1. [ ] Phase 1.1 Sentry Webhook 설정 시작
2. [ ] n8n 워크플로 템플릿 검토 (`/n8n:search sentry jira`)
3. [ ] Jira 프로젝트 매핑 테이블 정의
