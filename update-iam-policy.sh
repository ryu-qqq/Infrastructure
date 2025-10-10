#!/bin/bash
set -e

echo "🔄 Updating IAM Role permissions..."

aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPermissions \
  --policy-document file://github-actions-permissions.json

echo "✅ IAM Role permissions updated successfully!"
echo ""
echo "Updated permissions now include:"
echo "  - kms:GetKeyRotationStatus"
echo "  - kms:ListResourceTags"
echo ""
echo "GitHub Actions will use updated permissions on next run."
