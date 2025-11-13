#!/bin/bash
#
# init-repo-atlantis.sh - Application 레포용 atlantis.yaml 자동 생성 스크립트
#
# Multi-Repo 아키텍처에서 각 애플리케이션 레포에 atlantis.yaml을 생성합니다.
# 중앙 Atlantis 서버는 github.com/ryu-qqq/* 로 모든 레포를 허용하므로,
# 각 레포는 자신의 atlantis.yaml만 가지면 됩니다.
#
# Usage:
#   cd ~/your-app-repo
#   /path/to/infrastructure/scripts/atlantis/init-repo-atlantis.sh
#
# Features:
#   - Terraform 디렉토리 자동 감지
#   - 프로젝트 선택 (대화형)
#   - atlantis.yaml 자동 생성
#   - 베스트 프랙티스 적용
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Current directory (application repo)
REPO_DIR="$(pwd)"
REPO_NAME="$(basename "$REPO_DIR")"
ATLANTIS_FILE="$REPO_DIR/atlantis.yaml"

# Excluded patterns (won't be added to atlantis by default)
EXCLUDE_PATTERNS=("dev" "test" "tmp" "local" "example" "sandbox")

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Atlantis Configuration Generator                   ║${NC}"
echo -e "${BLUE}║       For Application Repositories                       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Repository: ${GREEN}$REPO_NAME${NC}"
echo -e "${CYAN}Directory:  ${GREEN}$REPO_DIR${NC}\n"

# Check if atlantis.yaml already exists
if [[ -f "$ATLANTIS_FILE" ]]; then
    echo -e "${YELLOW}⚠️  atlantis.yaml already exists!${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted.${NC}"
        exit 1
    fi
    # Backup existing file
    cp "$ATLANTIS_FILE" "${ATLANTIS_FILE}.backup"
    echo -e "${GREEN}✓ Backed up to atlantis.yaml.backup${NC}\n"
fi

# Check if terraform directory exists
if [[ ! -d "$REPO_DIR/terraform" ]]; then
    echo -e "${RED}Error: terraform/ directory not found${NC}"
    echo -e "${YELLOW}Expected structure:${NC}"
    echo "  $REPO_NAME/"
    echo "  └── terraform/"
    echo "      ├── ecr/"
    echo "      ├── alb/"
    echo "      └── ecs-service/"
    exit 1
fi

# Scan terraform directories
echo -e "${BLUE}🔍 Scanning terraform directories...${NC}\n"

declare -a PROJECTS=()
declare -a PROJECTS_DESCRIPTIONS=()
declare -a PROJECTS_SELECTED=()

# Find all subdirectories in terraform/
while IFS= read -r -d '' dir; do
    project_name=$(basename "$dir")

    # Check if it's excluded by default
    excluded=false
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$project_name" == *"$pattern"* ]]; then
            excluded=true
            break
        fi
    done

    # Check if it contains .tf files
    if find "$dir" -maxdepth 1 -name "*.tf" -print -quit | grep -q .; then
        PROJECTS+=("$project_name")

        # Try to extract description from README or main.tf
        description=""
        if [[ -f "$dir/README.md" ]]; then
            description=$(head -n 5 "$dir/README.md" | grep -v "^#" | grep -v "^$" | head -n 1 || echo "")
        fi
        if [[ -z "$description" && -f "$dir/main.tf" ]]; then
            description=$(grep -m 1 "^# " "$dir/main.tf" | sed 's/^# //' || echo "")
        fi
        if [[ -z "$description" ]]; then
            description="Terraform configuration for $project_name"
        fi

        PROJECTS_DESCRIPTIONS+=("$description")

        # Default selection (exclude dev/test patterns)
        if [[ "$excluded" == true ]]; then
            PROJECTS_SELECTED+=(false)
            echo -e "  ${YELLOW}⊗${NC} Found: ${CYAN}terraform/$project_name${NC} ${YELLOW}(excluded by default)${NC}"
        else
            PROJECTS_SELECTED+=(true)
            echo -e "  ${GREEN}✓${NC} Found: ${CYAN}terraform/$project_name${NC}"
        fi
    fi
done < <(find "$REPO_DIR/terraform" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    echo -e "${RED}Error: No terraform projects found${NC}"
    exit 1
fi

echo

# Show detected projects with selection
echo -e "${BLUE}📋 Detected Terraform Projects:${NC}\n"

for i in "${!PROJECTS[@]}"; do
    project="${PROJECTS[$i]}"
    description="${PROJECTS_DESCRIPTIONS[$i]}"
    selected="${PROJECTS_SELECTED[$i]}"

    if [[ "$selected" == true ]]; then
        checkbox="${GREEN}[x]${NC}"
    else
        checkbox="${YELLOW}[ ]${NC}"
    fi

    echo -e "  $checkbox ${CYAN}$project${NC}-prod ${YELLOW}(terraform/$project)${NC}"
    echo -e "      $description"
    echo
done

# Confirm selection
echo -e "${BLUE}? Include selected projects in atlantis.yaml?${NC}"
read -p "  (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]?$ ]]; then
    echo -e "${RED}Aborted.${NC}"
    exit 1
fi

# Ask about excluded projects
has_excluded=false
for selected in "${PROJECTS_SELECTED[@]}"; do
    if [[ "$selected" == false ]]; then
        has_excluded=true
        break
    fi
done

if [[ "$has_excluded" == true ]]; then
    echo
    echo -e "${BLUE}? Include excluded projects (dev/test)?${NC}"
    read -p "  (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Include all
        for i in "${!PROJECTS_SELECTED[@]}"; do
            PROJECTS_SELECTED[$i]=true
        done
        echo -e "${GREEN}✓ All projects will be included${NC}"
    fi
fi

# Generate atlantis.yaml
echo
echo -e "${BLUE}📝 Generating atlantis.yaml...${NC}\n"

cat > "$ATLANTIS_FILE" << 'EOF'
# Atlantis Configuration for Application Repository
# Auto-generated by /if/atlantis init
#
# This configuration enables Terraform automation via Pull Requests.
# The central Atlantis server (ECS) monitors this repo and executes
# terraform plan/apply based on this configuration.
#
# Workflow:
#   1. Create PR with terraform changes
#   2. Atlantis automatically runs `terraform plan`
#   3. Review plan output in PR comment
#   4. Approve PR
#   5. Comment `atlantis apply` to execute changes
#
# Documentation:
#   - https://www.runatlantis.io/docs/repo-level-atlantis-yaml.html
#   - /path/to/infrastructure/docs/guides/atlantis-operations-guide.md

version: 3

# Global Settings
automerge: false
delete_source_branch_on_merge: false
parallel_plan: true
parallel_apply: false

projects:
EOF

# Add projects
added_count=0
current_category=""

for i in "${!PROJECTS[@]}"; do
    project="${PROJECTS[$i]}"
    description="${PROJECTS_DESCRIPTIONS[$i]}"
    selected="${PROJECTS_SELECTED[$i]}"

    if [[ "$selected" != true ]]; then
        continue
    fi

    # Determine category
    category=""
    if [[ "$project" == "ecr"* ]]; then
        category="Container Registry"
    elif [[ "$project" == "alb" || "$project" == "nlb" || "$project" == "cloudfront" ]]; then
        category="Load Balancing & CDN"
    elif [[ "$project" == "ecs"* || "$project" == "lambda"* ]]; then
        category="Application Infrastructure"
    elif [[ "$project" == "rds" || "$project" == "dynamodb" || "$project" == "elasticache" ]]; then
        category="Data Storage"
    else
        category="Application Infrastructure"
    fi

    # Add category header if changed
    if [[ "$category" != "$current_category" ]]; then
        cat >> "$ATLANTIS_FILE" << EOF

  # ============================================================================
  # $category
  # ============================================================================
EOF
        current_category="$category"
    fi

    # Add project
    cat >> "$ATLANTIS_FILE" << EOF

  # $description
  - name: $project-prod
    dir: terraform/$project
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default
EOF

    added_count=$((added_count + 1))
    echo -e "  ${GREEN}✓${NC} Added: ${CYAN}$project-prod${NC}"
done

# Add workflows section
cat >> "$ATLANTIS_FILE" << 'EOF'

# Workflow Definition
workflows:
  default:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - apply
EOF

echo
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                 ✅ Success!                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Generated: ${GREEN}$ATLANTIS_FILE${NC}"
echo -e "${CYAN}Projects:  ${GREEN}$added_count${NC}\n"

echo -e "${BLUE}📋 Next Steps:${NC}\n"
echo -e "  1. Review the generated atlantis.yaml:"
echo -e "     ${CYAN}cat atlantis.yaml${NC}\n"
echo -e "  2. Commit and push to GitHub:"
echo -e "     ${CYAN}git add atlantis.yaml${NC}"
echo -e "     ${CYAN}git commit -m \"feat: Add Atlantis configuration\"${NC}"
echo -e "     ${CYAN}git push origin main${NC}\n"
echo -e "  3. Test with a PR:"
echo -e "     ${CYAN}git checkout -b test/atlantis${NC}"
echo -e "     ${CYAN}# Make terraform change${NC}"
echo -e "     ${CYAN}git commit -am \"test: Atlantis integration\"${NC}"
echo -e "     ${CYAN}git push origin test/atlantis${NC}"
echo -e "     ${CYAN}# Create PR on GitHub${NC}\n"
echo -e "  4. Atlantis will automatically comment with plan output\n"

echo -e "${YELLOW}📖 Documentation:${NC}"
echo -e "  - Atlantis Usage: https://www.runatlantis.io/docs/"
echo -e "  - Commands: atlantis plan, atlantis apply"
echo -e "  - Help: atlantis help\n"
