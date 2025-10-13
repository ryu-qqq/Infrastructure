#!/bin/bash

# Atlantis 로그 내보내기 스크립트
# 사용법: ./export-atlantis-logs.sh [환경] [시간범위]
# 예시:
#   ./export-atlantis-logs.sh prod 24h   # 최근 24시간
#   ./export-atlantis-logs.sh prod 7d    # 최근 7일

set -e

ENVIRONMENT=${1:-prod}
TIMERANGE=${2:-24h}
LOG_GROUP="/ecs/atlantis-${ENVIRONMENT}"
REGION="ap-northeast-2"
OUTPUT_DIR="./logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 출력 디렉토리 생성
mkdir -p "${OUTPUT_DIR}"

echo "=== Atlantis 로그 내보내기 ==="
echo "환경: ${ENVIRONMENT}"
echo "로그 그룹: ${LOG_GROUP}"
echo "시간 범위: ${TIMERANGE}"
echo "출력 디렉토리: ${OUTPUT_DIR}"
echo ""

# 1. 전체 로그 (short format)
echo "1️⃣  전체 로그 내보내기 중..."
OUTPUT_FILE="${OUTPUT_DIR}/atlantis-${ENVIRONMENT}-${TIMESTAMP}.log"
aws logs tail "${LOG_GROUP}" \
  --since "${TIMERANGE}" \
  --format short \
  --region "${REGION}" > "${OUTPUT_FILE}"
echo "✅ 저장됨: ${OUTPUT_FILE}"

# 2. 에러 로그만
echo "2️⃣  에러 로그 내보내기 중..."
ERROR_FILE="${OUTPUT_DIR}/atlantis-${ENVIRONMENT}-errors-${TIMESTAMP}.log"
aws logs tail "${LOG_GROUP}" \
  --since "${TIMERANGE}" \
  --filter-pattern "level=error" \
  --format short \
  --region "${REGION}" > "${ERROR_FILE}" 2>/dev/null || echo "에러 로그 없음" > "${ERROR_FILE}"
echo "✅ 저장됨: ${ERROR_FILE}"

# 3. JSON 형식 (분석용)
echo "3️⃣  JSON 형식 내보내기 중..."
JSON_FILE="${OUTPUT_DIR}/atlantis-${ENVIRONMENT}-${TIMESTAMP}.json"
aws logs tail "${LOG_GROUP}" \
  --since "${TIMERANGE}" \
  --format json \
  --region "${REGION}" > "${JSON_FILE}"
echo "✅ 저장됨: ${JSON_FILE}"

# 4. 통계 정보
echo ""
echo "=== 로그 통계 ==="
TOTAL_LINES=$(wc -l < "${OUTPUT_FILE}")
ERROR_LINES=$(wc -l < "${ERROR_FILE}")
echo "전체 로그 라인: ${TOTAL_LINES}"
echo "에러 로그 라인: ${ERROR_LINES}"

# 5. 파일 크기
echo ""
echo "=== 파일 크기 ==="
ls -lh "${OUTPUT_DIR}"/atlantis-${ENVIRONMENT}-*${TIMESTAMP}*

echo ""
echo "✅ 로그 내보내기 완료"
