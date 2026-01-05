# Slack Module

재사용 가능한 Slack 메시지 전송 모듈

## 모듈 목록

| 모듈 | 설명 |
|------|------|
| `send-message.json` | 다양한 유형의 Slack 메시지 전송 |

---

## send-message.json

### 사용법

메인 워크플로우에서 **Execute Workflow** 노드로 호출:

```
[Your Node] → [Execute Workflow: send-message] → [Next Node]
```

### 입력 파라미터

```json
{
  "messageType": "review_suggestion",  // 메시지 유형 (필수)
  "channel": "C0A5JRE5K09",            // 채널 ID (optional - 프로젝트 설정 사용 가능)
  "data": {                            // 메시지 데이터
    "repoName": "ryu-qqq/Infrastructure",
    "prNumber": 123,
    "prUrl": "https://github.com/...",
    // ... 유형별 추가 데이터
  },
  "projectConfig": {                   // 프로젝트별 커스텀 설정 (optional)
    "channel": "C0CUSTOM01",
    "emoji": ":custom:",
    "color": "#FF0000",
    "name": "CustomProject"
  }
}
```

### 메시지 유형 (messageType)

#### 1. `review_suggestion` - AI 리뷰 분석 결과

```json
{
  "messageType": "review_suggestion",
  "data": {
    "repoName": "ryu-qqq/Infrastructure",
    "prNumber": 117,
    "prUrl": "https://github.com/ryu-qqq/Infrastructure/pull/117",
    "reviewerType": "coderabbit",  // "coderabbit" | "gemini" | 기타
    "reviewer": "CodeRabbit",
    "aiSummary": "변수명 불일치 및 하드코딩된 값 발견",
    "aiItemCount": 3,
    "aiItems": "• var.region → var.aws_region\n• 하드코딩된 account ID",
    "aiRecommendation": "변수 참조 수정 권장",
    "issueNum": 115
  }
}
```

**출력 메시지:**
```
🤖 AI 리뷰 분석 완료
├── 리뷰어: 🐰 CodeRabbit
├── PR: #117
├── 요약: 변수명 불일치 및 하드코딩된 값 발견
├── 수정 필요 항목 (3개): ...
└── [✅ 수정 적용] [🔗 PR 보기] [❌ 무시]
```

#### 2. `apply_success` - 수정 적용 성공

```json
{
  "messageType": "apply_success",
  "data": {
    "prNumber": 117,
    "prUrl": "https://github.com/ryu-qqq/Infrastructure/pull/117",
    "filesChanged": 2,
    "commitMessage": "fix: apply AI review suggestions"
  }
}
```

#### 3. `apply_error` - 수정 적용 실패

```json
{
  "messageType": "apply_error",
  "data": {
    "prNumber": 117,
    "prUrl": "https://github.com/ryu-qqq/Infrastructure/pull/117",
    "error": "Failed to commit: merge conflict"
  }
}
```

#### 4. `notification` - 일반 알림

```json
{
  "messageType": "notification",
  "data": {
    "title": "🚀 배포 완료",
    "message": "Production 환경에 v1.2.3 배포되었습니다.",
    "fields": [
      { "label": "환경", "value": "Production" },
      { "label": "버전", "value": "v1.2.3" }
    ],
    "actionUrl": "https://app.example.com",
    "actionText": "🔗 앱 확인"
  }
}
```

### 출력

```json
{
  "success": true,
  "messageTs": "1234567890.123456",
  "channel": "C0A5JRE5K09",
  "error": null
}
```

### 프로젝트별 기본 설정

모듈에 내장된 프로젝트 설정:

| Repository | Channel | Emoji | Color |
|------------|---------|-------|-------|
| `ryu-qqq/Infrastructure` | `C0A5JRE5K09` | :terraform: | #7B42BC |
| `ryu-qqq/AuthHub` | `C0B6KSF6L10` | :lock: | #2ECC71 |
| `ryu-qqq/CrawlingHub` | `C0C7LTG7M11` | :spider: | #E74C3C |

`data.repoName`을 전달하면 자동으로 해당 프로젝트 설정 적용.

### n8n에서 설정 방법

1. n8n에 `send-message.json` import
2. Slack API credential 연결
3. 메인 워크플로우에서 Execute Workflow 노드 추가
4. Workflow 선택: `[Module] Slack - Send Message`
5. Input Data로 파라미터 전달

---

## 새 프로젝트 추가

`send-message.json`의 `Validate & Route` 노드에서 `defaultProjectConfigs` 수정:

```javascript
const defaultProjectConfigs = {
  // 기존 프로젝트...

  'ryu-qqq/NewProject': {
    channel: 'C0NEWCHANNEL',
    emoji: ':new:',
    color: '#3498DB',
    name: 'NewProject'
  }
};
```
