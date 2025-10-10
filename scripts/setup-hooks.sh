#!/bin/bash
#
# setup-hooks.sh - Git Hooks Installation Script
#
# Installs Git hooks for Terraform governance validation.
# Copies hooks from scripts/hooks/ to .git/hooks/
#
# Usage:
#   ./scripts/setup-hooks.sh
#
# Hooks Installed:
#   - pre-commit: Fast validation before commit
#   - pre-push: Comprehensive validation before push
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}🔧 Git Hooks Setup for Terraform${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}\n"

# Get the root directory of the git repository
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo -e "${RED}✗ Error: Not in a git repository${NC}"
    exit 1
fi

cd "$GIT_ROOT"

# Check if .git directory exists
if [[ ! -d ".git" ]]; then
    echo -e "${RED}✗ Error: .git directory not found${NC}"
    exit 1
fi

# Check if scripts/hooks directory exists
if [[ ! -d "scripts/hooks" ]]; then
    echo -e "${RED}✗ Error: scripts/hooks directory not found${NC}"
    echo -e "${YELLOW}💡 Expected structure:${NC}"
    echo -e "${YELLOW}   scripts/hooks/pre-commit${NC}"
    echo -e "${YELLOW}   scripts/hooks/pre-push${NC}"
    exit 1
fi

# Check dependencies
echo -e "${BLUE}📋 Checking dependencies...${NC}\n"

MISSING_DEPS=()

if ! command -v terraform >/dev/null 2>&1; then
    echo -e "${RED}✗ terraform not found${NC}"
    MISSING_DEPS+=("terraform")
else
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4 || terraform version | head -n1 | awk '{print $2}' | sed 's/v//')
    echo -e "${GREEN}✓ terraform $TERRAFORM_VERSION${NC}"
fi

if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}✗ git not found${NC}"
    MISSING_DEPS+=("git")
else
    GIT_VERSION=$(git --version | awk '{print $3}')
    echo -e "${GREEN}✓ git $GIT_VERSION${NC}"
fi

if ! command -v bash >/dev/null 2>&1; then
    echo -e "${RED}✗ bash not found${NC}"
    MISSING_DEPS+=("bash")
else
    BASH_VERSION=$(bash --version | head -n1 | awk '{print $4}')
    echo -e "${GREEN}✓ bash $BASH_VERSION${NC}"
fi

# Optional tools
echo -e "\n${BLUE}📦 Optional tools (recommended):${NC}\n"

if command -v tfsec >/dev/null 2>&1; then
    TFSEC_VERSION=$(tfsec --version 2>&1 | grep -o 'v[0-9.]*' | head -n1)
    echo -e "${GREEN}✓ tfsec $TFSEC_VERSION${NC}"
else
    echo -e "${YELLOW}○ tfsec not installed (optional)${NC}"
    echo -e "${YELLOW}  Install: brew install tfsec${NC}"
    echo -e "${YELLOW}  Or: https://github.com/aquasecurity/tfsec${NC}"
fi

if command -v checkov >/dev/null 2>&1; then
    CHECKOV_VERSION=$(checkov --version 2>&1 | head -n1)
    echo -e "${GREEN}✓ checkov $CHECKOV_VERSION${NC}"
else
    echo -e "${YELLOW}○ checkov not installed (optional)${NC}"
    echo -e "${YELLOW}  Install: pip install checkov${NC}"
fi

# Exit if required dependencies are missing
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo -e "\n${RED}✗ Missing required dependencies: ${MISSING_DEPS[*]}${NC}"
    echo -e "${YELLOW}💡 Install required tools before proceeding${NC}"
    exit 1
fi

# Install hooks
echo -e "\n${BLUE}🔗 Installing Git hooks...${NC}\n"

HOOKS_INSTALLED=0

for hook_file in scripts/hooks/*; do
    if [[ -f "$hook_file" ]]; then
        hook_name=$(basename "$hook_file")
        target_hook=".git/hooks/$hook_name"

        # Backup existing hook if present
        if [[ -f "$target_hook" ]]; then
            backup_file="$target_hook.backup.$(date +%Y%m%d_%H%M%S)"
            echo -e "${YELLOW}⚠ Backing up existing $hook_name to ${backup_file##*/}${NC}"
            mv "$target_hook" "$backup_file"
        fi

        # Copy hook
        cp "$hook_file" "$target_hook"
        chmod +x "$target_hook"

        echo -e "${GREEN}✓ Installed: $hook_name${NC}"
        ((HOOKS_INSTALLED++))
    fi
done

# Verify validators
echo -e "\n${BLUE}✅ Verifying validators...${NC}\n"

VALIDATORS=("check-tags.sh" "check-encryption.sh" "check-naming.sh")
VALIDATORS_OK=0

for validator in "${VALIDATORS[@]}"; do
    validator_path="scripts/validators/$validator"

    if [[ -x "$validator_path" ]]; then
        echo -e "${GREEN}✓ $validator${NC}"
        ((VALIDATORS_OK++))
    else
        echo -e "${RED}✗ $validator not found or not executable${NC}"
    fi
done

# Summary
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Installation Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}\n"

echo -e "${GREEN}✓ Hooks installed: $HOOKS_INSTALLED${NC}"
echo -e "${GREEN}✓ Validators ready: $VALIDATORS_OK/${#VALIDATORS[@]}${NC}"

if [[ $VALIDATORS_OK -eq ${#VALIDATORS[@]} ]]; then
    echo -e "\n${GREEN}✅ Git hooks successfully installed!${NC}\n"

    echo -e "${BLUE}📖 What happens now:${NC}"
    echo -e "  ${YELLOW}On commit:${NC} Fast checks (fmt, secrets, validate)"
    echo -e "  ${YELLOW}On push:${NC} Full validation (tags, encryption, naming)"
    echo -e "\n${BLUE}💡 Tips:${NC}"
    echo -e "  ${YELLOW}• Bypass (emergency): git commit/push --no-verify${NC}"
    echo -e "  ${YELLOW}• Test validators: ./scripts/validators/check-*.sh${NC}"
    echo -e "  ${YELLOW}• Documentation: docs/infrastructure_governance.md${NC}"
    echo -e "  ${YELLOW}• PR workflow: docs/infrastructure_pr.md${NC}"

    echo -e "\n${GREEN}🎉 Ready to develop with governance!${NC}\n"
else
    echo -e "\n${YELLOW}⚠ Warning: Some validators are missing${NC}"
    echo -e "${YELLOW}  Run this script from the repository root${NC}\n"
    exit 1
fi
