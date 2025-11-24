#!/bin/bash

# Atlantis 재시작 스크립트
# 사용법: ./restart-atlantis.sh [환경]
# 예시: ./restart-atlantis.sh prod

set -e

ENVIRONMENT=${1:-prod}
CLUSTER="atlantis-${ENVIRONMENT}"
SERVICE="atlantis-${ENVIRONMENT}"
REGION="ap-northeast-2"

echo "=== Atlantis 재시작 시작 ==="
echo "환경: ${ENVIRONMENT}"
echo "클러스터: ${CLUSTER}"
echo "서비스: ${SERVICE}"
echo "리전: ${REGION}"
echo ""

# ECS 서비스 강제 재배포
aws ecs update-service \
  --cluster "${CLUSTER}" \
  --service "${SERVICE}" \
  --force-new-deployment \
  --region "${REGION}"

echo "✅ Atlantis 재배포가 시작되었습니다."
echo "약 2-3분 소요됩니다. 진행 상황을 확인하려면:"
echo ""
echo "  aws ecs describe-services \\"
echo "    --cluster ${CLUSTER} \\"
echo "    --services ${SERVICE} \\"
echo "    --region ${REGION}"
