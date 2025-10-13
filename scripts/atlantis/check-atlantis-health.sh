#!/bin/bash

# Atlantis 헬스체크 스크립트
# 사용법: ./check-atlantis-health.sh [환경]
# 예시: ./check-atlantis-health.sh prod

set -e

ENVIRONMENT=${1:-prod}
CLUSTER="atlantis-${ENVIRONMENT}"
SERVICE="atlantis-${ENVIRONMENT}"
LOG_GROUP="/ecs/atlantis-${ENVIRONMENT}"
REGION="ap-northeast-2"

# Target Group ARN (환경에 따라 다를 수 있음)
if [ "${ENVIRONMENT}" == "prod" ]; then
  TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:ap-northeast-2:646886795421:targetgroup/atl-20251011072359287200000001/2c46e9934484e453"
fi

echo "==================================="
echo "Atlantis Health Check"
echo "환경: ${ENVIRONMENT}"
echo "==================================="
echo ""

# 1. ECS Service 상태
echo "📋 ECS Service Status"
echo "-----------------------------------"
aws ecs describe-services \
  --cluster "${CLUSTER}" \
  --services "${SERVICE}" \
  --region "${REGION}" \
  --query 'services[0].[serviceName,status,runningCount,desiredCount,deployments[0].status]' \
  --output table
echo ""

# 2. Task 상태
echo "📦 Running Tasks"
echo "-----------------------------------"
TASK_ARNS=$(aws ecs list-tasks \
  --cluster "${CLUSTER}" \
  --service-name "${SERVICE}" \
  --region "${REGION}" \
  --query 'taskArns[0]' \
  --output text)

if [ -n "${TASK_ARNS}" ] && [ "${TASK_ARNS}" != "None" ]; then
  aws ecs describe-tasks \
    --cluster "${CLUSTER}" \
    --tasks "${TASK_ARNS}" \
    --region "${REGION}" \
    --query 'tasks[0].[taskArn,lastStatus,healthStatus,createdAt]' \
    --output table
else
  echo "⚠️  실행 중인 Task가 없습니다."
fi
echo ""

# 3. ALB Target Health (prod 환경만)
if [ -n "${TARGET_GROUP_ARN}" ]; then
  echo "🎯 Target Health Status"
  echo "-----------------------------------"
  aws elbv2 describe-target-health \
    --target-group-arn "${TARGET_GROUP_ARN}" \
    --region "${REGION}" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table
  echo ""
fi

# 4. 최근 로그 (에러만)
echo "🔍 Recent Error Logs (Last 10 minutes)"
echo "-----------------------------------"
ERROR_LOGS=$(aws logs tail "${LOG_GROUP}" \
  --since 10m \
  --filter-pattern "level=error" \
  --region "${REGION}" \
  --format short 2>/dev/null | head -10)

if [ -n "${ERROR_LOGS}" ]; then
  echo "${ERROR_LOGS}"
else
  echo "✅ 에러 로그가 없습니다."
fi
echo ""

# 5. 최근 활동 요약
echo "📊 Recent Activity (Last 1 hour)"
echo "-----------------------------------"
WEBHOOK_COUNT=$(aws logs tail "${LOG_GROUP}" \
  --since 1h \
  --filter-pattern "Received webhook" \
  --region "${REGION}" \
  --format short 2>/dev/null | wc -l)

PLAN_COUNT=$(aws logs tail "${LOG_GROUP}" \
  --since 1h \
  --filter-pattern "Running plan" \
  --region "${REGION}" \
  --format short 2>/dev/null | wc -l)

APPLY_COUNT=$(aws logs tail "${LOG_GROUP}" \
  --since 1h \
  --filter-pattern "Running apply" \
  --region "${REGION}" \
  --format short 2>/dev/null | wc -l)

echo "Webhook 수신: ${WEBHOOK_COUNT}"
echo "Plan 실행: ${PLAN_COUNT}"
echo "Apply 실행: ${APPLY_COUNT}"
echo ""

echo "==================================="
echo "Health Check 완료"
echo "==================================="
