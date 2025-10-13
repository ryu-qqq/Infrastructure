#!/bin/bash

# Atlantis 로그 모니터링 스크립트
# 사용법: ./monitor-atlantis-logs.sh [환경] [필터]
# 예시:
#   ./monitor-atlantis-logs.sh prod             # 전체 로그
#   ./monitor-atlantis-logs.sh prod error       # 에러만
#   ./monitor-atlantis-logs.sh prod FileFlow    # FileFlow 관련

set -e

ENVIRONMENT=${1:-prod}
FILTER=${2:-}
LOG_GROUP="/ecs/atlantis-${ENVIRONMENT}"
REGION="ap-northeast-2"

echo "=== Atlantis 실시간 로그 모니터링 ==="
echo "환경: ${ENVIRONMENT}"
echo "로그 그룹: ${LOG_GROUP}"

if [ -n "${FILTER}" ]; then
  if [ "${FILTER}" == "error" ]; then
    echo "필터: 에러 로그만"
    echo ""
    aws logs tail "${LOG_GROUP}" \
      --follow \
      --filter-pattern "level=error" \
      --region "${REGION}" \
      --format short
  else
    echo "필터: ${FILTER}"
    echo ""
    aws logs tail "${LOG_GROUP}" \
      --follow \
      --filter-pattern "${FILTER}" \
      --region "${REGION}" \
      --format short
  fi
else
  echo "필터: 없음 (전체 로그)"
  echo ""
  aws logs tail "${LOG_GROUP}" \
    --follow \
    --region "${REGION}" \
    --format short
fi
