# Slack + AWS Chatbot 설정 가이드

## 개요
AWS CloudWatch Alarms를 Slack으로 받기 위한 AWS Chatbot 설정 가이드입니다.

## 1. Slack 채널 생성

### 옵션 A: 단일 채널 (권장 - 초기)
```
1. Slack 워크스페이스 접속
2. 좌측 사이드바에서 "채널 추가" 클릭
3. 채널 이름: #alerts 또는 #monitoring
4. 설명: AWS CloudWatch 알람 통합 채널
5. 공개 채널로 생성 (팀 전체가 볼 수 있도록)
```

### 옵션 B: 레벨별 채널 (향후 분리 시)
```
- #alerts-critical : P0 즉시 대응
- #alerts-warning  : P1 주의 필요
- #alerts-info     : P2 정보성
```

## 2. Slack 워크스페이스 ID 확인

### 방법 1: Slack 설정에서 확인
```
1. Slack 데스크톱 앱 또는 웹 접속
2. 왼쪽 상단의 워크스페이스 이름 클릭
3. "설정 & 관리" → "워크스페이스 설정" 클릭
4. URL에서 워크스페이스 ID 확인
   예: https://app.slack.com/client/T0XXXXXXXXX/...
   → T0XXXXXXXXX가 워크스페이스 ID
```

### 방법 2: AWS Chatbot 설정 시 자동으로 표시됨

## 3. Slack 채널 ID 확인

```
1. Slack에서 #alerts 채널 접속
2. 채널 이름 클릭 → "이 대화 정보" 선택
3. 하단의 "채널 ID" 복사
   또는
4. 채널에서 우클릭 → "링크 복사"
5. URL에서 채널 ID 추출
   예: https://yourworkspace.slack.com/archives/C0XXXXXXXXX
   → C0XXXXXXXXX가 채널 ID
```

## 4. AWS Chatbot 설정

### AWS Console에서 설정
```
1. AWS Console 접속 → "AWS Chatbot" 검색
2. "Configure new client" 클릭
3. "Slack" 선택
4. "Configure client" 클릭
5. Slack 워크스페이스 권한 승인 (Slack 로그인)
6. "Allow" 클릭하여 AWS Chatbot 앱 승인
```

### Terraform으로 배포
```bash
cd terraform/monitoring

# terraform.tfvars 또는 terraform.tfvars.json에 추가
slack_workspace_id = "T0XXXXXXXXX"  # 위에서 확인한 워크스페이스 ID
slack_channel_id   = "C0YYYYYYYYY"  # 위에서 확인한 채널 ID
enable_chatbot     = true

# 배포
terraform init
terraform plan
terraform apply
```

## 5. 테스트

### SNS 토픽 테스트
```bash
# Critical 알람 테스트
aws sns publish \
  --topic-arn $(cd terraform/monitoring && terraform output -raw sns_topic_critical_arn) \
  --subject "테스트: Critical 알람" \
  --message "이것은 테스트 메시지입니다. ECS 태스크가 모두 중단되었습니다."

# Warning 알람 테스트
aws sns publish \
  --topic-arn $(cd terraform/monitoring && terraform output -raw sns_topic_warning_arn) \
  --subject "테스트: Warning 알람" \
  --message "이것은 테스트 메시지입니다. ECS CPU 사용률이 80%를 초과했습니다."

# Info 알람 테스트
aws sns publish \
  --topic-arn $(cd terraform/monitoring && terraform output -raw sns_topic_info_arn) \
  --subject "테스트: Info 알람" \
  --message "이것은 테스트 메시지입니다. 알람이 정상 상태로 복구되었습니다."
```

### Slack에서 확인
- #alerts 채널에서 3개의 메시지가 수신되는지 확인
- 메시지 포맷 및 가독성 확인

## 6. 향후 채널 분리 (선택사항)

알림이 너무 많아지면 나중에 채널을 분리할 수 있습니다.

### 채널 분리 단계
```
1. Slack에서 #alerts-critical, #alerts-warning, #alerts-info 채널 생성
2. 각 채널 ID 확인
3. terraform/monitoring/variables.tf 수정:
   - slack_channel_id를 slack_channel_ids (map)로 변경
4. chatbot.tf에서 단일 configuration을 3개로 분리
5. terraform apply로 재배포
```

## 7. 트러블슈팅

### Slack에 메시지가 안 옴
```
✓ AWS Chatbot이 Slack 워크스페이스에 설치되어 있는지 확인
✓ 채널에 AWS Chatbot 앱이 추가되어 있는지 확인 (/invite @AWS Chatbot)
✓ terraform apply가 성공적으로 완료되었는지 확인
✓ SNS 토픽 ARN이 올바른지 확인
✓ AWS Chatbot IAM 역할에 필요한 권한이 있는지 확인
```

### 권한 에러
```
✓ Slack 워크스페이스 관리자 권한이 있는지 확인
✓ AWS IAM 권한으로 Chatbot 리소스를 생성할 수 있는지 확인
```

### 채널 ID를 못 찾겠음
```
방법 1: AWS Chatbot Console에서 채널 선택 시 자동으로 표시됨
방법 2: Slack API 토큰으로 channels.list 호출
방법 3: Slack 앱 권한으로 channels:read 스코프 추가 후 확인
```

## 8. 비용

- **AWS Chatbot**: 무료
- **SNS**: 알림당 $0.50/백만 건 (매우 저렴)
- **예상 월 비용**: $0.01 미만 (알림 1000건 기준)

## 9. 참고 자료

- [AWS Chatbot 문서](https://docs.aws.amazon.com/chatbot/)
- [Slack App Directory - AWS Chatbot](https://slack.com/apps/A6L22LZNH-aws-chatbot)
- [Terraform AWS Chatbot 리소스](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/chatbot_slack_channel_configuration)
