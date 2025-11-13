#!/bin/bash
#
# add-project.sh - Atlantis 프로젝트 자동 추가 스크립트
#
# 새로운 Terraform 프로젝트를 Atlantis 설정에 자동으로 추가합니다.
#
# Usage:
#   ./scripts/atlantis/add-project.sh <service-name> <category> "<description>"
#
# Example:
#   ./scripts/atlantis/add-project.sh api-server "Application Infrastructure" "API Server - REST API Service"
#
# Categories:
#   - "Shared Infrastructure" (공유 인프라)
#   - "Platform Infrastructure" (플랫폼 인프라)
#   - "Container Registry" (컨테이너 레지스트리)
#   - "Application Infrastructure" (애플리케이션 인프라)
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Arguments
SERVICE_NAME="$1"
CATEGORY="$2"
DESCRIPTION="$3"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ATLANTIS_FILE="$PROJECT_ROOT/atlantis.yaml"

# Validation
if [[ -z "$SERVICE_NAME" ]]; then
    echo -e "${RED}Error: Service name is required${NC}"
    echo "Usage: $0 <service-name> <category> \"<description>\""
    exit 1
fi

if [[ -z "$CATEGORY" ]]; then
    echo -e "${RED}Error: Category is required${NC}"
    echo "Categories:"
    echo "  - Shared Infrastructure"
    echo "  - Platform Infrastructure"
    echo "  - Container Registry"
    echo "  - Application Infrastructure"
    exit 1
fi

if [[ -z "$DESCRIPTION" ]]; then
    echo -e "${YELLOW}Warning: No description provided${NC}"
    DESCRIPTION="$SERVICE_NAME"
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Atlantis Project Addition Tool                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Service Name: ${GREEN}$SERVICE_NAME${NC}"
echo -e "${BLUE}Category:     ${GREEN}$CATEGORY${NC}"
echo -e "${BLUE}Description:  ${GREEN}$DESCRIPTION${NC}\n"

# Check if project already exists
if grep -q "name: $SERVICE_NAME-prod" "$ATLANTIS_FILE"; then
    echo -e "${RED}Error: Project '$SERVICE_NAME-prod' already exists in atlantis.yaml${NC}"
    exit 1
fi

# Check if terraform directory exists
TERRAFORM_DIR="$PROJECT_ROOT/terraform/$SERVICE_NAME"
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${YELLOW}Warning: Terraform directory does not exist: $TERRAFORM_DIR${NC}"
    echo -e "${BLUE}Creating directory...${NC}"
    mkdir -p "$TERRAFORM_DIR"
    echo -e "${GREEN}✓ Directory created${NC}\n"
fi

# Category markers in atlantis.yaml
case "$CATEGORY" in
    "Shared Infrastructure")
        CATEGORY_MARKER="# Shared Infrastructure (공유 인프라)"
        ;;
    "Platform Infrastructure")
        CATEGORY_MARKER="# Platform Infrastructure (플랫폼 인프라)"
        ;;
    "Container Registry")
        CATEGORY_MARKER="# Container Registry (컨테이너 레지스트리)"
        ;;
    "Application Infrastructure")
        CATEGORY_MARKER="# Application Infrastructure (애플리케이션 인프라)"
        ;;
    *)
        echo -e "${RED}Error: Invalid category: $CATEGORY${NC}"
        echo "Valid categories:"
        echo "  - Shared Infrastructure"
        echo "  - Platform Infrastructure"
        echo "  - Container Registry"
        echo "  - Application Infrastructure"
        exit 1
        ;;
esac

# Find category line number
CATEGORY_LINE=$(grep -n "$CATEGORY_MARKER" "$ATLANTIS_FILE" | cut -d: -f1)

if [[ -z "$CATEGORY_LINE" ]]; then
    echo -e "${RED}Error: Category not found in atlantis.yaml: $CATEGORY${NC}"
    exit 1
fi

# Find the next section separator or end of file
NEXT_SECTION=$(awk -v start=$((CATEGORY_LINE + 1)) 'NR >= start && /^  # ===/ {print NR; exit}' "$ATLANTIS_FILE")

if [[ -z "$NEXT_SECTION" ]]; then
    # No next section, append at end
    NEXT_SECTION=$(wc -l < "$ATLANTIS_FILE")
fi

# Generate project configuration
PROJECT_CONFIG=$(cat <<EOF

  # $DESCRIPTION
  - name: $SERVICE_NAME-prod
    dir: terraform/$SERVICE_NAME
    workspace: default
    autoplan:
      when_modified: ["*.tf", "*.tfvars"]
      enabled: true
    apply_requirements: ["approved", "mergeable"]
    workflow: default
EOF
)

# Create backup
BACKUP_FILE="$ATLANTIS_FILE.backup.$(date +%Y%m%d_%H%M%S)"
cp "$ATLANTIS_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}\n"

# Insert project configuration
echo -e "${BLUE}Adding project to atlantis.yaml...${NC}"

# Create temporary file with new configuration
TEMP_FILE=$(mktemp)

# Copy lines up to insertion point
head -n "$NEXT_SECTION" "$ATLANTIS_FILE" > "$TEMP_FILE"

# Add new project configuration
echo "$PROJECT_CONFIG" >> "$TEMP_FILE"

# Copy remaining lines
tail -n +"$((NEXT_SECTION + 1))" "$ATLANTIS_FILE" >> "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$ATLANTIS_FILE"

echo -e "${GREEN}✓ Project added to atlantis.yaml${NC}\n"

# Validate YAML syntax
echo -e "${BLUE}Validating YAML syntax...${NC}"
if command -v python3 &> /dev/null; then
    if python3 -c "import yaml; yaml.safe_load(open('$ATLANTIS_FILE'))" 2>/dev/null; then
        echo -e "${GREEN}✓ YAML syntax is valid${NC}\n"
    else
        echo -e "${RED}✗ YAML syntax error${NC}"
        echo -e "${YELLOW}Restoring backup...${NC}"
        mv "$BACKUP_FILE" "$ATLANTIS_FILE"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Python3 not found, skipping YAML validation${NC}\n"
fi

# Show added configuration
echo -e "${BLUE}Added configuration:${NC}"
echo -e "${GREEN}$PROJECT_CONFIG${NC}\n"

# Next steps
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              NEXT STEPS                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}1. Create Terraform configuration:${NC}"
echo -e "   cd $TERRAFORM_DIR"
echo -e "   # Create main.tf, variables.tf, outputs.tf, etc.\n"

echo -e "${YELLOW}2. Test Terraform configuration:${NC}"
echo -e "   terraform init"
echo -e "   terraform validate"
echo -e "   terraform plan\n"

echo -e "${YELLOW}3. Commit changes:${NC}"
echo -e "   git add atlantis.yaml terraform/$SERVICE_NAME"
echo -e "   git commit -m \"feat: Add $SERVICE_NAME infrastructure\""
echo -e "   git push\n"

echo -e "${YELLOW}4. Create Pull Request:${NC}"
echo -e "   # Atlantis will automatically run 'terraform plan'"
echo -e "   # Review the plan and merge if everything looks good\n"

echo -e "${GREEN}✅ Project '$SERVICE_NAME-prod' successfully added to Atlantis!${NC}\n"

# Cleanup old backups (keep last 5)
echo -e "${BLUE}Cleaning up old backups...${NC}"
ls -t "$ATLANTIS_FILE.backup."* 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
echo -e "${GREEN}✓ Cleanup complete${NC}\n"
