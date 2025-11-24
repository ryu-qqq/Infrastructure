#!/bin/bash
# Run Conftest policy validation on Terraform plans
# Usage: ./run-conftest.sh [terraform_directory]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TERRAFORM_DIR="${1:-terraform}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Running Conftest policy validation..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if conftest is installed
if ! command -v conftest &> /dev/null; then
    echo -e "${RED}❌ Conftest is not installed${NC}"
    echo "Please install conftest: https://www.conftest.dev/install/"
    echo ""
    echo "Quick install:"
    echo "  macOS:   brew install conftest"
    echo "  Linux:   curl -L https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_linux_amd64.tar.gz | tar xz && sudo mv conftest /usr/local/bin/"
    exit 1
fi

# Check if OPA is installed (for testing)
if ! command -v opa &> /dev/null; then
    echo -e "${YELLOW}⚠️  OPA is not installed (optional, but recommended for policy testing)${NC}"
    echo "Install OPA: https://www.openpolicyagent.org/docs/latest/#1-download-opa"
fi

cd "${PROJECT_ROOT}"

# Run conftest test on all policy directories
echo ""
echo "📋 Testing policy syntax and unit tests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

POLICY_DIRS=("policies/naming" "policies/tagging" "policies/security_groups" "policies/public_resources")
TEST_FAILED=0

for policy_dir in "${POLICY_DIRS[@]}"; do
    if [ -d "${policy_dir}" ]; then
        echo ""
        echo "Testing ${policy_dir}..."
        if opa test "${policy_dir}"/*.rego -v; then
            echo -e "${GREEN}✅ ${policy_dir} tests passed${NC}"
        else
            echo -e "${RED}❌ ${policy_dir} tests failed${NC}"
            TEST_FAILED=1
        fi
    fi
done

if [ ${TEST_FAILED} -eq 1 ]; then
    echo ""
    echo -e "${RED}❌ Some policy tests failed${NC}"
    exit 1
fi

# Find all Terraform directories
echo ""
echo "🔍 Scanning for Terraform plans..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TERRAFORM_MODULES=$(find "${TERRAFORM_DIR}" -type f -name "*.tf" -exec dirname {} \; | sort -u)

if [ -z "${TERRAFORM_MODULES}" ]; then
    echo -e "${YELLOW}⚠️  No Terraform modules found in ${TERRAFORM_DIR}${NC}"
    exit 0
fi

VALIDATION_FAILED=0
PLAN_COUNT=0

for module_dir in ${TERRAFORM_MODULES}; do
    echo ""
    echo "📦 Module: ${module_dir}"
    echo "─────────────────────────────────────────"

    # Generate Terraform plan
    cd "${PROJECT_ROOT}/${module_dir}"

    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        echo "🔧 Initializing Terraform..."
        if ! terraform init -backend=false > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Skipping ${module_dir} (initialization failed)${NC}"
            continue
        fi
    fi

    # Create plan
    PLAN_FILE="${PROJECT_ROOT}/.terraform-plans/$(echo ${module_dir} | tr '/' '-').tfplan"
    PLAN_JSON="${PLAN_FILE}.json"

    mkdir -p "${PROJECT_ROOT}/.terraform-plans"

    echo "📝 Creating Terraform plan..."
    if terraform plan -out="${PLAN_FILE}" > /dev/null 2>&1; then
        # Convert plan to JSON
        terraform show -json "${PLAN_FILE}" > "${PLAN_JSON}"

        # Run conftest
        cd "${PROJECT_ROOT}"
        echo "🔍 Running policy validation..."

        if conftest test "${PLAN_JSON}" --config conftest.toml; then
            echo -e "${GREEN}✅ Policy validation passed${NC}"
        else
            echo -e "${RED}❌ Policy validation failed${NC}"
            VALIDATION_FAILED=1
        fi

        PLAN_COUNT=$((PLAN_COUNT + 1))

        # Clean up
        rm -f "${PLAN_FILE}" "${PLAN_JSON}"
    else
        echo -e "${YELLOW}⚠️  Skipping ${module_dir} (plan creation failed)${NC}"
    fi
done

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Modules validated: ${PLAN_COUNT}"

if [ ${VALIDATION_FAILED} -eq 1 ]; then
    echo -e "${RED}❌ Policy validation failed${NC}"
    echo ""
    echo "Please review the policy violations above and fix them."
    exit 1
else
    echo -e "${GREEN}✅ All policy validations passed${NC}"
    exit 0
fi
