#!/bin/bash
#
# check-naming.sh - Terraform Naming Convention Validator
#
# Validates that Terraform resources and variables follow naming conventions.
# Based on docs/governance/infrastructure_governance.md standards.
#
# Naming Rules:
#   - Resource names: kebab-case (lowercase, numbers, hyphens only)
#   - Variable names: snake_case (lowercase, numbers, underscores only)
#   - No uppercase letters, no special characters except - and _
#
# Usage:
#   ./scripts/validators/check-naming.sh [terraform_directory]
#
# Exit Codes:
#   0 - All names follow conventions
#   1 - Naming violations found
#

# Removed set -e to allow warnings without failing
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="${1:-terraform}"
ERRORS=0
WARNINGS=0

# Naming patterns
KEBAB_CASE_PATTERN='^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$'
SNAKE_CASE_PATTERN='^[a-z0-9][a-z0-9_]*[a-z0-9]$|^[a-z0-9]$'

echo -e "${BLUE}📝 Checking naming conventions in Terraform resources...${NC}\n"

# Check if terraform directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${RED}✗ Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

# Function to validate kebab-case
validate_kebab_case() {
    local name=$1
    if [[ ! $name =~ $KEBAB_CASE_PATTERN ]]; then
        return 1
    fi
    return 0
}

# Function to validate snake_case
validate_snake_case() {
    local name=$1
    if [[ ! $name =~ $SNAKE_CASE_PATTERN ]]; then
        return 1
    fi
    return 0
}

# Function to check resource naming
check_resource_naming() {
    local file=$1
    local resource_type=$2
    local resource_name=$3
    local line_number=$4

    if validate_kebab_case "$resource_name"; then
        echo -e "${GREEN}✓ $resource_type.$resource_name (kebab-case)${NC}"
    else
        echo -e "${RED}✗ Error: Invalid resource name${NC}"
        echo -e "  ${YELLOW}Resource: $resource_type.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}Expected: kebab-case (lowercase, numbers, hyphens)${NC}"
        echo -e "  ${YELLOW}Example: my-resource-123${NC}"
        ((ERRORS++))
    fi
}

# Function to check variable naming
check_variable_naming() {
    local file=$1
    local variable_name=$2
    local line_number=$3

    if validate_snake_case "$variable_name"; then
        echo -e "${GREEN}✓ var.$variable_name (snake_case)${NC}"
    else
        echo -e "${RED}✗ Error: Invalid variable name${NC}"
        echo -e "  ${YELLOW}Variable: $variable_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}Expected: snake_case (lowercase, numbers, underscores)${NC}"
        echo -e "  ${YELLOW}Example: my_variable_123${NC}"
        ((ERRORS++))
    fi
}

# Function to check output naming
check_output_naming() {
    local file=$1
    local output_name=$2
    local line_number=$3

    if validate_snake_case "$output_name"; then
        echo -e "${GREEN}✓ output.$output_name (snake_case)${NC}"
    else
        echo -e "${RED}✗ Error: Invalid output name${NC}"
        echo -e "  ${YELLOW}Output: $output_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}Expected: snake_case (lowercase, numbers, underscores)${NC}"
        echo -e "  ${YELLOW}Example: my_output_123${NC}"
        ((ERRORS++))
    fi
}

# Function to check local naming
check_local_naming() {
    local file=$1
    local local_name=$2
    local line_number=$3

    if validate_snake_case "$local_name"; then
        echo -e "${GREEN}✓ local.$local_name (snake_case)${NC}"
    else
        echo -e "${YELLOW}⚠ Warning: Local name should use snake_case${NC}"
        echo -e "  ${YELLOW}Local: $local_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        ((WARNINGS++))
    fi
}

# Check resources
echo -e "${BLUE}🔍 Checking resource names (kebab-case)...${NC}"
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_number=$(echo "$line" | cut -d: -f2)
    resource_line=$(echo "$line" | cut -d: -f3-)

    if [[ $resource_line =~ resource[[:space:]]+\"([^\"]+)\"[[:space:]]+\"([^\"]+)\" ]]; then
        resource_type="${BASH_REMATCH[1]}"
        resource_name="${BASH_REMATCH[2]}"
        check_resource_naming "$file" "$resource_type" "$resource_name" "$line_number"
    fi
done < <(grep -n "^resource\s" $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null || true)

# Check variables
echo -e "\n${BLUE}🔍 Checking variable names (snake_case)...${NC}"
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_number=$(echo "$line" | cut -d: -f2)
    variable_line=$(echo "$line" | cut -d: -f3-)

    if [[ $variable_line =~ variable[[:space:]]+\"([^\"]+)\" ]]; then
        variable_name="${BASH_REMATCH[1]}"
        check_variable_naming "$file" "$variable_name" "$line_number"
    fi
done < <(grep -n "^variable\s" $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null || true)

# Check outputs
echo -e "\n${BLUE}🔍 Checking output names (snake_case)...${NC}"
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_number=$(echo "$line" | cut -d: -f2)
    output_line=$(echo "$line" | cut -d: -f3-)

    if [[ $output_line =~ output[[:space:]]+\"([^\"]+)\" ]]; then
        output_name="${BASH_REMATCH[1]}"
        check_output_naming "$file" "$output_name" "$line_number"
    fi
done < <(grep -n "^output\s" $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null || true)

# Check locals (warnings only)
# NOTE: Disabled due to false positives with JSON keys inside resource blocks
# TODO: Improve parsing to only check actual locals {} block content
# echo -e "\n${BLUE}🔍 Checking local names (snake_case)...${NC}"
# while IFS= read -r line; do
#     file=$(echo "$line" | cut -d: -f1)
#     line_number=$(echo "$line" | cut -d: -f2)
#     locals_line=$(echo "$line" | cut -d: -f3-)
#
#     # Extract local variable names from locals block
#     # This is simplified - may need more robust parsing
#     if [[ $locals_line =~ ([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*= ]]; then
#         local_name="${BASH_REMATCH[1]}"
#         if [[ "$local_name" != "locals" ]]; then
#             check_local_naming "$file" "$local_name" "$line_number"
#         fi
#     fi
# done < <(grep -n "^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*=" $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null | grep -v "variable\|output\|resource\|data\|module" || true)

# Summary
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Naming Convention Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ All names follow conventions!${NC}"
    echo -e "${GREEN}  Resources: kebab-case ✓${NC}"
    echo -e "${GREEN}  Variables/Outputs: snake_case ✓${NC}"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
    echo -e "${YELLOW}💡 See: docs/governance/infrastructure_governance.md${NC}"
    exit 0
else
    echo -e "${RED}✗ Errors: $ERRORS${NC}"
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
    echo -e "\n${YELLOW}📖 Naming Conventions:${NC}"
    echo -e "${YELLOW}  Resources: kebab-case (my-resource-name)${NC}"
    echo -e "${YELLOW}  Variables/Outputs: snake_case (my_variable_name)${NC}"
    echo -e "${YELLOW}💡 See: docs/governance/infrastructure_governance.md${NC}"
    exit 1
fi
