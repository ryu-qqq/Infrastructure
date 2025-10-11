#!/bin/bash
set -e

echo "🚀 GitHub Actions IAM Role 생성 스크립트"
echo "=========================================="
echo ""

# 1. Role 생성
echo "1️⃣ IAM Role 생성 중..."
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-actions-trust-policy.json \
  --description "Role for GitHub Actions to deploy infrastructure"

echo "✅ Role 생성 완료"
echo ""

# 2. Permissions Policy 연결
echo "2️⃣ Permissions Policy 연결 중..."
aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name GitHubActionsPermissions \
  --policy-document file://github-actions-permissions.json

echo "✅ Policy 연결 완료"
echo ""

# 3. Role ARN 확인
echo "3️⃣ Role ARN 확인 중..."
ROLE_ARN=$(aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text)

echo ""
echo "=========================================="
echo "✅ 설정 완료!"
echo "=========================================="
echo ""
echo "📋 GitHub Secrets에 추가할 값:"
echo ""
echo "Secret Name: AWS_ROLE_ARN"
echo "Secret Value: ${ROLE_ARN}"
echo ""
echo "🔗 GitHub 설정 위치:"
echo "https://github.com/ryu-qqq/Infrastructure/settings/secrets/actions"
echo ""
echo "설정 방법:"
echo "1. 위 링크 접속"
echo "2. 'New repository secret' 클릭"
echo "3. Name: AWS_ROLE_ARN"
echo "4. Secret: 위의 Role ARN 복사 붙여넣기"
echo "5. 'Add secret' 클릭"
echo ""
