# GitHub App 생성 및 설정 가이드

## 목적
Atlantis가 GitHub PR 이벤트를 자동으로 감지하고 처리할 수 있도록 GitHub App을 생성합니다.

## 1. GitHub App 생성

### 1.1 GitHub Organization 설정 페이지 접근
1. GitHub Organization 페이지로 이동
2. Settings → Developer settings → GitHub Apps
3. "New GitHub App" 버튼 클릭

### 1.2 기본 정보 설정

**GitHub App name**: `atlantis-terraform-automation`

**Description**:
```
Atlantis를 위한 Terraform 자동화 앱. PR에서 Terraform plan/apply를 자동으로 실행합니다.
```

**Homepage URL**:
```
https://github.com/[YOUR_ORG]/infrastructure
```

**Webhook URL**:
```
https://[ATLANTIS_DOMAIN]/events
```
> 참고: Atlantis가 배포된 후 실제 도메인으로 업데이트 필요

**Webhook secret**:
- 강력한 랜덤 문자열 생성 (나중에 Atlantis 설정에서 사용)
- 생성 예시: `openssl rand -hex 32`

## 2. Repository Permissions 설정

다음 권한들을 설정합니다:

### 2.1 Contents
- **Permission**: Read
- **용도**: Repository 코드 읽기, Terraform 파일 접근

### 2.2 Pull requests
- **Permission**: Write
- **용도**: PR에 코멘트 작성, 상태 업데이트

### 2.3 Issues
- **Permission**: Write
- **용도**: Issue에 자동화 알림 작성 (선택사항)

### 2.4 Commit statuses
- **Permission**: Write
- **용도**: Terraform plan/apply 결과를 commit status로 표시

### 2.5 Checks
- **Permission**: Write
- **용도**: GitHub Checks API를 통한 상태 보고

## 3. Subscribe to events

다음 이벤트들을 구독합니다:

- [x] **Pull request**: PR 생성, 업데이트, 닫기
- [x] **Issue comment**: PR 코멘트 (/terraform plan, /terraform apply 등)
- [x] **Pull request review**: PR 리뷰 승인
- [x] **Push**: PR에 새로운 커밋 푸시

## 4. Where can this GitHub App be installed?

- ◉ **Only on this account**: 현재 Organization에만 설치

## 5. Private Key 생성

1. GitHub App 생성 완료 후 설정 페이지로 이동
2. "Private keys" 섹션에서 "Generate a private key" 클릭
3. `.pem` 파일이 자동으로 다운로드됨
4. 이 파일을 안전하게 보관 (절대 Git에 커밋하지 말것!)

## 6. App Installation

1. GitHub App 설정 페이지에서 "Install App" 클릭
2. Organization 선택
3. Repository 접근 권한 설정:
   - ◉ **All repositories** (모든 리포지토리)
   - ○ **Only select repositories** (특정 리포지토리만)
4. "Install" 버튼 클릭

## 7. 중요 정보 수집

GitHub App 생성 후 다음 정보들을 기록합니다:

### 7.1 App ID
- GitHub App 설정 페이지 상단에 표시
- 예시: `123456`

### 7.2 Installation ID
```bash
# GitHub CLI로 확인
gh api /orgs/[YOUR_ORG]/installations

# 또는 웹에서 확인
# Settings → GitHub Apps → Installed GitHub Apps → Configure
# URL에서 installation ID 확인: /settings/installations/[INSTALLATION_ID]
```

### 7.3 Private Key
- 앞서 다운로드한 `.pem` 파일

## 8. AWS Secrets Manager에 저장

Private Key를 AWS Secrets Manager에 안전하게 저장합니다:

```bash
# Private Key 내용을 base64로 인코딩
base64 -i atlantis-app.private-key.pem

# AWS Secrets Manager에 저장
aws secretsmanager create-secret \
  --name atlantis/github-app-private-key \
  --description "Atlantis GitHub App Private Key" \
  --secret-string '{
    "app_id": "123456",
    "installation_id": "12345678",
    "private_key": "[BASE64_ENCODED_PRIVATE_KEY]"
  }' \
  --region ap-northeast-2
```

## 9. Atlantis 설정에 적용

Atlantis 설정 파일에 GitHub App 정보를 추가합니다:

```yaml
# atlantis.yaml
github-app-id: 123456
github-app-key-file: /path/to/private-key.pem
github-app-installation-id: 12345678
```

또는 환경변수로:

```bash
ATLANTIS_GH_APP_ID=123456
ATLANTIS_GH_APP_KEY_FILE=/path/to/private-key.pem
ATLANTIS_GH_APP_INSTALLATION_ID=12345678
```

## 10. 테스트

### 10.1 Contents 권한 테스트
```bash
# GitHub App token 생성 (temporary)
# 이는 실제로 Atlantis가 수행하는 작업입니다
gh api /repos/[YOUR_ORG]/[REPO]/contents/README.md
```

### 10.2 Pull requests 권한 테스트
1. 테스트 브랜치 생성
2. PR 생성
3. Atlantis가 자동으로 코멘트를 달 수 있는지 확인

### 10.3 Webhook 테스트
1. PR에 코멘트 작성: `atlantis plan`
2. Atlantis 로그에서 webhook 이벤트 수신 확인

## 11. 보안 체크리스트

- [ ] Private Key가 Git에 커밋되지 않았는지 확인
- [ ] Private Key가 AWS Secrets Manager에 안전하게 저장됨
- [ ] Webhook secret이 강력한 랜덤 문자열인지 확인
- [ ] GitHub App이 필요한 최소 권한만 가지고 있는지 확인
- [ ] Installation이 필요한 Repository에만 제한되어 있는지 확인

## 12. 문제 해결

### App이 PR에 접근할 수 없는 경우
- Installation ID가 올바른지 확인
- App이 해당 Repository에 설치되어 있는지 확인
- Repository 권한이 올바르게 설정되어 있는지 확인

### Webhook 이벤트가 수신되지 않는 경우
- Webhook URL이 올바른지 확인
- Atlantis 서버가 실행 중인지 확인
- GitHub에서 Webhook delivery 로그 확인

### 권한 오류가 발생하는 경우
- GitHub App의 권한이 올바르게 설정되어 있는지 확인
- Private Key가 만료되지 않았는지 확인
- App ID와 Installation ID가 올바른지 확인

## 참고 자료

- [GitHub Apps 공식 문서](https://docs.github.com/en/developers/apps)
- [Atlantis GitHub App 설정](https://www.runatlantis.io/docs/access-credentials.html#github-app)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
