#!/bin/bash
#
# check-tags.sh - Terraform Required Tags Validator
#
# Validates that all Terraform resources include required governance tags.
# Based on docs/governance/TAGGING_STANDARDS.md standards.
#
# Required Tags:
#   - Environment, Service, Team, Owner, CostCenter, ManagedBy, Project
#
# Optional Tags:
#   - DataClass (for data-storing resources)
#
# Usage:
#   ./scripts/validators/check-tags.sh [terraform_directory]
#
# Exit Codes:
#   0 - All resources have required tags
#   1 - Missing tags found or validation errors
#

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Required tags based on new governance standards (docs/governance/TAGGING_STANDARDS.md)
REQUIRED_TAGS=("Environment" "Service" "Team" "Owner" "CostCenter" "ManagedBy" "Project")

# Configuration
TERRAFORM_DIR="${1:-terraform}"
ERRORS=0
WARNINGS=0

echo -e "${BLUE}🏷️  Checking required tags in Terraform resources...${NC}\n"

# Check if terraform directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${RED}✗ Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    echo -e "${YELLOW}💡 Tip: Specify directory as: $0 <terraform_directory>${NC}"
    exit 1
fi

# Function to check if required_tags local is defined
check_required_tags_local() {
    local found=0

    echo -e "${BLUE}📋 Checking for required_tags local definition...${NC}"

    for file in $(find "$TERRAFORM_DIR" -name "*.tf" -type f); do
        if grep -q "required_tags\s*=" "$file"; then
            echo -e "${GREEN}✓ Found required_tags in: $file${NC}"

            # Verify all required tags are in the local
            for tag in "${REQUIRED_TAGS[@]}"; do
                if ! grep -A 10 "required_tags\s*=" "$file" | grep -q "$tag\s*="; then
                    echo -e "${YELLOW}⚠ Warning: $tag not found in required_tags local${NC}"
                    ((WARNINGS++))
                fi
            done

            found=1
            break
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo -e "${YELLOW}⚠ Warning: required_tags local not found${NC}"
        echo -e "${YELLOW}💡 Tip: Define required_tags in variables.tf as:${NC}"
        echo -e "${YELLOW}   locals {${NC}"
        echo -e "${YELLOW}     required_tags = {${NC}"
        echo -e "${YELLOW}       Owner       = var.owner${NC}"
        echo -e "${YELLOW}       CostCenter  = var.cost_center${NC}"
        echo -e "${YELLOW}       ...${NC}"
        echo -e "${YELLOW}     }${NC}"
        echo -e "${YELLOW}   }${NC}"
        ((WARNINGS++))
    fi

    echo ""
}

# Function to check tags in a resource block
check_resource_tags() {
    local file=$1
    local resource_type=$2
    local resource_name=$3
    local line_number=$4

    # Skip certain resource types that don't support tags
    local skip_types=("aws_kms_alias" "aws_kms_key_policy" "aws_ecr_repository_policy" "aws_ecr_lifecycle_policy" "aws_iam_role_policy_attachment" "aws_iam_role_policy" "aws_ecs_cluster_capacity_providers" "aws_secretsmanager_secret_version" "aws_secretsmanager_secret_rotation" "aws_lambda_permission" "aws_efs_mount_target" "aws_efs_access_point" "aws_route" "aws_route_table_association" "aws_sns_topic_policy" "aws_sns_topic_subscription" "aws_cloudwatch_event_target" "aws_cloudwatch_log_metric_filter" "aws_grafana_role_association" "aws_appautoscaling_target" "aws_appautoscaling_policy" "aws_appautoscaling_scheduled_action" "aws_route53_record" "aws_route53_query_log" "data")

    for skip_type in "${skip_types[@]}"; do
        if [[ "$resource_type" == "$skip_type" ]]; then
            return
        fi
    done

    # Skip resource types that don't support tags based on patterns
    # Random provider resources don't support tags
    if [[ "$resource_type" =~ ^random_ ]]; then
        return
    fi

    # S3 bucket sub-resources don't support tags (only the bucket itself does)
    # Exclude all aws_s3_bucket_* except aws_s3_bucket itself
    if [[ "$resource_type" =~ ^aws_s3_bucket_ ]]; then
        return
    fi

    # Extract the resource block
    local resource_block=$(awk -v start="$line_number" '
        NR == start { depth=0; print }
        NR > start {
            for (i=1; i<=length($0); i++) {
                c = substr($0, i, 1)
                if (c == "{") depth++
                if (c == "}") depth--
            }
            print
            if (depth < 0) exit
        }
    ' "$file")

    # Check if tags block exists
    if ! echo "$resource_block" | grep -q "tags\s*="; then
        echo -e "${RED}✗ Error: No tags found${NC}"
        echo -e "  ${YELLOW}Resource: $resource_type.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}💡 Add: tags = merge(local.required_tags, {...})${NC}"
        ((ERRORS++))
        return
    fi

    # Check if using merge(local.required_tags) or merge(var.common_tags) pattern
    # Convert to single line for pattern matching
    if echo "$resource_block" | tr '\n' ' ' | grep -qE "merge.*(local\.required_tags|var\.common_tags)"; then
        echo -e "${GREEN}✓ $resource_type.$resource_name uses required_tags pattern${NC}"
        return
    fi

    # Check if all required tags are present directly
    local missing_tags=()
    for tag in "${REQUIRED_TAGS[@]}"; do
        if ! echo "$resource_block" | grep -q "$tag\s*="; then
            missing_tags+=("$tag")
        fi
    done

    if [[ ${#missing_tags[@]} -gt 0 ]]; then
        echo -e "${RED}✗ Error: Missing required tags${NC}"
        echo -e "  ${YELLOW}Resource: $resource_type.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}Missing: ${missing_tags[*]}${NC}"
        echo -e "  ${YELLOW}💡 Use: tags = merge(local.required_tags, {...})${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ $resource_type.$resource_name has all required tags${NC}"
    fi
}

# Main validation
check_required_tags_local

echo -e "${BLUE}🔍 Scanning resources for tags...${NC}\n"

# Find all resource blocks
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_number=$(echo "$line" | cut -d: -f2)
    resource_line=$(echo "$line" | cut -d: -f3-)

    # Extract resource type and name
    if [[ $resource_line =~ resource[[:space:]]+\"([^\"]+)\"[[:space:]]+\"([^\"]+)\" ]]; then
        resource_type="${BASH_REMATCH[1]}"
        resource_name="${BASH_REMATCH[2]}"

        check_resource_tags "$file" "$resource_type" "$resource_name" "$line_number"
    fi
done < <(grep -n "^resource\s" $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null || true)

# Summary
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Tag Validation Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ All resources have required tags!${NC}"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
    echo -e "${YELLOW}💡 See: docs/governance/infrastructure_governance.md${NC}"
    exit 0
else
    echo -e "${RED}✗ Errors: $ERRORS${NC}"
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
    echo -e "${YELLOW}💡 See: docs/governance/infrastructure_governance.md${NC}"
    exit 1
fi
