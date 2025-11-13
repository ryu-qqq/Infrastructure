#!/bin/bash
#
# validate-modules.sh - Terraform Module Structure and Validation
#
# 모든 terraform/modules/ 하위 모듈의 구조와 유효성을 검증합니다.
#
# 검증 항목:
#   1. 필수 파일 존재 (main.tf, variables.tf, outputs.tf, versions.tf)
#   2. terraform init 성공
#   3. terraform validate 성공
#   4. 예제 코드 유효성 (examples/)
#   5. 거버넌스 규칙 준수
#
# Usage:
#   ./scripts/validators/validate-modules.sh [module-name]
#
# Exit codes:
#   0 - All checks passed
#   1 - Validation errors found
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODULES_DIR="$PROJECT_ROOT/terraform/modules"

# Counters
TOTAL_MODULES=0
PASSED_MODULES=0
FAILED_MODULES=0
ERRORS=0

# Module to validate (optional argument)
SPECIFIC_MODULE="$1"

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Terraform Module Validation Tool                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"

# Function to check required files
check_required_files() {
    local module_path="$1"
    local module_name="$(basename "$module_path")"
    local errors=0

    echo -e "${BLUE}📁 $module_name - Checking required files...${NC}"

    # Required files
    local required_files=("main.tf" "variables.tf" "outputs.tf" "versions.tf")

    for file in "${required_files[@]}"; do
        if [[ -f "$module_path/$file" ]]; then
            echo -e "${GREEN}  ✓ $file${NC}"
        else
            echo -e "${RED}  ✗ Missing: $file${NC}"
            ((errors++))
        fi
    done

    # Check for README.md
    if [[ -f "$module_path/README.md" ]]; then
        echo -e "${GREEN}  ✓ README.md${NC}"
    else
        echo -e "${YELLOW}  ⚠ Warning: Missing README.md${NC}"
    fi

    # Check for examples directory
    if [[ -d "$module_path/examples" ]]; then
        echo -e "${GREEN}  ✓ examples/ directory${NC}"
    else
        echo -e "${YELLOW}  ⚠ Warning: Missing examples/ directory${NC}"
    fi

    return $errors
}

# Function to validate terraform configuration
validate_terraform() {
    local module_path="$1"
    local module_name="$(basename "$module_path")"
    local errors=0

    echo -e "\n${BLUE}🔍 $module_name - Terraform validation...${NC}"

    # Create temporary directory for testing
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT

    # Copy module to temp directory
    cp -r "$module_path"/* "$temp_dir/"

    cd "$temp_dir"

    # Skip init/validate for common-tags (it's just locals)
    if [[ "$module_name" == "common-tags" ]]; then
        echo -e "${YELLOW}  ⚠ Skipping validation for common-tags (locals only)${NC}"
        return 0
    fi

    # Initialize terraform
    echo -e "${BLUE}  → Running terraform init...${NC}"
    if terraform init -backend=false > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ terraform init succeeded${NC}"
    else
        echo -e "${RED}  ✗ terraform init failed${NC}"
        ((errors++))
        cd - > /dev/null
        return $errors
    fi

    # Validate terraform
    echo -e "${BLUE}  → Running terraform validate...${NC}"
    if terraform validate > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ terraform validate succeeded${NC}"
    else
        echo -e "${RED}  ✗ terraform validate failed:${NC}"
        terraform validate 2>&1 | sed 's/^/    /'
        ((errors++))
    fi

    cd - > /dev/null
    return $errors
}

# Function to validate examples
validate_examples() {
    local module_path="$1"
    local module_name="$(basename "$module_path")"
    local errors=0

    echo -e "\n${BLUE}📝 $module_name - Validating examples...${NC}"

    if [[ ! -d "$module_path/examples" ]]; then
        echo -e "${YELLOW}  ⚠ No examples directory${NC}"
        return 0
    fi

    local example_count=0
    for example_dir in "$module_path/examples"/*; do
        if [[ -d "$example_dir" ]]; then
            local example_name="$(basename "$example_dir")"
            ((example_count++))

            echo -e "${BLUE}  → Checking example: $example_name${NC}"

            # Check for main.tf in example
            if [[ -f "$example_dir/main.tf" ]]; then
                echo -e "${GREEN}    ✓ main.tf exists${NC}"

                # Create temporary directory for example validation
                local temp_dir=$(mktemp -d)
                trap "rm -rf $temp_dir" EXIT

                # Copy example to temp
                cp -r "$example_dir"/* "$temp_dir/"
                cd "$temp_dir"

                # Try to initialize
                if terraform init -backend=false > /dev/null 2>&1; then
                    echo -e "${GREEN}    ✓ terraform init succeeded${NC}"

                    # Try to validate
                    if terraform validate > /dev/null 2>&1; then
                        echo -e "${GREEN}    ✓ terraform validate succeeded${NC}"
                    else
                        echo -e "${RED}    ✗ terraform validate failed${NC}"
                        ((errors++))
                    fi
                else
                    echo -e "${RED}    ✗ terraform init failed${NC}"
                    ((errors++))
                fi

                cd - > /dev/null
            else
                echo -e "${RED}    ✗ Missing main.tf${NC}"
                ((errors++))
            fi
        fi
    done

    if [[ $example_count -eq 0 ]]; then
        echo -e "${YELLOW}  ⚠ No examples found${NC}"
    else
        echo -e "${BLUE}  → Found $example_count example(s)${NC}"
    fi

    return $errors
}

# Function to run governance checks
run_governance_checks() {
    local module_path="$1"
    local module_name="$(basename "$module_path")"
    local errors=0

    echo -e "\n${BLUE}🛡️  $module_name - Governance checks...${NC}"

    # Run validator on all .tf files
    for tf_file in "$module_path"/*.tf; do
        if [[ -f "$tf_file" ]]; then
            local filename="$(basename "$tf_file")"
            echo -e "${BLUE}  → Checking $filename${NC}"

            if "$SCRIPT_DIR/validate-terraform-file.sh" "$tf_file" > /dev/null 2>&1; then
                echo -e "${GREEN}    ✓ Governance checks passed${NC}"
            else
                echo -e "${RED}    ✗ Governance checks failed${NC}"
                "$SCRIPT_DIR/validate-terraform-file.sh" "$tf_file" 2>&1 | sed 's/^/    /'
                ((errors++))
            fi
        fi
    done

    return $errors
}

# Main validation function
validate_module() {
    local module_path="$1"
    local module_name="$(basename "$module_path")"
    local module_errors=0

    echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Module: $module_name${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    # 1. Check required files
    if ! check_required_files "$module_path"; then
        ((module_errors+=$?))
    fi

    # 2. Validate terraform
    if ! validate_terraform "$module_path"; then
        ((module_errors+=$?))
    fi

    # 3. Validate examples
    if ! validate_examples "$module_path"; then
        ((module_errors+=$?))
    fi

    # 4. Run governance checks
    if ! run_governance_checks "$module_path"; then
        ((module_errors+=$?))
    fi

    # Summary for this module
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    if [[ $module_errors -eq 0 ]]; then
        echo -e "${GREEN}✅ Module $module_name: PASSED${NC}"
        ((PASSED_MODULES++))
    else
        echo -e "${RED}❌ Module $module_name: FAILED ($module_errors errors)${NC}"
        ((FAILED_MODULES++))
        ((ERRORS+=module_errors))
    fi
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"

    return $module_errors
}

# Main execution
if [[ -n "$SPECIFIC_MODULE" ]]; then
    # Validate specific module
    MODULE_PATH="$MODULES_DIR/$SPECIFIC_MODULE"
    if [[ ! -d "$MODULE_PATH" ]]; then
        echo -e "${RED}Error: Module '$SPECIFIC_MODULE' not found${NC}"
        exit 1
    fi

    TOTAL_MODULES=1
    validate_module "$MODULE_PATH"
else
    # Validate all modules
    for module_path in "$MODULES_DIR"/*; do
        if [[ -d "$module_path" ]]; then
            ((TOTAL_MODULES++))
            validate_module "$module_path"
        fi
    done
fi

# Final summary
echo -e "\n${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              VALIDATION SUMMARY                           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Total Modules:   $TOTAL_MODULES${NC}"
echo -e "${GREEN}Passed Modules:  $PASSED_MODULES${NC}"
echo -e "${RED}Failed Modules:  $FAILED_MODULES${NC}"
echo -e "${RED}Total Errors:    $ERRORS${NC}\n"

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✅ All modules passed validation!${NC}\n"
    exit 0
else
    echo -e "${RED}❌ Validation failed with $ERRORS error(s)${NC}\n"
    echo -e "${YELLOW}Fix errors above before committing${NC}\n"
    exit 1
fi
