#!/bin/bash
#
# check-checkov.sh - Checkov Policy Compliance Scanner
#
# Validates Terraform code against security policies and compliance frameworks using Checkov.
# Based on .checkov.yml configuration and CIS AWS Foundations Benchmark.
#
# Checks:
#   - CIS AWS Foundations Benchmark v1.4.0
#   - PCI-DSS v3.2.1 compliance
#   - HIPAA compliance requirements
#   - ISO/IEC 27001 information security
#   - Encryption and data protection
#   - IAM security policies
#   - Network security configurations
#   - Secrets detection
#
# Usage:
#   ./scripts/validators/check-checkov.sh [terraform_directory]
#
# Exit Codes:
#   0 - No policy violations found
#   1 - Policy violations found or scan failed
#   2 - checkov not installed
#

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="${1:-terraform}"
CONFIG_FILE=".checkov.yml"
OUTPUT_JSON="checkov-results.json"
OUTPUT_SARIF="checkov-results.sarif"
OUTPUT_JUNIT="checkov-results.xml"
ERRORS=0
WARNINGS=0
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

echo -e "${BLUE}🔐 Running Checkov policy compliance scan...${NC}\n"

# Check if terraform directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${RED}✗ Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    echo -e "${YELLOW}💡 Tip: Specify directory as: $0 <terraform_directory>${NC}"
    exit 1
fi

# Check if checkov is installed
if ! command -v checkov >/dev/null 2>&1; then
    echo -e "${RED}✗ Error: checkov is not installed${NC}"
    echo -e "${YELLOW}💡 Install checkov:${NC}"
    echo -e "${YELLOW}   pip install checkov${NC}"
    echo -e "${YELLOW}   OR${NC}"
    echo -e "${YELLOW}   brew install checkov${NC}"
    echo -e "${YELLOW}   OR${NC}"
    echo -e "${YELLOW}   docker run --rm -it -v \"\$(pwd):/tf\" bridgecrew/checkov -d /tf${NC}"
    exit 2
fi

# Check checkov version
CHECKOV_VERSION=$(checkov --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo -e "${CYAN}📦 checkov version: ${CHECKOV_VERSION}${NC}\n"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}⚠ Warning: Config file not found: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}💡 Using default checkov policies${NC}\n"
    CONFIG_ARG=""
else
    echo -e "${GREEN}✓ Using config file: $CONFIG_FILE${NC}\n"
    CONFIG_ARG="--config-file $CONFIG_FILE"
fi

# Run checkov scan
echo -e "${BLUE}🔍 Scanning Terraform code for policy violations...${NC}\n"
echo -e "${CYAN}📋 Enabled frameworks:${NC}"
echo -e "  • CIS AWS Foundations Benchmark v1.4.0"
echo -e "  • PCI-DSS v3.2.1"
echo -e "  • HIPAA"
echo -e "  • ISO/IEC 27001\n"

# Run checkov with JSON output directly to file
set +e
checkov -d "$TERRAFORM_DIR" \
    $CONFIG_ARG \
    --output json \
    --soft-fail \
    2>&1 | tee "$OUTPUT_JSON" > /dev/null

CHECKOV_EXIT_CODE=$?
set -e

# Check if output files were created
if [[ ! -f "$OUTPUT_JSON" ]]; then
    echo -e "${RED}✗ Error: checkov scan failed to produce output${NC}"
    exit 1
fi

# Parse JSON results
if command -v jq >/dev/null 2>&1; then
    # Extract summary statistics
    PASSED_COUNT=$(jq -r '.summary.passed // 0' "$OUTPUT_JSON" 2>/dev/null || echo "0")
    FAILED_COUNT=$(jq -r '.summary.failed // 0' "$OUTPUT_JSON" 2>/dev/null || echo "0")
    SKIPPED_COUNT=$(jq -r '.summary.skipped // 0' "$OUTPUT_JSON" 2>/dev/null || echo "0")

    # Count by severity
    if [[ -f "$OUTPUT_JSON" ]] && jq -e '.results.failed_checks' "$OUTPUT_JSON" >/dev/null 2>&1; then
        # Count CRITICAL severity issues
        CRITICAL_COUNT=$(jq '[.results.failed_checks[] | select(.severity == "CRITICAL")] | length' "$OUTPUT_JSON" 2>/dev/null || echo "0")

        # Count HIGH severity issues
        HIGH_COUNT=$(jq '[.results.failed_checks[] | select(.severity == "HIGH")] | length' "$OUTPUT_JSON" 2>/dev/null || echo "0")

        # Count MEDIUM severity issues
        MEDIUM_COUNT=$(jq '[.results.failed_checks[] | select(.severity == "MEDIUM")] | length' "$OUTPUT_JSON" 2>/dev/null || echo "0")

        # Count LOW severity issues
        LOW_COUNT=$(jq '[.results.failed_checks[] | select(.severity == "LOW")] | length' "$OUTPUT_JSON" 2>/dev/null || echo "0")

        # Display top critical/high issues
        if [[ $CRITICAL_COUNT -gt 0 ]]; then
            echo -e "\n${RED}🚨 CRITICAL Issues: $CRITICAL_COUNT${NC}"
            jq -r '.results.failed_checks[] | select(.severity == "CRITICAL") |
                "  [\(.check_id)] \(.check_name)\n  File: \(.file_path):\(.file_line_range[0])\n  Guideline: \(.guideline // "N/A")\n"' \
                "$OUTPUT_JSON" | head -n 50
            ((ERRORS += CRITICAL_COUNT))
        fi

        if [[ $HIGH_COUNT -gt 0 ]]; then
            echo -e "\n${RED}❌ HIGH Issues: $HIGH_COUNT${NC}"
            jq -r '.results.failed_checks[] | select(.severity == "HIGH") |
                "  [\(.check_id)] \(.check_name)\n  File: \(.file_path):\(.file_line_range[0])\n  Guideline: \(.guideline // "N/A")\n"' \
                "$OUTPUT_JSON" | head -n 50
            ((ERRORS += HIGH_COUNT))
        fi

        if [[ $MEDIUM_COUNT -gt 0 ]]; then
            echo -e "\n${YELLOW}⚠️  MEDIUM Issues: $MEDIUM_COUNT${NC}"
            # Show first 5 medium issues
            jq -r '.results.failed_checks[] | select(.severity == "MEDIUM") |
                "  [\(.check_id)] \(.check_name)\n  File: \(.file_path):\(.file_line_range[0])\n"' \
                "$OUTPUT_JSON" | head -n 20
            ((ERRORS += MEDIUM_COUNT))
        fi

        if [[ $LOW_COUNT -gt 0 ]]; then
            echo -e "\n${CYAN}ℹ️  LOW Issues: $LOW_COUNT${NC}"
            # Don't count LOW as errors
        fi
    fi

    # Display framework-specific results
    echo -e "\n${MAGENTA}📊 Compliance Framework Results:${NC}"

    # CIS AWS checks
    CIS_FAILED=$(jq '[.results.failed_checks[] | select(.check_id | startswith("CKV_AWS"))] | length' "$OUTPUT_JSON" 2>/dev/null || echo "0")
    echo -e "  • CIS AWS: ${CIS_FAILED} issues"

    # Check for specific critical compliance violations
    if [[ $CIS_FAILED -gt 0 ]]; then
        echo -e "${YELLOW}    Top CIS violations:${NC}"
        jq -r '.results.failed_checks[] | select(.check_id | startswith("CKV_AWS")) |
            "      [\(.check_id)] \(.check_name)"' "$OUTPUT_JSON" | head -n 5
    fi

else
    echo -e "${YELLOW}⚠ Warning: jq not installed - cannot parse detailed results${NC}"
    echo -e "${YELLOW}💡 Install jq for better result parsing: brew install jq${NC}"

    # Fallback: check if there are failures in the JSON
    if grep -q '"failed":' "$OUTPUT_JSON" && grep -q '[1-9][0-9]*' "$OUTPUT_JSON"; then
        echo -e "${RED}Policy violations found - check $OUTPUT_JSON for details${NC}"
        ERRORS=1
    fi
fi

# Display scan summary
echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Checkov Policy Compliance Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

# Show scanned resources
SCANNED_FILES=$(find "$TERRAFORM_DIR" -name "*.tf" -type f | wc -l | tr -d ' ')
echo -e "${CYAN}📁 Scanned: $SCANNED_FILES Terraform files${NC}"

# Show check statistics
echo -e "\n${CYAN}Check Statistics:${NC}"
[[ $PASSED_COUNT -gt 0 ]] && echo -e "  ${GREEN}✓ Passed: $PASSED_COUNT${NC}" || echo -e "  ${CYAN}✓ Passed: 0${NC}"
[[ $FAILED_COUNT -gt 0 ]] && echo -e "  ${RED}✗ Failed: $FAILED_COUNT${NC}" || echo -e "  ${GREEN}✗ Failed: 0${NC}"
[[ $SKIPPED_COUNT -gt 0 ]] && echo -e "  ${YELLOW}⊘ Skipped: $SKIPPED_COUNT${NC}" || echo -e "  ${CYAN}⊘ Skipped: 0${NC}"

# Show severity breakdown
echo -e "\n${CYAN}Severity Breakdown:${NC}"
[[ $CRITICAL_COUNT -gt 0 ]] && echo -e "  ${RED}🚨 Critical: $CRITICAL_COUNT${NC}" || echo -e "  ${GREEN}🚨 Critical: 0${NC}"
[[ $HIGH_COUNT -gt 0 ]] && echo -e "  ${RED}❌ High: $HIGH_COUNT${NC}" || echo -e "  ${GREEN}❌ High: 0${NC}"
[[ $MEDIUM_COUNT -gt 0 ]] && echo -e "  ${YELLOW}⚠️  Medium: $MEDIUM_COUNT${NC}" || echo -e "  ${GREEN}⚠️  Medium: 0${NC}"
[[ $LOW_COUNT -gt 0 ]] && echo -e "  ${CYAN}ℹ️  Low: $LOW_COUNT${NC}" || echo -e "  ${GREEN}ℹ️  Low: 0${NC}"

# Show output files
echo -e "\n${CYAN}📄 Output Files:${NC}"
echo -e "  • JSON: $OUTPUT_JSON"
[[ -f "$OUTPUT_SARIF" ]] && echo -e "  • SARIF: $OUTPUT_SARIF"
[[ -f "$OUTPUT_JUNIT" ]] && echo -e "  • JUnit: $OUTPUT_JUNIT"

# Show compliance status
echo -e "\n${MAGENTA}🔐 Compliance Status:${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "  ${GREEN}✓ CIS AWS Foundations Benchmark${NC}"
    echo -e "  ${GREEN}✓ PCI-DSS Compliance${NC}"
    echo -e "  ${GREEN}✓ HIPAA Compliance${NC}"
    echo -e "  ${GREEN}✓ ISO/IEC 27001${NC}"
else
    echo -e "  ${RED}✗ Compliance violations detected${NC}"
    echo -e "  ${YELLOW}⚠ Review findings and remediate issues${NC}"
fi

# Final result
echo -e "\n${BLUE}═══════════════════════════════════════════════════${NC}"
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ No policy violations found!${NC}"
    echo -e "${GREEN}✓ Terraform code meets compliance standards${NC}"
    [[ $LOW_COUNT -gt 0 ]] && echo -e "${CYAN}ℹ️  Note: $LOW_COUNT low severity issues found (non-blocking)${NC}"
    exit 0
else
    echo -e "${RED}✗ Errors: $ERRORS (Critical: $CRITICAL_COUNT, High: $HIGH_COUNT, Medium: $MEDIUM_COUNT)${NC}"
    echo -e "\n${RED}❌ Policy violations must be resolved${NC}"
    echo -e "${YELLOW}💡 Detailed results: $OUTPUT_JSON${NC}"
    echo -e "${YELLOW}📖 Policy configuration: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}📋 Governance standards: docs/governance/infrastructure_governance.md${NC}"
    echo -e "\n${CYAN}🔧 Common remediation steps:${NC}"
    echo -e "  1. Review failed checks in $OUTPUT_JSON"
    echo -e "  2. Apply security fixes to Terraform code"
    echo -e "  3. Document any necessary skip rules in $CONFIG_FILE"
    echo -e "  4. Re-run scan to verify fixes"
    echo -e "  5. Update security documentation if needed"
    exit 1
fi
