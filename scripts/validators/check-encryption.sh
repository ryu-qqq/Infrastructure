#!/bin/bash
#
# check-encryption.sh - Terraform KMS Encryption Validator
#
# Validates that sensitive AWS resources use KMS encryption (not AES256).
# Based on docs/infrastructure_governance.md standards.
#
# Checked Resources:
#   - ECR: encryption_type = "KMS"
#   - S3: server_side_encryption_configuration (SSE-KMS)
#   - RDS: storage_encrypted + kms_key_id
#   - EBS: encrypted + kms_key_id
#
# Usage:
#   ./scripts/validators/check-encryption.sh [terraform_directory]
#
# Exit Codes:
#   0 - All resources use KMS encryption
#   1 - Missing or incorrect encryption found
#

set -e
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

echo -e "${BLUE}🔒 Checking KMS encryption in Terraform resources...${NC}\n"

# Check if terraform directory exists
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${RED}✗ Error: Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

# Function to extract resource block
extract_resource_block() {
    local file=$1
    local line_number=$2

    awk -v start="$line_number" '
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
    ' "$file"
}

# Function to check ECR encryption
check_ecr_encryption() {
    local file=$1
    local resource_name=$2
    local line_number=$3

    local resource_block=$(extract_resource_block "$file" "$line_number")

    # Check if encryption_configuration exists
    if ! echo "$resource_block" | grep -q "encryption_configuration"; then
        echo -e "${RED}✗ Error: ECR repository missing encryption_configuration${NC}"
        echo -e "  ${YELLOW}Resource: aws_ecr_repository.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}💡 Add: encryption_configuration { encryption_type = \"KMS\"; kms_key = ... }${NC}"
        ((ERRORS++))
        return
    fi

    # Check encryption type
    if echo "$resource_block" | grep -q 'encryption_type\s*=\s*"AES256"'; then
        echo -e "${RED}✗ Error: ECR using AES256 instead of KMS${NC}"
        echo -e "  ${YELLOW}Resource: aws_ecr_repository.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}💡 Change to: encryption_type = \"KMS\"${NC}"
        ((ERRORS++))
        return
    fi

    if ! echo "$resource_block" | grep -q 'encryption_type\s*=\s*"KMS"'; then
        echo -e "${RED}✗ Error: ECR encryption_type not set to KMS${NC}"
        echo -e "  ${YELLOW}Resource: aws_ecr_repository.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        ((ERRORS++))
        return
    fi

    # Check if kms_key is specified
    if ! echo "$resource_block" | grep -q "kms_key\s*="; then
        echo -e "${YELLOW}⚠ Warning: ECR encryption_type is KMS but kms_key not specified${NC}"
        echo -e "  ${YELLOW}Resource: aws_ecr_repository.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        ((WARNINGS++))
        return
    fi

    echo -e "${GREEN}✓ aws_ecr_repository.$resource_name uses KMS encryption${NC}"
}

# Function to check S3 encryption
check_s3_encryption() {
    local file=$1
    local resource_name=$2
    local line_number=$3

    local resource_block=$(extract_resource_block "$file" "$line_number")

    # Note: aws_s3_bucket encryption is now in separate resource aws_s3_bucket_server_side_encryption_configuration
    # This is a simplified check - in practice, need to check both old and new S3 patterns

    if echo "$resource_block" | grep -q "server_side_encryption_configuration"; then
        # Old pattern (inline)
        if echo "$resource_block" | grep -q 'sse_algorithm\s*=\s*"AES256"'; then
            echo -e "${RED}✗ Error: S3 using AES256 instead of KMS${NC}"
            echo -e "  ${YELLOW}Resource: aws_s3_bucket.$resource_name${NC}"
            echo -e "  ${YELLOW}File: $file:$line_number${NC}"
            echo -e "  ${YELLOW}💡 Change to: sse_algorithm = \"aws:kms\"${NC}"
            ((ERRORS++))
            return
        fi

        if echo "$resource_block" | grep -q 'sse_algorithm\s*=\s*"aws:kms"'; then
            echo -e "${GREEN}✓ aws_s3_bucket.$resource_name uses KMS encryption${NC}"
            return
        fi
    fi

    # If no encryption found, it's a warning (might be in separate resource)
    echo -e "${YELLOW}⚠ Info: S3 bucket encryption config not found (check if using separate resource)${NC}"
    echo -e "  ${YELLOW}Resource: aws_s3_bucket.$resource_name${NC}"
    echo -e "  ${YELLOW}File: $file:$line_number${NC}"
}

# Function to check RDS encryption
check_rds_encryption() {
    local file=$1
    local resource_name=$2
    local line_number=$3

    local resource_block=$(extract_resource_block "$file" "$line_number")

    # Check storage_encrypted
    if ! echo "$resource_block" | grep -q "storage_encrypted\s*=\s*true"; then
        echo -e "${RED}✗ Error: RDS instance not encrypted${NC}"
        echo -e "  ${YELLOW}Resource: aws_db_instance.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}💡 Add: storage_encrypted = true; kms_key_id = ...${NC}"
        ((ERRORS++))
        return
    fi

    # Check kms_key_id
    if ! echo "$resource_block" | grep -q "kms_key_id\s*="; then
        echo -e "${YELLOW}⚠ Warning: RDS encrypted but kms_key_id not specified${NC}"
        echo -e "  ${YELLOW}Resource: aws_db_instance.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        ((WARNINGS++))
        return
    fi

    echo -e "${GREEN}✓ aws_db_instance.$resource_name uses KMS encryption${NC}"
}

# Function to check EBS encryption
check_ebs_encryption() {
    local file=$1
    local resource_name=$2
    local line_number=$3

    local resource_block=$(extract_resource_block "$file" "$line_number")

    # Check encrypted
    if ! echo "$resource_block" | grep -q "encrypted\s*=\s*true"; then
        echo -e "${RED}✗ Error: EBS volume not encrypted${NC}"
        echo -e "  ${YELLOW}Resource: aws_ebs_volume.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        echo -e "  ${YELLOW}💡 Add: encrypted = true; kms_key_id = ...${NC}"
        ((ERRORS++))
        return
    fi

    # Check kms_key_id
    if ! echo "$resource_block" | grep -q "kms_key_id\s*="; then
        echo -e "${YELLOW}⚠ Warning: EBS encrypted but kms_key_id not specified${NC}"
        echo -e "  ${YELLOW}Resource: aws_ebs_volume.$resource_name${NC}"
        echo -e "  ${YELLOW}File: $file:$line_number${NC}"
        ((WARNINGS++))
        return
    fi

    echo -e "${GREEN}✓ aws_ebs_volume.$resource_name uses KMS encryption${NC}"
}

# Scan for ECR repositories
echo -e "${BLUE}📦 Checking ECR repositories...${NC}"
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_number=$(echo "$line" | cut -d: -f2)
    resource_line=$(echo "$line" | cut -d: -f3-)

    if [[ $resource_line =~ resource[[:space:]]+\"aws_ecr_repository\"[[:space:]]+\"([^\"]+)\" ]]; then
        resource_name="${BASH_REMATCH[1]}"
        check_ecr_encryption "$file" "$resource_name" "$line_number"
    fi
done < <(grep -n '^resource\s*"aws_ecr_repository"' $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null || true)

# Scan for S3 buckets
echo -e "\n${BLUE}🪣 Checking S3 buckets...${NC}"
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_number=$(echo "$line" | cut -d: -f2)
    resource_line=$(echo "$line" | cut -d: -f3-)

    if [[ $resource_line =~ resource[[:space:]]+\"aws_s3_bucket\"[[:space:]]+\"([^\"]+)\" ]]; then
        resource_name="${BASH_REMATCH[1]}"
        check_s3_encryption "$file" "$resource_name" "$line_number"
    fi
done < <(grep -n '^resource\s*"aws_s3_bucket"' $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null || true)

# Scan for RDS instances
echo -e "\n${BLUE}🗄️  Checking RDS instances...${NC}"
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_number=$(echo "$line" | cut -d: -f2)
    resource_line=$(echo "$line" | cut -d: -f3-)

    if [[ $resource_line =~ resource[[:space:]]+\"aws_db_instance\"[[:space:]]+\"([^\"]+)\" ]]; then
        resource_name="${BASH_REMATCH[1]}"
        check_rds_encryption "$file" "$resource_name" "$line_number"
    fi
done < <(grep -n '^resource\s*"aws_db_instance"' $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null || true)

# Scan for EBS volumes
echo -e "\n${BLUE}💾 Checking EBS volumes...${NC}"
while IFS= read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    line_number=$(echo "$line" | cut -d: -f2)
    resource_line=$(echo "$line" | cut -d: -f3-)

    if [[ $resource_line =~ resource[[:space:]]+\"aws_ebs_volume\"[[:space:]]+\"([^\"]+)\" ]]; then
        resource_name="${BASH_REMATCH[1]}"
        check_ebs_encryption "$file" "$resource_name" "$line_number"
    fi
done < <(grep -n '^resource\s*"aws_ebs_volume"' $(find "$TERRAFORM_DIR" -name "*.tf" -type f) 2>/dev/null || true)

# Summary
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Encryption Validation Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ All resources use KMS encryption!${NC}"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
    echo -e "${YELLOW}💡 See: docs/infrastructure_governance.md${NC}"
    exit 0
else
    echo -e "${RED}✗ Errors: $ERRORS${NC}"
    echo -e "${YELLOW}⚠ Warnings: $WARNINGS${NC}"
    echo -e "${YELLOW}💡 See: docs/infrastructure_governance.md${NC}"
    exit 1
fi
