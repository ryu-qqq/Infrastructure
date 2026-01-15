#!/bin/bash
# =============================================================================
# Verification Script - 리다이렉트 정상 동작 확인
# =============================================================================
#
# 사용법:
#   ./scripts/verify.sh
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOMAIN="server.set-of.net"
TARGET="www.set-of.com"

echo -e "${YELLOW}==============================================================================${NC}"
echo -e "${YELLOW} 리다이렉트 검증: ${DOMAIN} → ${TARGET}${NC}"
echo -e "${YELLOW}==============================================================================${NC}"
echo ""

# 1. DNS 확인
echo -e "${GREEN}[1/4] DNS 확인${NC}"
echo "현재 DNS 레코드:"
dig +short ${DOMAIN} A
dig +short ${DOMAIN} AAAA
echo ""

# 2. HTTP 응답 확인
echo -e "${GREEN}[2/4] HTTP 응답 확인${NC}"
RESPONSE=$(curl -sI -o /dev/null -w "%{http_code}" "https://${DOMAIN}/" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "301" ]; then
  echo -e "HTTP Status: ${GREEN}${RESPONSE} (정상)${NC}"
else
  echo -e "HTTP Status: ${RED}${RESPONSE} (예상: 301)${NC}"
fi
echo ""

# 3. Location 헤더 확인
echo -e "${GREEN}[3/4] 리다이렉트 Location 확인${NC}"
LOCATION=$(curl -sI "https://${DOMAIN}/" 2>/dev/null | grep -i "^location:" | tr -d '\r')
echo "Location: ${LOCATION}"

if [[ "$LOCATION" == *"${TARGET}"* ]]; then
  echo -e "${GREEN}✅ 리다이렉트 타겟 정상${NC}"
else
  echo -e "${RED}❌ 리다이렉트 타겟 불일치${NC}"
fi
echo ""

# 4. 경로 유지 테스트
echo -e "${GREEN}[4/4] 경로 유지 테스트${NC}"
TEST_PATHS=(
  "/api/v1/users"
  "/api/v1/auth?token=test123"
  "/health"
)

for path in "${TEST_PATHS[@]}"; do
  LOCATION=$(curl -sI "https://${DOMAIN}${path}" 2>/dev/null | grep -i "^location:" | tr -d '\r')
  EXPECTED="https://${TARGET}${path}"

  if [[ "$LOCATION" == *"${path}"* ]]; then
    echo -e "  ${path}: ${GREEN}✅${NC}"
  else
    echo -e "  ${path}: ${RED}❌${NC}"
    echo "    Expected: ${EXPECTED}"
    echo "    Got: ${LOCATION}"
  fi
done

echo ""
echo -e "${YELLOW}==============================================================================${NC}"
echo -e "${YELLOW} 검증 완료${NC}"
echo -e "${YELLOW}==============================================================================${NC}"
