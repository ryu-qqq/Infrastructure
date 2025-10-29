#!/bin/bash

# =============================================================================
# Import Existing AWS Resources to Terraform State
# =============================================================================
# This script imports manually created AWS resources into Terraform state
# to prevent recreation during terraform apply.
#
# Usage:
#   cd terraform/bootstrap
#   ../../scripts/import-existing-resources.sh
# =============================================================================

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}===${NC} $1 ${BLUE}===${NC}\n"
}

# Check if we're in terraform/bootstrap directory
if [ ! -f "main.tf" ] || [ "$(basename $(pwd))" != "bootstrap" ]; then
    log_error "This script must be run from terraform/bootstrap directory"
    exit 1
fi

# =============================================================================
# Bootstrap Resources Import
# =============================================================================

log_section "Importing Bootstrap Resources"

# 1. S3 Bucket for Terraform State
log_info "Importing S3 bucket: prod-connectly"
terraform import aws_s3_bucket.terraform-state prod-connectly || log_warn "S3 bucket already in state or doesn't exist"

# 2. S3 Bucket Versioning
log_info "Importing S3 bucket versioning"
terraform import aws_s3_bucket_versioning.terraform-state prod-connectly || log_warn "S3 versioning already in state"

# 3. S3 Bucket Encryption
log_info "Importing S3 bucket encryption"
terraform import aws_s3_bucket_server_side_encryption_configuration.terraform-state prod-connectly || log_warn "S3 encryption already in state"

# 4. S3 Bucket Public Access Block
log_info "Importing S3 bucket public access block"
terraform import aws_s3_bucket_public_access_block.terraform-state prod-connectly || log_warn "S3 public access block already in state"

# 5. S3 Bucket Lifecycle
log_info "Importing S3 bucket lifecycle"
terraform import aws_s3_bucket_lifecycle_configuration.terraform-state prod-connectly || log_warn "S3 lifecycle already in state"

# 6. DynamoDB Table for Terraform Lock
log_info "Importing DynamoDB table: prod-connectly-tf-lock"
terraform import aws_dynamodb_table.terraform-lock prod-connectly-tf-lock || log_warn "DynamoDB table already in state or doesn't exist"

# 7. KMS Key for Terraform State
log_info "Finding KMS key ID for alias/terraform-state"
KMS_KEY_ID=$(aws kms describe-key --key-id alias/terraform-state --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "")

if [ -n "$KMS_KEY_ID" ]; then
    log_info "Importing KMS key: $KMS_KEY_ID"
    terraform import aws_kms_key.terraform-state "$KMS_KEY_ID" || log_warn "KMS key already in state"

    log_info "Importing KMS alias: alias/terraform-state"
    terraform import aws_kms_alias.terraform-state alias/terraform-state || log_warn "KMS alias already in state"
else
    log_warn "KMS key alias/terraform-state not found"
fi

# 8. IAM Role for GitHub Actions
log_info "Importing IAM role: GitHubActionsRole"
terraform import aws_iam_role.github-actions GitHubActionsRole || log_warn "IAM role already in state or doesn't exist"

# 9. IAM Role Policies
log_info "Importing IAM role policies"
terraform import aws_iam_role_policy.github-actions-terraform-state GitHubActionsRole:terraform-state-access || log_warn "Policy already in state"
terraform import aws_iam_role_policy.github-actions-ssm GitHubActionsRole:ssm-parameter-access || log_warn "Policy already in state"
terraform import aws_iam_role_policy.github-actions-kms GitHubActionsRole:kms-key-access || log_warn "Policy already in state"
terraform import aws_iam_role_policy.github-actions-resource-management GitHubActionsRole:resource-management || log_warn "Policy already in state"

# 10. IAM Policy for FileFlow
log_info "Finding IAM policy ARN for GitHubActionsFileFlowPolicy"
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='GitHubActionsFileFlowPolicy'].Arn" --output text 2>/dev/null || echo "")

if [ -n "$POLICY_ARN" ]; then
    log_info "Importing IAM policy: $POLICY_ARN"
    terraform import aws_iam_policy.github-actions-fileflow "$POLICY_ARN" || log_warn "IAM policy already in state"

    log_info "Importing IAM policy attachment"
    terraform import aws_iam_role_policy_attachment.github-actions-fileflow GitHubActionsRole/arn:aws:iam::646886795421:policy/GitHubActionsFileFlowPolicy || log_warn "Policy attachment already in state"
else
    log_warn "IAM policy GitHubActionsFileFlowPolicy not found"
fi

# =============================================================================
# Summary
# =============================================================================

log_section "Import Complete"

log_info "All existing resources have been imported into Terraform state"
log_info "Run 'terraform plan' to verify no changes are needed"

echo ""
echo "If you see any changes in terraform plan, it might be due to:"
echo "  - Tag differences (Owner email changed)"
echo "  - Configuration drift from manual changes"
echo "  - New resources that don't exist yet"
