#!/bin/bash
# =============================================================================
# Rollback Script - server.set-of.net을 기존 ALB로 복원
# =============================================================================
#
# 사용법:
#   ./scripts/rollback.sh
#
# 주의: 이 스크립트는 Route53 레코드만 롤백합니다.
#       CloudFront Distribution은 유지됩니다 (비용 없음, 재사용 가능)
# =============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 설정
HOSTED_ZONE_ID="Z02584341WZ7FPIKF06FI"
DOMAIN_NAME="server.set-of.net"
ALB_DNS_NAME="dualstack.setof-web-server-lb-428831385.ap-northeast-2.elb.amazonaws.com"
ALB_HOSTED_ZONE_ID="ZWKZPGTI48KDX"  # ALB hosted zone (ap-northeast-2)

echo -e "${YELLOW}==============================================================================${NC}"
echo -e "${YELLOW} Rollback: server.set-of.net → 기존 ALB 복원${NC}"
echo -e "${YELLOW}==============================================================================${NC}"
echo ""

# 현재 상태 확인
echo -e "${GREEN}[1/4] 현재 Route53 레코드 확인 중...${NC}"
CURRENT_RECORD=$(aws route53 list-resource-record-sets \
  --hosted-zone-id ${HOSTED_ZONE_ID} \
  --query "ResourceRecordSets[?Name=='${DOMAIN_NAME}.']" \
  --output json)

echo "현재 설정:"
echo "$CURRENT_RECORD" | jq '.[0].AliasTarget.DNSName'
echo ""

# 확인 프롬프트
echo -e "${YELLOW}[2/4] 롤백 확인${NC}"
echo "다음 변경을 수행합니다:"
echo "  - ${DOMAIN_NAME} → ${ALB_DNS_NAME}"
echo ""
read -p "계속하시겠습니까? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo -e "${RED}롤백이 취소되었습니다.${NC}"
  exit 1
fi

# Route53 변경 (A 레코드)
echo -e "${GREEN}[3/4] Route53 A 레코드 롤백 중...${NC}"
aws route53 change-resource-record-sets \
  --hosted-zone-id ${HOSTED_ZONE_ID} \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'${DOMAIN_NAME}'",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'${ALB_HOSTED_ZONE_ID}'",
          "DNSName": "'${ALB_DNS_NAME}'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'

# AAAA 레코드 삭제 (CloudFront가 추가한 IPv6)
echo -e "${GREEN}[4/4] Route53 AAAA 레코드 삭제 중...${NC}"
aws route53 change-resource-record-sets \
  --hosted-zone-id ${HOSTED_ZONE_ID} \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "'${DOMAIN_NAME}'",
        "Type": "AAAA",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "'$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, \`${DOMAIN_NAME}\`)].DomainName" --output text 2>/dev/null || echo "unknown.cloudfront.net")'",
          "EvaluateTargetHealth": false
        }
      }
    }]
  }' 2>/dev/null || echo "AAAA 레코드가 없거나 이미 삭제됨"

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN} 롤백 완료!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo "확인 방법:"
echo "  1. dig ${DOMAIN_NAME}"
echo "  2. curl -I https://${DOMAIN_NAME}"
echo ""
echo "DNS 전파에 최대 5분 소요될 수 있습니다."
