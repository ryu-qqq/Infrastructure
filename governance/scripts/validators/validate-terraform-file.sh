#!/bin/bash
#
# validate-terraform-file.sh - Single Terraform File Validator for Claude Sessions
#
# Validates a single Terraform file against governance rules:
#   1. Required tags pattern (merge(local.required_tags))
#   2. KMS encryption (no AES256)
#   3. Naming conventions (kebab-case for resources, snake_case for variables)
#   4. No hardcoded secrets
#
# Usage:
#   ./scripts/validators/validate-terraform-file.sh <file-path>
#
# Exit codes:
#   0 - All checks passed
#   1 - Validation errors found
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FILE_PATH="$1"

# Validation results
ERRORS=0
WARNINGS=0

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    echo -e "${YELLOW}⚠ File not found: $FILE_PATH${NC}"
    exit 0
fi

# Only validate .tf files
if [[ ! "$FILE_PATH" =~ \.tf$ ]]; then
    exit 0
fi

echo -e "${BLUE}🔍 Validating Terraform file: $FILE_PATH${NC}"

# Read file content
FILE_CONTENT=$(cat "$FILE_PATH")

# Check 1: Required Tags Pattern
echo -e "\n${BLUE}📋 Checking required tags pattern...${NC}"

# Find all resource blocks with tags
RESOURCE_COUNT=0
TAGGED_COUNT=0

while IFS= read -r line; do
    if [[ "$line" =~ ^resource[[:space:]]\"([^\"]+)\"[[:space:]]\"([^\"]+)\" ]]; then
        RESOURCE_TYPE="${BASH_REMATCH[1]}"
        RESOURCE_NAME="${BASH_REMATCH[2]}"
        ((RESOURCE_COUNT++))

        # Extract resource block
        RESOURCE_BLOCK=$(awk "/^resource \"$RESOURCE_TYPE\" \"$RESOURCE_NAME\"/,/^}/" "$FILE_PATH")

        # Check if resource has tags
        if echo "$RESOURCE_BLOCK" | grep -q "tags"; then
            # Check if using merge(local.required_tags) pattern
            if echo "$RESOURCE_BLOCK" | tr '\n' ' ' | grep -q "merge.*local\.required_tags"; then
                ((TAGGED_COUNT++))
            else
                echo -e "${RED}✗ $RESOURCE_TYPE.$RESOURCE_NAME: Not using merge(local.required_tags) pattern${NC}"
                ((ERRORS++))
            fi
        fi
    fi
done < "$FILE_PATH"

if [[ $RESOURCE_COUNT -eq 0 ]]; then
    echo -e "${YELLOW}ℹ No resources found in file${NC}"
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ All resources ($TAGGED_COUNT/$RESOURCE_COUNT with tags) use required_tags pattern${NC}"
fi

# Check 2: KMS Encryption
echo -e "\n${BLUE}🔐 Checking KMS encryption...${NC}"

KMS_ERRORS=0

# Check for AES256 usage (should use KMS instead)
if echo "$FILE_CONTENT" | grep -q 'encryption_type\s*=\s*"AES256"'; then
    echo -e "${RED}✗ Error: Found AES256 encryption (use KMS instead)${NC}"
    ((ERRORS++))
    ((KMS_ERRORS++))
fi

# Check ECR encryption
if echo "$FILE_CONTENT" | grep -q 'resource "aws_ecr_repository"'; then
    if ! echo "$FILE_CONTENT" | grep -q 'encryption_type\s*=\s*"KMS"'; then
        echo -e "${RED}✗ Error: ECR repository missing KMS encryption${NC}"
        ((ERRORS++))
        ((KMS_ERRORS++))
    fi
fi

if [[ $KMS_ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ KMS encryption properly configured${NC}"
fi

# Check 3: Naming Conventions
echo -e "\n${BLUE}📝 Checking naming conventions...${NC}"

NAMING_ERRORS=0

# Kebab-case pattern for resource names
KEBAB_CASE_PATTERN='^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$'

# Snake_case pattern for variables
SNAKE_CASE_PATTERN='^[a-z0-9][a-z0-9_]*[a-z0-9]$|^[a-z0-9]$'

# Check resource names in name = "..." declarations
while IFS= read -r line; do
    if [[ "$line" =~ name[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
        NAME="${BASH_REMATCH[1]}"
        # Skip if it's a variable reference or contains variable interpolation
        if [[ ! "$NAME" =~ ^\$ ]] && [[ ! "$NAME" =~ \$\{ ]]; then
            if [[ ! "$NAME" =~ $KEBAB_CASE_PATTERN ]]; then
                echo -e "${RED}✗ Resource name \"$NAME\" should use kebab-case${NC}"
                ((ERRORS++))
                ((NAMING_ERRORS++))
            fi
        fi
    fi
done < "$FILE_PATH"

# Check variable names
while IFS= read -r line; do
    if [[ "$line" =~ ^variable[[:space:]]\"([^\"]+)\" ]]; then
        VAR_NAME="${BASH_REMATCH[1]}"
        if [[ ! "$VAR_NAME" =~ $SNAKE_CASE_PATTERN ]]; then
            echo -e "${RED}✗ Variable \"$VAR_NAME\" should use snake_case${NC}"
            ((ERRORS++))
            ((NAMING_ERRORS++))
        fi
    fi
done < "$FILE_PATH"

# Check local names
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*= ]] && [[ "$FILE_CONTENT" =~ locals[[:space:]]*\{ ]]; then
        LOCAL_NAME="${BASH_REMATCH[1]}"
        if [[ ! "$LOCAL_NAME" =~ $SNAKE_CASE_PATTERN ]]; then
            echo -e "${RED}✗ Local \"$LOCAL_NAME\" should use snake_case${NC}"
            ((ERRORS++))
            ((NAMING_ERRORS++))
        fi
    fi
done < "$FILE_PATH"

if [[ $NAMING_ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ Naming conventions followed${NC}"
fi

# Check 4: No Hardcoded Secrets
echo -e "\n${BLUE}🔒 Checking for hardcoded secrets...${NC}"

SECRET_ERRORS=0

# Dangerous patterns that might contain hardcoded secrets
SENSITIVE_PATTERNS=(
    'password\s*=\s*"[^$]'
    'secret\s*=\s*"[^$]'
    'api_key\s*=\s*"[^$]'
    'access_key\s*=\s*"[^$]'
    'secret_key\s*=\s*"[^$]'
    'token\s*=\s*"[^$]'
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if echo "$FILE_CONTENT" | grep -E "$pattern" >/dev/null 2>&1; then
        MATCHED_LINE=$(echo "$FILE_CONTENT" | grep -E "$pattern" | head -n1)
        echo -e "${RED}✗ Potential hardcoded secret found: ${MATCHED_LINE}${NC}"
        echo -e "${YELLOW}  Use variables or Secrets Manager instead${NC}"
        ((ERRORS++))
        ((SECRET_ERRORS++))
    fi
done

if [[ $SECRET_ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ No hardcoded secrets detected${NC}"
fi

# Summary
echo -e "\n${BLUE}════════════════════════════════════════${NC}"

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✅ All governance checks passed!${NC}"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
    echo -e "${GREEN}✓ No critical errors${NC}"
    exit 0
else
    echo -e "${RED}✗ Errors: $ERRORS${NC}"
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
    echo -e "\n${RED}❌ Governance validation failed${NC}"
    echo -e "${YELLOW}Fix errors above or check .claude/INFRASTRUCTURE_RULES.md${NC}"
    exit 1
fi
