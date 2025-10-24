# 🚨 보안 조치 체크리스트

이 프로젝트의 민감 정보 노출 문제가 발견되어 보안 조치가 수행되었습니다.

## ✅ 완료된 보안 조치

### 1. 파일 보호 상태 확인
- ✅ `.gitignore`에 `*.tfvars` 패턴 존재 확인
- ✅ `.gitignore`에 `*.pem`, `*.key`, `.env` 패턴 존재 확인
- ✅ 민감 정보가 있는 `terraform.tfvars` 파일이 Git 추적되지 않음 확인

### 2. 안전한 템플릿 파일 생성
- ✅ `terraform/atlantis/terraform.tfvars.example` 생성
  - 민감 정보 제거
  - 환경 변수 사용 안내 포함
  - AWS Secrets Manager 사용 가이드 포함

### 3. 보안 가이드 문서 작성
- ✅ `docs/SECURITY.md` 생성
  - 환경 변수 사용 방법
  - AWS Secrets Manager 통합 방법
  - GitHub Actions Secrets 연동 방법
  - 노출 시 대응 절차

## ⚠️ 즉시 수행 필요한 조치 (사용자 액션)

### 🔴 1. GitHub Personal Access Token 폐기 및 재생성

**현재 노출된 토큰:**
```
ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

**조치 방법:**
1. GitHub → Settings → Developer settings → Personal access tokens
2. 위 토큰 찾아서 **Delete** 클릭
3. 새 토큰 생성 (필요한 권한: `repo`, `write:repo_hook`)
4. 새 토큰을 환경 변수로 설정:
   ```bash
   export TF_VAR_github_token="새로운토큰"
   ```

### 🔴 2. GitHub App Private Key 재생성

**조치 방법:**
1. GitHub → Settings → Developer settings → GitHub Apps
2. 해당 App 선택
3. "Generate a private key" 클릭
4. 다운로드된 `.pem` 파일을 안전한 곳에 보관
5. 기존 Private Key를 "Revoke" 클릭
6. 새 키를 환경 변수로 설정:
   ```bash
   export TF_VAR_github_app_private_key="$(base64 < new-private-key.pem)"
   ```

### 🔴 3. Webhook Secret 변경

**조치 방법:**
1. GitHub → Settings → Developer settings → GitHub Apps
2. 해당 App 선택
3. "Webhook secret" 섹션에서 새 시크릿 생성
4. 환경 변수로 설정:
   ```bash
   export TF_VAR_github_webhook_secret="새로운시크릿"
   ```

### 🟡 4. terraform.tfvars 파일 업데이트

**조치 방법:**
```bash
# 1. 기존 tfvars 파일 백업 (민감 정보 확인용)
cp terraform/atlantis/terraform.tfvars terraform/atlantis/terraform.tfvars.backup

# 2. 템플릿에서 새 파일 생성
cp terraform/atlantis/terraform.tfvars.example terraform/atlantis/terraform.tfvars

# 3. 민감하지 않은 정보만 채우기 (VPC ID, Subnet IDs 등)
# 4. 민감 정보는 환경 변수로 설정 (위 단계 참조)

# 5. 백업 파일은 안전하게 삭제
shred -u terraform/atlantis/terraform.tfvars.backup  # Linux
# 또는
rm -P terraform/atlantis/terraform.tfvars.backup     # macOS
```

## 🎯 권장 사항

### Option A: 환경 변수 사용 (간단, 로컬 개발용)

```bash
# .envrc 파일 생성 (DO NOT COMMIT!)
cat > .envrc << 'ENVRC'
export TF_VAR_github_username="your-username"
export TF_VAR_github_token="새GitHub토큰"
export TF_VAR_github_app_id="2099790"
export TF_VAR_github_app_installation_id="89741554"
export TF_VAR_github_app_private_key="$(base64 < path/to/new-key.pem)"
export TF_VAR_github_webhook_secret="새Webhook시크릿"
ENVRC

# 환경 변수 로드
source .envrc

# Terraform 실행
cd terraform/atlantis
terraform plan
```

### Option B: AWS Secrets Manager (프로덕션 권장)

```bash
# 1. 시크릿 저장
aws secretsmanager create-secret \
  --name atlantis/github-token \
  --secret-string '{"token":"새GitHub토큰"}' \
  --region ap-northeast-2

aws secretsmanager create-secret \
  --name atlantis/github-app-private-key \
  --secret-binary fileb://new-private-key.pem \
  --region ap-northeast-2

aws secretsmanager create-secret \
  --name atlantis/webhook-secret \
  --secret-string '{"secret":"새Webhook시크릿"}' \
  --region ap-northeast-2

# 2. Terraform 코드에서 참조 (data.tf 수정 필요)
```

## 📋 검증 체크리스트

수동으로 확인:
- [ ] `git status` - `.tfvars` 파일이 Untracked인지 확인
- [ ] `git ls-files | grep tfvars` - `.auto.tfvars`만 있는지 확인
- [ ] GitHub에서 기존 토큰/키가 폐기되었는지 확인
- [ ] 새 토큰으로 Terraform 실행 성공하는지 확인
- [ ] `terraform.tfvars` 파일에 민감 정보가 없는지 확인

자동 검증:
```bash
# 민감 정보 검색
grep -r "ghp_\|AKIA\|github_app_private_key.*LS0tLS" terraform/ --include="*.tf" --include="*.tfvars"

# 결과가 없어야 정상
```

## 🔄 향후 작업 흐름

**로컬 개발:**
1. `source .envrc` (환경 변수 로드)
2. `terraform plan/apply`
3. `.envrc`는 절대 커밋하지 않기

**CI/CD (GitHub Actions):**
1. GitHub Secrets에 민감 정보 저장
2. Workflow에서 환경 변수로 로드
3. Terraform 실행

**프로덕션 배포:**
1. AWS Secrets Manager에 저장
2. Terraform data source로 참조
3. 안전하게 배포

## 📚 참고 문서

- [docs/SECURITY.md](docs/SECURITY.md) - 상세 보안 가이드
- [terraform/atlantis/terraform.tfvars.example](terraform/atlantis/terraform.tfvars.example) - 설정 템플릿
- [.gitignore](.gitignore) - 보호된 파일 패턴

---

**작성일**: 2025-10-24
**최종 수정**: 2025-10-24
**상태**: 🔴 사용자 액션 필요
