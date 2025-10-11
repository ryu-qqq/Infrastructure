#!/bin/bash
#
# cleanup-kms.sh - Clean up orphaned KMS resources from failed Terraform runs
#
# This script deletes KMS aliases and keys that were created but not tracked in Terraform state.
# Run this when you get "AlreadyExistsException" errors during Terraform apply.
#

set -e

REGION="ap-northeast-2"
ALIAS_NAME="alias/ecr-atlantis"

echo "🧹 Cleaning up orphaned KMS resources..."
echo ""

# Get the target key ID for the alias
echo "🔍 Checking for existing KMS alias: $ALIAS_NAME"
TARGET_KEY_ID=$(aws kms list-aliases --region $REGION --query "Aliases[?AliasName=='$ALIAS_NAME'].TargetKeyId" --output text 2>/dev/null || echo "")

if [ -z "$TARGET_KEY_ID" ]; then
    echo "✓ No alias found - nothing to clean up"
    exit 0
fi

echo "📋 Found alias pointing to key: $TARGET_KEY_ID"
echo ""

# Delete the alias
echo "🗑️  Deleting KMS alias..."
aws kms delete-alias --alias-name $ALIAS_NAME --region $REGION
echo "✓ Alias deleted"
echo ""

# Schedule the key for deletion (30 days waiting period)
echo "🗑️  Scheduling KMS key for deletion (30 day waiting period)..."
aws kms schedule-key-deletion --key-id $TARGET_KEY_ID --pending-window-in-days 30 --region $REGION
echo "✓ Key scheduled for deletion"
echo ""

echo "✅ Cleanup complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Run GitHub Actions workflow again"
echo "  2. Terraform will create fresh KMS resources"
echo ""
echo "⚠️  Note: The KMS key will be permanently deleted after 30 days."
echo "    You can cancel the deletion within this period if needed."
