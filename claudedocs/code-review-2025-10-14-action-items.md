# Code Review Action Items
# Generated: 2025-10-14

Based on code review report: [code-review-2025-10-14.md](./code-review-2025-10-14.md)

---

## ✅ Completed

### Critical #1: Terraform Naming Convention Violation
- **Status**: FIXED ✅
- **File**: `terraform/monitoring/amg.tf`
- **Change**: 
  - `resource "aws_iam_role" "grafana-workspace"` → `"grafana_workspace"`
  - `aws_iam_role.grafana-workspace.arn` → `aws_iam_role.grafana_workspace.arn`
- **Impact**: Terraform 표준 준수, 코드 일관성 확보
- **Completed**: 2025-10-14 16:15 KST

---

## 🔴 High Priority (This Week)

### Major #2: Archived Directory Structure
- **Status**: TODO
- **Priority**: High
- **Estimated Time**: 30 minutes

**Description**: `atlantis-iam/`, `bootstrap/` 디렉토리를 아카이브 구조로 이동

**Tasks**:
```bash
# 1. 아카이브 디렉토리 생성
mkdir -p terraform/archived

# 2. 디렉토리 이동
mv terraform/atlantis-iam terraform/archived/
mv terraform/bootstrap terraform/archived/

# 3. 아카이브 설명 README 생성
cat > terraform/archived/README.md << 'EOF'
# Archived Terraform Configurations

This directory contains Terraform configurations that are no longer actively maintained.

## Contents
- `atlantis-iam/`: Former Atlantis IAM role configuration (state only)
- `bootstrap/`: Former bootstrap configuration (lock file only)

## Policy
- Do not modify these directories
- State files are preserved for historical reference
- See individual README.md for migration guidance
EOF

# 4. .gitignore 업데이트 (필요시)
echo "terraform/archived/**/*.tfstate" >> .gitignore
echo "terraform/archived/**/*.tfstate.backup" >> .gitignore
```

**Verification**:
```bash
# 구조 확인
tree terraform/archived/

# Git 상태 확인
git status
```

**Related Jira**: 새 서브태스크 생성 권장 (`IN-121-1: Clean up archived directories`)

---

### Major #3: Script Deletion Migration Guide
- **Status**: TODO
- **Priority**: High
- **Estimated Time**: 1 hour

**Description**: 삭제된 3개 스크립트에 대한 마이그레이션 가이드 작성

**Deleted Scripts**:
1. `cleanup-kms.sh` (48 lines) - KMS key cleanup
2. `setup-github-actions-role.sh` (51 lines) - GitHub Actions IAM role setup
3. `update-iam-policy.sh` (18 lines) - IAM policy updates

**Tasks**:
1. **CHANGELOG 추가** (`docs/CHANGELOG_INFRASTRUCTURE.md` 새로 생성):
```markdown
# Infrastructure Repository Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - 2025-10-14

### Removed
- **cleanup-kms.sh**: Replaced with manual AWS Console operations
  - Migration: Use `aws kms list-keys --region ap-northeast-2` and Console for cleanup
  - Rationale: Infrequent operation, manual review preferred for safety
  
- **setup-github-actions-role.sh**: Migrated to Terraform
  - Migration: Use `terraform/atlantis-iam/` or follow [GitHub Actions Setup Guide](./docs/github_actions_setup.md)
  - Rationale: Infrastructure as Code preferred over imperative scripts
  
- **update-iam-policy.sh**: Automated in GitHub Actions workflow
  - Migration: IAM policies now managed via `.github/workflows/terraform-apply-and-deploy.yml`
  - Rationale: CI/CD automation replaces manual updates

### Migration Guide
For teams previously using these scripts:
1. KMS operations: Refer to [AWS KMS Console](https://console.aws.amazon.com/kms)
2. GitHub Actions IAM: Follow Terraform approach in `terraform/atlantis-iam/`
3. Policy updates: Handled automatically by CI/CD pipeline

### Breaking Changes
None - scripts were optional utilities, not part of core workflow.
```

2. **README.md 업데이트** (섹션 추가):
```markdown
## Deprecated Scripts

The following scripts have been removed in this release:

| Script | Removed Date | Replacement |
|--------|--------------|-------------|
| `cleanup-kms.sh` | 2025-10-14 | AWS Console manual cleanup |
| `setup-github-actions-role.sh` | 2025-10-14 | `terraform/atlantis-iam/` |
| `update-iam-policy.sh` | 2025-10-14 | GitHub Actions automation |

For migration details, see [CHANGELOG_INFRASTRUCTURE.md](docs/CHANGELOG_INFRASTRUCTURE.md).
```

**Verification**:
- [ ] CHANGELOG 작성 완료
- [ ] README.md 업데이트
- [ ] 팀원에게 변경사항 공지

**Related Jira**: 새 서브태스크 생성 권장 (`IN-121-2: Document script migration`)

---

### Major #4: Module Version Tagging
- **Status**: TODO
- **Priority**: Medium
- **Estimated Time**: 15 minutes

**Description**: 활성 모듈에 대한 초기 버전 태그 생성

**Modules**:
- `terraform/modules/common-tags/`
- `terraform/modules/cloudwatch-log-group/`

**Tasks**:
```bash
# 1. common-tags 모듈 v1.0.0 태그
git tag -a modules/common-tags/v1.0.0 -m "Release common-tags module v1.0.0

Initial release:
- Standard AWS resource tagging
- Supports Environment, Service, Team, Owner, CostCenter, ManagedBy, Project
- Merge function for custom tags
- Full Terraform validation

Closes IN-121
"

# 2. cloudwatch-log-group 모듈 v1.0.0 태그
git tag -a modules/cloudwatch-log-group/v1.0.0 -m "Release cloudwatch-log-group module v1.0.0

Initial release:
- CloudWatch Log Group creation
- KMS encryption support
- Configurable retention period
- Standard tagging integration

Closes IN-121
"

# 3. 태그 푸시
git push origin modules/common-tags/v1.0.0
git push origin modules/cloudwatch-log-group/v1.0.0

# 4. GitHub Release 생성 (UI에서)
# - Tag: modules/common-tags/v1.0.0
# - Title: Common Tags Module v1.0.0
# - Description: Copy from tag message
```

**Verification**:
```bash
# 로컬 태그 확인
git tag -l "modules/*"

# 원격 태그 확인
git ls-remote --tags origin | grep modules

# 태그 상세 정보
git show modules/common-tags/v1.0.0
```

**GitHub Actions**: GitHub Release 생성 시 자동 릴리스 노트 생성 확인

**Related Jira**: 같은 태스크 내 완료 (`IN-121`)

---

## 🟢 Low Priority (Future Iterations)

### Minor #5: Documentation Language Policy
- **Status**: TODO
- **Priority**: Low
- **Estimated Time**: 30 minutes

**Tasks**:
1. `CONTRIBUTING.md` 생성 (또는 `docs/README.md`에 추가)
2. 한글/영문 문서 정책 명시:
   - 영문: 기술 표준, API, 모듈 README
   - 한글: 가이드, 튜토리얼, 개요
   - 접미사: `*_KR.md`

**Related Jira**: Epic 5 (Documentation Improvement)

---

### Minor #6: Documentation Link Validation
- **Status**: TODO
- **Priority**: Low
- **Estimated Time**: 2 hours

**Tasks**:
1. `markdown-link-check` 설치 및 설정
2. `scripts/validators/check-doc-links.sh` 생성
3. Pre-commit hook 또는 GitHub Actions에 통합
4. 깨진 링크 수정

**Script Example**:
```bash
#!/bin/bash
# scripts/validators/check-doc-links.sh

echo "🔗 Checking documentation links..."

# Install markdown-link-check if not present
if ! command -v markdown-link-check &> /dev/null; then
    echo "Installing markdown-link-check..."
    npm install -g markdown-link-check
fi

# Check all markdown files
find docs/ terraform/modules/ -name "*.md" -print0 | while IFS= read -r -d '' file; do
    echo "Checking: $file"
    markdown-link-check "$file" --quiet --config .markdown-link-check.json
done

echo "✅ Link validation complete!"
```

**Related Jira**: Epic 5

---

### Minor #7: Module Examples Implementation
- **Status**: TODO
- **Priority**: Low
- **Estimated Time**: 4 hours (2 hours per module)

**Description**: 각 모듈에 실제 작동하는 예제 추가

**Structure**:
```
terraform/modules/common-tags/
├── examples/
│   ├── basic/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── advanced/
│       ├── main.tf
│       └── README.md
```

**Tasks per Module**:
1. `examples/basic/` 디렉토리 생성
2. 최소한의 사용 예제 작성 (main.tf)
3. README.md 작성 (실행 방법, 주의사항)
4. `terraform init && terraform plan` 테스트

**Related Jira**: Epic 4 서브태스크로 추가 권장

---

## 📊 Progress Tracking

| Priority | Total | Completed | In Progress | Pending |
|----------|-------|-----------|-------------|---------|
| 🔴 Critical | 1 | 1 | 0 | 0 |
| 🟡 Major | 3 | 0 | 0 | 3 |
| 🟢 Minor | 3 | 0 | 0 | 3 |
| **Total** | **7** | **1** | **0** | **6** |

---

## 🎯 Next Steps

1. **Immediate (Today)**:
   - ✅ Fix Critical #1: Terraform naming (DONE)
   - Review and merge current PR

2. **This Week**:
   - Complete Major #2: Archive directory cleanup
   - Complete Major #3: Script migration guide
   - Complete Major #4: Version tagging

3. **Next Sprint**:
   - Address Minor issues #5-7
   - Plan Epic 5 (Documentation tooling)

---

## 📞 Contact

- **Jira Epic**: [IN-121 - 모듈 디렉터리 구조 설계](https://ryuqqq.atlassian.net/browse/IN-121)
- **Review Report**: [code-review-2025-10-14.md](./code-review-2025-10-14.md)
- **Team**: Infrastructure Team

---

**Last Updated**: 2025-10-14 16:15 KST
