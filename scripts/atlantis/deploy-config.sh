#!/bin/bash
# Deploy Atlantis Configuration Changes
# Usage: ./scripts/atlantis/deploy-config.sh [commit-message]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cd "$PROJECT_ROOT"

echo -e "${BLUE}🚀 Atlantis Configuration Deployment${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if atlantis.yaml exists
if [ ! -f "atlantis.yaml" ]; then
    echo -e "${RED}❌ Error: atlantis.yaml not found${NC}"
    exit 1
fi

# Step 1: Validate YAML syntax
echo -e "${YELLOW}📋 Step 1: Validating YAML syntax...${NC}"
if python3 -c "import yaml; yaml.safe_load(open('atlantis.yaml'))" 2>/dev/null; then
    echo -e "${GREEN}✅ YAML syntax valid${NC}"
else
    echo -e "${RED}❌ YAML syntax error${NC}"
    echo "Run: python3 -c \"import yaml; yaml.safe_load(open('atlantis.yaml'))\""
    exit 1
fi
echo ""

# Step 2: Check if there are changes
echo -e "${YELLOW}📝 Step 2: Checking for changes...${NC}"
if ! git diff --quiet atlantis.yaml; then
    echo -e "${GREEN}✅ Changes detected in atlantis.yaml${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    git diff atlantis.yaml
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
else
    echo -e "${YELLOW}⚠️  No changes detected in atlantis.yaml${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi
echo ""

# Step 3: Validate project directories
echo -e "${YELLOW}🔍 Step 3: Validating project directories...${NC}"
VALIDATION_FAILED=0
while IFS= read -r dir; do
    dir=$(echo "$dir" | awk '{print $2}')
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✅${NC} $dir"
    else
        echo -e "  ${RED}❌${NC} $dir - NOT FOUND"
        VALIDATION_FAILED=1
    fi
done < <(grep "dir: terraform" atlantis.yaml)

if [ $VALIDATION_FAILED -eq 1 ]; then
    echo ""
    echo -e "${RED}❌ Validation failed: Some directories do not exist${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi
echo ""

# Step 4: Get commit message
echo -e "${YELLOW}💬 Step 4: Preparing commit...${NC}"
if [ -z "$1" ]; then
    COMMIT_MSG="chore: Update Atlantis configuration

Updated atlantis.yaml project definitions"
else
    COMMIT_MSG="$1"
fi

echo "Commit message:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$COMMIT_MSG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Proceed with commit? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi
echo ""

# Step 5: Create feature branch
echo -e "${YELLOW}🔀 Step 5: Creating feature branch...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
BRANCH_NAME="config/atlantis-$(date +%Y%m%d-%H%M%S)"

git checkout -b "$BRANCH_NAME"
echo -e "${GREEN}✅ Created branch: $BRANCH_NAME${NC}"
echo ""

# Step 6: Stage and commit
echo -e "${YELLOW}💾 Step 6: Staging and committing...${NC}"
git add atlantis.yaml

if git commit -m "$COMMIT_MSG"; then
    echo -e "${GREEN}✅ Committed successfully${NC}"
else
    echo -e "${RED}❌ Commit failed${NC}"
    git checkout "$CURRENT_BRANCH"
    git branch -D "$BRANCH_NAME"
    exit 1
fi
echo ""

# Step 7: Push to remote
echo -e "${YELLOW}🚀 Step 7: Pushing to remote...${NC}"
if git push origin "$BRANCH_NAME"; then
    echo -e "${GREEN}✅ Pushed to remote${NC}"
else
    echo -e "${RED}❌ Push failed${NC}"
    git checkout "$CURRENT_BRANCH"
    git branch -D "$BRANCH_NAME"
    exit 1
fi
echo ""

# Step 8: Create PR (if gh CLI available)
echo -e "${YELLOW}📬 Step 8: Creating Pull Request...${NC}"
if command -v gh &> /dev/null; then
    echo "Creating PR with GitHub CLI..."

    PR_TITLE="chore: Update Atlantis configuration"
    PR_BODY="## Changes
- Updated \`atlantis.yaml\` project definitions

## Validation
- [x] YAML syntax validated
- [x] Project directories verified
- [x] Committed and pushed to feature branch

## Next Steps
After merging:
1. Atlantis will automatically reload configuration from main branch
2. Test with: \`atlantis plan -p <project-name>\`"

    if gh pr create \
        --title "$PR_TITLE" \
        --body "$PR_BODY" \
        --base main \
        --head "$BRANCH_NAME"; then
        echo -e "${GREEN}✅ Pull Request created${NC}"
    else
        echo -e "${YELLOW}⚠️  PR creation failed, but branch is pushed${NC}"
        echo "Create PR manually at: https://github.com/ryuqqq/infrastructure/compare/$BRANCH_NAME"
    fi
else
    echo -e "${YELLOW}⚠️  GitHub CLI not installed${NC}"
    echo "Create PR manually at:"
    echo "  https://github.com/ryuqqq/infrastructure/compare/$BRANCH_NAME"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Deployment Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Branch: $BRANCH_NAME"
echo "Status: Pushed to remote"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Review and merge the PR"
echo "2. Atlantis will automatically use the new configuration"
echo "3. No restart required"
echo ""
echo -e "${BLUE}To test:${NC}"
echo "  # In the next PR touching terraform/ecr/fileflow"
echo "  atlantis plan -p ecr-prod"
echo ""
echo -e "${BLUE}To rollback:${NC}"
echo "  git checkout $CURRENT_BRANCH"
echo "  git branch -D $BRANCH_NAME"
echo "  git push origin --delete $BRANCH_NAME"
echo ""
