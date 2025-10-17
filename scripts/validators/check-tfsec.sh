#!/bin/bash
#
# check-tfsec.sh - Terraform Security Scanner (tfsec)
#
# Validates Terraform code against security best practices using tfsec.
# Based on .tfsec/config.yml configuration and docs/governance/infrastructure_governance.md
#
# Checks:
#   - Encryption standards (KMS required)
#   - Public access controls
#   - IAM security policies
#   - Network security configurations
#   - Logging and monitoring requirements
#
# Usage:
#   ./scripts/validators/check-tfsec.sh [terraform_directory]
#
# Exit Codes:
#   0 - No security issues found
#   1 - Security issues found or scan failed
#   2 - tfsec not installed
#

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="${1:-terraform}"
CONFIG_FILE=".tfsec/config.yml"
OUTPUT_FILE="tfsec-results.json"
ERRORS=0
WARNINGS=0
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0

echo -e "${BLUE}🛡️  Running tfsec security scan...${NC}\n"

# Check if terraform directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${RED}✗ Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    echo -e "${YELLOW}💡 Tip: Specify directory as: $0 <terraform_directory>${NC}"
    exit 1
fi

# Check if tfsec is installed
if ! command -v tfsec >/dev/null 2>&1; then
    echo -e "${RED}✗ Error: tfsec is not installed${NC}"
    echo -e "${YELLOW}💡 Install tfsec:${NC}"
    echo -e "${YELLOW}   macOS: brew install tfsec${NC}"
    echo -e "${YELLOW}   Linux: https://github.com/aquasecurity/tfsec#installation${NC}"
    echo -e "${YELLOW}   Docker: docker run --rm -it -v \"\$(pwd):/src\" aquasec/tfsec /src${NC}"
    exit 2
fi

# Check tfsec version
TFSEC_VERSION=$(tfsec --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo -e "${CYAN}📦 tfsec version: ${TFSEC_VERSION}${NC}\n"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}⚠ Warning: Config file not found: $CONFIG_FILE${NC}"
    echo -e "${YELLOW}💡 Using default tfsec rules${NC}\n"
    CONFIG_ARG=""
else
    echo -e "${GREEN}✓ Using config file: $CONFIG_FILE${NC}\n"
    CONFIG_ARG="--config-file=$CONFIG_FILE"
fi

# Run tfsec scan
echo -e "${BLUE}🔍 Scanning Terraform code for security issues...${NC}\n"

# Run tfsec with JSON output for parsing
set +e
tfsec "$TERRAFORM_DIR" \
    $CONFIG_ARG \
    --format json \
    --out "$OUTPUT_FILE" \
    --soft-fail \
    --minimum-severity MEDIUM \
    2>&1
set -e

# Check if output file was created
if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo -e "${RED}✗ Error: tfsec scan failed to produce output${NC}"
    exit 1
fi

# Parse JSON results
if command -v jq >/dev/null 2>&1; then
    # Count issues by severity using jq
    CRITICAL_COUNT=$(jq '[.results[] | select(.severity == "CRITICAL")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
    HIGH_COUNT=$(jq '[.results[] | select(.severity == "HIGH")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
    MEDIUM_COUNT=$(jq '[.results[] | select(.severity == "MEDIUM")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
    LOW_COUNT=$(jq '[.results[] | select(.severity == "LOW")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")

    # Display issues by severity
    if [[ $CRITICAL_COUNT -gt 0 ]]; then
        echo -e "${RED}🚨 CRITICAL Issues: $CRITICAL_COUNT${NC}"
        jq -r '.results[] | select(.severity == "CRITICAL") | "  [\(.rule_id)] \(.description)\n  File: \(.location.filename):\(.location.start_line)\n"' "$OUTPUT_FILE"
        ((ERRORS += CRITICAL_COUNT))
    fi

    if [[ $HIGH_COUNT -gt 0 ]]; then
        echo -e "${RED}❌ HIGH Issues: $HIGH_COUNT${NC}"
        jq -r '.results[] | select(.severity == "HIGH") | "  [\(.rule_id)] \(.description)\n  File: \(.location.filename):\(.location.start_line)\n"' "$OUTPUT_FILE"
        ((ERRORS += HIGH_COUNT))
    fi

    if [[ $MEDIUM_COUNT -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  MEDIUM Issues: $MEDIUM_COUNT${NC}"
        jq -r '.results[] | select(.severity == "MEDIUM") | "  [\(.rule_id)] \(.description)\n  File: \(.location.filename):\(.location.start_line)\n"' "$OUTPUT_FILE"
        ((ERRORS += MEDIUM_COUNT))
    fi

    if [[ $LOW_COUNT -gt 0 ]]; then
        echo -e "${CYAN}ℹ️  LOW Issues: $LOW_COUNT${NC}"
        # Don't count LOW as errors or warnings
    fi

else
    echo -e "${YELLOW}⚠ Warning: jq not installed - cannot parse detailed results${NC}"
    echo -e "${YELLOW}💡 Install jq for better result parsing: brew install jq${NC}"

    # Fallback: just check if there are any results
    if grep -q '"results":\s*\[\s*{' "$OUTPUT_FILE"; then
        echo -e "${RED}Security issues found - check $OUTPUT_FILE for details${NC}"
        ERRORS=1
    fi
fi

# Display scan summary
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 tfsec Security Scan Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

# Show scanned paths
SCANNED_FILES=$(find "$TERRAFORM_DIR" -name "*.tf" -type f | wc -l | tr -d ' ')
echo -e "${CYAN}📁 Scanned: $SCANNED_FILES Terraform files${NC}"

# Show issue counts
echo -e "\n${CYAN}Issue Breakdown:${NC}"
[[ $CRITICAL_COUNT -gt 0 ]] && echo -e "  ${RED}🚨 Critical: $CRITICAL_COUNT${NC}" || echo -e "  ${GREEN}🚨 Critical: 0${NC}"
[[ $HIGH_COUNT -gt 0 ]] && echo -e "  ${RED}❌ High: $HIGH_COUNT${NC}" || echo -e "  ${GREEN}❌ High: 0${NC}"
[[ $MEDIUM_COUNT -gt 0 ]] && echo -e "  ${YELLOW}⚠️  Medium: $MEDIUM_COUNT${NC}" || echo -e "  ${GREEN}⚠️  Medium: 0${NC}"
[[ $LOW_COUNT -gt 0 ]] && echo -e "  ${CYAN}ℹ️  Low: $LOW_COUNT${NC}" || echo -e "  ${GREEN}ℹ️  Low: 0${NC}"

# Show result file location
echo -e "\n${CYAN}📄 Detailed results: $OUTPUT_FILE${NC}"

# Final result
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ No security issues found!${NC}"
    echo -e "${GREEN}✓ Terraform code meets security standards${NC}"
    [[ $LOW_COUNT -gt 0 ]] && echo -e "${CYAN}ℹ️  Note: $LOW_COUNT low severity issues found (non-blocking)${NC}"
    exit 0
else
    echo -e "${RED}✗ Errors: $ERRORS (Critical: $CRITICAL_COUNT, High: $HIGH_COUNT, Medium: $MEDIUM_COUNT)${NC}"
    echo -e "\n${RED}❌ Security issues must be resolved${NC}"
    echo -e "${YELLOW}💡 Review: $OUTPUT_FILE${NC}"
    echo -e "${YELLOW}📖 Security Standards: docs/governance/infrastructure_governance.md${NC}"
    echo -e "${YELLOW}🔧 Config: .tfsec/config.yml${NC}"
    exit 1
fi
