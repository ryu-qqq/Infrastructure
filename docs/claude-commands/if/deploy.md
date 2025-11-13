# Infrastructure Deploy Command

**Task**: Atlantis 설정 변경사항을 배포하고 적용합니다.

## Atlantis 설정 배포 프로세스

Atlantis는 Git 레포지토리의 `atlantis.yaml` 파일을 읽어 프로젝트 설정을 인식합니다. 설정을 변경했다면 반드시 Git에 커밋하고 푸시해야 합니다.

## 배포 단계

### 1단계: 변경사항 확인
```bash
cd /path/to/infrastructure

# Git 상태 확인
git status

# atlantis.yaml 변경사항 확인
git diff atlantis.yaml
```

### 2단계: 변경사항 커밋
```bash
# 스테이징
git add atlantis.yaml

# 커밋
git commit -m "chore: Update Atlantis configuration

- Remove atlantis-test project
- Remove ecr-fileflow-prod project
- Add ecr-prod for unified ECR management"

# 현재 브랜치 확인
git branch --show-current
```

### 3단계: Push 및 PR 생성

**Option A: 메인 브랜치에 직접 푸시** (권장하지 않음)
```bash
git push origin main
```

**Option B: Feature 브랜치로 PR 생성** (권장)
```bash
# Feature 브랜치 생성
git checkout -b config/update-atlantis-projects

# 푸시
git push origin config/update-atlantis-projects

# PR 생성 (GitHub CLI 사용)
gh pr create \
  --title "chore: Update Atlantis project configuration" \
  --body "## Changes
- Removed \`atlantis-test\` project (no terraform directory)
- Removed \`ecr-fileflow-prod\` (consolidated into ecr-prod)
- Added \`ecr-prod\` for unified ECR management at \`terraform/ecr/fileflow\`

## Reason
Cleaned up Atlantis configuration to match actual terraform directory structure.

## Testing
- [ ] Atlantis configuration validated with Python YAML parser
- [ ] All remaining projects have corresponding terraform directories" \
  --base main
```

### 4단계: Atlantis 적용 확인

PR이 머지되면 Atlantis가 자동으로 새 설정을 인식합니다.

```bash
# PR 머지 후 확인
# Atlantis는 main 브랜치의 atlantis.yaml을 자동으로 읽음

# 테스트: 다음 PR에서 atlantis plan 명령어 실행
# 예: terraform/ecr/fileflow 수정 후
atlantis plan -p ecr-prod
```

### 5단계: Atlantis 서버 상태 확인 (선택사항)

```bash
# Atlantis 로그 확인
./scripts/atlantis/monitor-atlantis-logs.sh

# Atlantis Health 체크
./scripts/atlantis/check-atlantis-health.sh

# 설정 리로드가 필요한 경우 (거의 필요 없음)
./scripts/atlantis/restart-atlantis.sh
```

## 빠른 배포 스크립트

아래 내용을 실행하면 자동으로 배포됩니다:

```bash
#!/bin/bash
# Quick deploy atlantis configuration

set -e

cd /path/to/infrastructure

echo "📋 1. Checking changes..."
git diff atlantis.yaml

echo ""
echo "📝 2. Staging changes..."
git add atlantis.yaml

echo ""
echo "💾 3. Committing..."
git commit -m "chore: Update Atlantis configuration

- Remove atlantis-test project
- Remove ecr-fileflow-prod project
- Add ecr-prod for unified ECR management"

echo ""
echo "🔀 4. Creating feature branch..."
BRANCH_NAME="config/atlantis-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH_NAME"

echo ""
echo "🚀 5. Pushing to remote..."
git push origin "$BRANCH_NAME"

echo ""
echo "✅ Done! Next steps:"
echo "   1. Create PR on GitHub"
echo "   2. Review and merge"
echo "   3. Atlantis will automatically use new configuration"
echo ""
echo "Create PR with:"
echo "   gh pr create --base main --head $BRANCH_NAME"
```

## 중요 사항

### ⚠️ Atlantis 설정 적용 시점
- **즉시 적용 안됨**: `atlantis.yaml` 변경 후 Git 푸시 필요
- **적용 시점**: PR 머지 후 Atlantis가 main 브랜치의 설정 읽음
- **재시작 불필요**: 대부분의 경우 Atlantis 재시작 없이 자동 인식

### ✅ 검증 방법
```bash
# 1. YAML 구문 검증
python3 -c "import yaml; yaml.safe_load(open('atlantis.yaml'))"

# 2. 프로젝트 목록 확인
grep "^  - name:" atlantis.yaml

# 3. 디렉토리 존재 확인
for dir in $(grep "dir: terraform" atlantis.yaml | awk '{print $2}'); do
  if [ -d "$dir" ]; then
    echo "✅ $dir"
  else
    echo "❌ $dir - NOT FOUND"
  fi
done
```

### 🔧 문제 해결

**문제**: Atlantis가 새 프로젝트를 인식 안함
```bash
# 해결:
# 1. main 브랜치에 푸시되었는지 확인
git log origin/main --oneline | grep atlantis

# 2. Atlantis 로그 확인
./scripts/atlantis/monitor-atlantis-logs.sh

# 3. 필요시 재시작
./scripts/atlantis/restart-atlantis.sh
```

**문제**: YAML 구문 오류
```bash
# 해결:
# 1. Python으로 검증
python3 -c "import yaml; print(yaml.safe_load(open('atlantis.yaml')))"

# 2. 온라인 YAML 검증기
# https://www.yamllint.com/
```

## 관련 커맨드
- `/if/atlantis` - Atlantis 프로젝트 관리
- `/if/validate` - 모듈 검증
- `/if/module` - 모듈 관리

## 관련 스크립트
- `scripts/atlantis/add-project.sh` - 새 프로젝트 추가
- `scripts/atlantis/check-atlantis-health.sh` - Health 체크
- `scripts/atlantis/monitor-atlantis-logs.sh` - 로그 모니터링
- `scripts/atlantis/restart-atlantis.sh` - 재시작
