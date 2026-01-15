# Stage RDS 접속 가이드

Stage 환경 데이터베이스에 로컬에서 접근하기 위한 가이드입니다.

---

## 📋 1단계: 필수 도구 설치 (최초 1회)

터미널에서 아래 명령어를 순서대로 실행하세요.

```bash
# AWS CLI 설치
brew install awscli

# Session Manager Plugin 설치
brew install --cask session-manager-plugin
```

설치 확인:
```bash
aws --version
session-manager-plugin --version
```

---

## 🔑 2단계: AWS 자격 증명 설정 (최초 1회)

터미널에서 아래 명령어를 실행하고, 안내에 따라 입력하세요.

```bash
aws configure --profile stage-developer
```

입력할 값:
```
AWS Access Key ID: <팀 리더에게 요청>
AWS Secret Access Key: <팀 리더에게 요청>
Default region name: ap-northeast-2
Default output format: json
```

> ⚠️ **주의**: AWS 크레덴셜은 절대 Git에 커밋하지 마세요. 팀 리더에게 별도로 전달받으세요.

설정 확인:
```bash
AWS_PROFILE=stage-developer aws sts get-caller-identity
```

성공시 아래와 같이 출력됩니다:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXX",
    "Account": "646886795421",
    "Arn": "arn:aws:iam::646886795421:user/developers/frontend-developer"
}
```

---

## 🚀 3단계: 포트 포워딩 실행

### 3-1. 스크립트 다운로드 및 실행 권한 부여

```bash
# 스크립트를 원하는 위치에 저장 후
chmod +x aws-port-forward-stage.sh
```

### 3-2. 포트 포워딩 시작

```bash
AWS_PROFILE=stage-developer ./aws-port-forward-stage.sh
```

성공시 아래와 같이 출력됩니다:
```
========================================
AWS SSM Port Forwarding Setup (STAGE)
========================================

✅ 필수 도구 확인 완료
✅ AWS 인증 완료
✅ Bastion Host 발견
✅ Stage RDS 엔드포인트 발견
✅ Stage RDS 포트 포워딩 시작

포트 포워딩 활성화 완료 (STAGE)
📌 포트 정보:
   - Stage RDS: localhost:13308

종료하려면 Ctrl+C를 누르세요.
```

---

## 🔌 4단계: 데이터베이스 접속

포트 포워딩이 실행된 상태에서 **새 터미널 창**을 열고 접속합니다.

### MySQL CLI로 접속
```bash
mysql -h 127.0.0.1 -P 13308 -u admin -p
```

### DBeaver / DataGrip 등 GUI 도구 설정
| 항목 | 값 |
|------|-----|
| Host | 127.0.0.1 |
| Port | 13308 |
| User | admin |
| Password | (별도 전달) |

---

## ⚠️ 주의사항

1. **포트 포워딩 유지**: DB 접속 중에는 포트 포워딩 터미널을 종료하지 마세요
2. **종료 방법**: 작업이 끝나면 포트 포워딩 터미널에서 `Ctrl+C`
3. **보안**: Access Key는 본인만 사용하세요. 공유하지 마세요.
4. **Stage 전용**: 이 계정은 Stage 환경만 접근 가능합니다.
