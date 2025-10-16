# Pre-commit Hooks 설정 가이드

로컬 개발 환경에서 Terraform 거버넌스 정책을 사전에 검증하는 pre-commit hook 설정 가이드입니다.

## 문제 해결

기존에 GitHub Actions에서만 검증되던 태그 거버넌스 오류를:
```
✗ Error: Missing required tags
  Resource: aws_ecs_cluster.main
  File: terraform/modules/ecs-service/examples/basic/main.tf:49
  Missing: Environment Service Team Owner CostCenter ManagedBy Project
```

**이제 로컬에서 commit 전에 자동으로 검증**할 수 있습니다!

## 사전 요구사항

### 1. pre-commit 설치

```bash
# macOS (Homebrew)
brew install pre-commit

# Python (pip)
pip install pre-commit

# 설치 확인
pre-commit --version
```

### 2. Git hooks path 설정 확인

```bash
# 현재 설정 확인
git config --get core.hooksPath

# pre-commit 사용을 위해 기본값으로 재설정 (선택사항)
git config --unset-all core.hooksPath
```

## 설치

### 1. Pre-commit Hook 설치

```bash
# 프로젝트 루트에서 실행
pre-commit install

# commit-msg hook도 함께 설치 (선택사항)
pre-commit install --hook-type commit-msg
```

설치 성공 시 출력:
```
pre-commit installed at .git/hooks/pre-commit
```

### 2. 기존 Git hooks path를 사용하는 경우

만약 `core.hooksPath`가 설정되어 있어 설치가 거부되면:

**방법 1: Pre-commit을 수동으로 실행**
```bash
# 전체 파일 검증
pre-commit run --all-files

# 특정 hook만 실행
pre-commit run check-tags --all-files
pre-commit run check-encryption --all-files
pre-commit run check-naming --all-files
```

**방법 2: Git alias로 등록**
```bash
git config alias.validate '!pre-commit run --all-files'

# 사용법
git validate
```

## 포함된 검증 항목

### 🏷️ 태그 거버넌스 (check-tags)
모든 Terraform 리소스가 필수 태그를 포함하는지 검증:
- `Environment`, `Service`, `Team`, `Owner`, `CostCenter`, `ManagedBy`, `Project`

### 🔒 암호화 정책 (check-encryption)
데이터 저장 리소스의 암호화 설정 검증:
- S3, RDS, EBS, EFS 등

### 📝 네이밍 컨벤션 (check-naming)
리소스 네이밍이 표준을 따르는지 검증:
- `snake_case` for Terraform resources
- 일관된 프리픽스/서픽스 패턴

### 🔍 Terraform 품질 검사
- **terraform_fmt**: 코드 포맷팅
- **terraform_validate**: 설정 유효성 검증
- **terraform_tflint**: 정적 분석 및 베스트 프랙티스
- **terraform_docs**: 모듈 문서 자동 생성

### 🔐 보안 검사
- **gitleaks**: 시크릿/키 누출 탐지
- **detect-private-key**: Private key 탐지

## 사용법

### 자동 실행 (Commit 시)

Hook이 설치되면 `git commit` 시 자동으로 실행됩니다:

```bash
git add terraform/modules/ecs-service/main.tf
git commit -m "feat: add ECS service module"

# Pre-commit hooks 자동 실행
# ✓ 검증 통과 → 커밋 진행
# ✗ 검증 실패 → 커밋 중단
```

### 수동 실행

```bash
# 전체 파일 검증
pre-commit run --all-files

# 특정 hook만 실행
pre-commit run check-tags

# 특정 파일만 검증
pre-commit run --files terraform/modules/ecs-service/*.tf

# 태그 검증만 빠르게 확인
./scripts/validators/check-tags.sh terraform
```

### 검증 우회 (긴급 상황)

```bash
# pre-commit 검증 건너뛰기 (권장하지 않음)
git commit --no-verify -m "emergency fix"

# 특정 hook만 건너뛰기
SKIP=check-tags git commit -m "skip tags check"
```

## 검증 실패 시 해결 방법

### 태그 누락 오류

```
✗ Error: Missing required tags
  Resource: aws_cloudwatch_log_group.this
  File: terraform/modules/ecs-service/main.tf:2
  Missing: Environment Service Team Owner CostCenter ManagedBy Project
  💡 Use: tags = merge(local.required_tags, {...})
```

**해결:**
```hcl
# Before (잘못된 예)
resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/${var.name}"
}

# After (올바른 예)
resource "aws_cloudwatch_log_group" "this" {
  name = "/ecs/${var.name}"

  tags = merge(
    var.common_tags,  # 또는 local.required_tags
    {
      Name        = "/ecs/${var.name}"
      Description = "ECS service logs"
    }
  )
}
```

### 포맷팅 오류

```
✗ terraform_fmt: Failed
```

**해결:**
```bash
# 자동 수정
terraform fmt -recursive terraform/
```

### TFLint 오류

```
✗ terraform_tflint: Failed
  Warning: aws_instance_invalid_type
```

**해결:**
1. `.tflint.hcl` 설정 확인
2. 지적된 리소스 타입/설정 수정
3. 또는 특정 규칙 비활성화 (정당한 이유가 있는 경우)

## 고급 설정

### 특정 파일/디렉토리 제외

`.pre-commit-config.yaml` 수정:

```yaml
- id: check-tags
  exclude: ^terraform/examples/
```

### Hook 업데이트

```bash
# 최신 버전으로 업데이트
pre-commit autoupdate

# 캐시 정리
pre-commit clean
```

### CI/CD 통합

GitHub Actions에서도 동일한 검증 실행:

```yaml
- name: Run pre-commit
  uses: pre-commit/action@v3.0.0
```

## 트러블슈팅

### "command not found: terraform"

```bash
# Terraform 설치 확인
which terraform

# PATH 설정
export PATH="/usr/local/bin:$PATH"
```

### "hook id 'check-tags' does not exist"

```bash
# 스크립트 실행 권한 확인
chmod +x scripts/validators/*.sh

# pre-commit 재설치
pre-commit uninstall
pre-commit install
```

### 느린 실행 속도

```bash
# 캐시 정리
pre-commit clean

# 특정 hook만 실행
pre-commit run check-tags --files terraform/**/*.tf
```

## 모범 사례

1. **커밋 전 습관화**: 큰 변경 전에 `pre-commit run --all-files` 실행
2. **정기적 업데이트**: `pre-commit autoupdate` 월 1회 실행
3. **팀 공유**: 신규 팀원 온보딩 시 설치 가이드 공유
4. **CI/CD 동기화**: 로컬과 CI/CD의 검증 도구 버전 일치

## 추가 리소스

- [Pre-commit 공식 문서](https://pre-commit.com/)
- [Terraform Pre-commit Hooks](https://github.com/antonbabenko/pre-commit-terraform)
- [프로젝트 Governance 문서](./infrastructure_governance.md)
- [태그 표준](./TAGGING_STANDARDS.md)

## 문의

문제가 발생하면 다음을 확인하세요:
1. Pre-commit 버전: `pre-commit --version`
2. Terraform 버전: `terraform version`
3. Python 버전: `python --version`

또는 프로젝트 이슈로 등록해주세요.
