#!/bin/bash
set -e

echo "🔄 Updating IAM Role permissions..."

aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPermissions \
  --policy-document file://github-actions-permissions.json

echo "✅ IAM Role permissions updated successfully!"
echo ""
echo "Updated permissions:"
echo "  - ECR: Full Access (ecr:*)"
echo "  - KMS: Full Access (kms:*)"
echo ""
echo "This provides complete ECR and KMS management capabilities."
echo "GitHub Actions will use updated permissions on next run."
