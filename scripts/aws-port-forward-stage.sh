#!/bin/bash

# ===============================================
# AWS SSM Session Manager Port Forwarding Script
# ===============================================
# Stage RDS에 안전하게 접근하기 위한 포트 포워딩 스크립트
# ===============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 환경 변수 기본값
ENVIRONMENT=${ENVIRONMENT:-stage}
AWS_REGION=${AWS_REGION:-ap-northeast-2}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AWS SSM Port Forwarding Setup (STAGE)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# AWS CLI 설치 확인
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI가 설치되어 있지 않습니다.${NC}"
    echo "설치 방법: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Session Manager Plugin 설치 확인
if ! command -v session-manager-plugin &> /dev/null; then
    echo -e "${RED}❌ AWS Session Manager Plugin이 설치되어 있지 않습니다.${NC}"
    echo "설치 방법:"
    echo "  macOS: brew install --cask session-manager-plugin"
    echo "  또는: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
    exit 1
fi

echo -e "${GREEN}✅ 필수 도구 확인 완료${NC}"
echo ""

# AWS 자격 증명 확인
echo "AWS 자격 증명 확인 중..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS 자격 증명이 설정되어 있지 않습니다.${NC}"
    echo "aws configure 또는 AWS SSO 로그인을 먼저 수행하세요."
    exit 1
fi

CALLER_IDENTITY=$(aws sts get-caller-identity)
echo -e "${GREEN}✅ AWS 인증 완료${NC}"
echo "$CALLER_IDENTITY"
echo ""

# Bastion Host 찾기 (SSM Parameter Store 사용)
echo "Bastion Host 인스턴스 검색 중..."
BASTION_INSTANCE_ID=$(aws ssm get-parameter \
    --region $AWS_REGION \
    --name "/shared/bastion/instance-id" \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "")

if [ -z "$BASTION_INSTANCE_ID" ] || [ "$BASTION_INSTANCE_ID" == "None" ]; then
    echo -e "${RED}❌ Bastion Host를 찾을 수 없습니다.${NC}"
    echo "SSM Parameter Store에 /shared/bastion/instance-id가 없습니다."
    echo "Terraform으로 Bastion Host를 먼저 배포해야 합니다."
    exit 1
fi

# Bastion이 실행 중인지 확인
BASTION_STATE=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --instance-ids $BASTION_INSTANCE_ID \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null || echo "")

if [ "$BASTION_STATE" != "running" ]; then
    echo -e "${RED}❌ Bastion Host가 실행 중이 아닙니다 (상태: ${BASTION_STATE})${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Bastion Host 발견: ${BASTION_INSTANCE_ID}${NC}"
echo ""

# Stage RDS 엔드포인트 찾기
echo "Stage RDS 엔드포인트 검색 중..."
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --region $AWS_REGION \
    --db-instance-identifier staging-shared-mysql \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text 2>/dev/null || echo "")

if [ -z "$RDS_ENDPOINT" ] || [ "$RDS_ENDPOINT" == "None" ]; then
    echo -e "${YELLOW}⚠️  Stage RDS 인스턴스(staging-shared-mysql)를 찾을 수 없습니다. RDS 포트 포워딩을 건너뜁니다.${NC}"
    RDS_ENDPOINT=""
else
    echo -e "${GREEN}✅ Stage RDS 엔드포인트: ${RDS_ENDPOINT}${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}포트 포워딩 시작 (STAGE)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# PID 파일 디렉토리
PID_DIR="/tmp/fileflow-port-forward-stage"
mkdir -p $PID_DIR

# 기존 포트 포워딩 종료 함수
cleanup() {
    echo ""
    echo -e "${YELLOW}포트 포워딩 종료 중...${NC}"

    if [ -f "$PID_DIR/rds.pid" ]; then
        kill $(cat $PID_DIR/rds.pid) 2>/dev/null || true
        rm -f $PID_DIR/rds.pid
    fi

    echo -e "${GREEN}✅ 포트 포워딩 종료 완료${NC}"
    exit 0
}

# Ctrl+C 시 cleanup 실행
trap cleanup SIGINT SIGTERM

# Stage RDS 포트 포워딩 (13308 포트 사용 - Prod는 13307)
if [ -n "$RDS_ENDPOINT" ]; then
    echo "Stage RDS 포트 포워딩 시작 (localhost:13308 -> ${RDS_ENDPOINT}:3306)..."
    aws ssm start-session \
        --region $AWS_REGION \
        --target $BASTION_INSTANCE_ID \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "{\"host\":[\"${RDS_ENDPOINT}\"],\"portNumber\":[\"3306\"],\"localPortNumber\":[\"13308\"]}" \
        > /dev/null 2>&1 &

    RDS_PID=$!
    echo $RDS_PID > $PID_DIR/rds.pid
    echo -e "${GREEN}✅ Stage RDS 포트 포워딩 시작 (PID: ${RDS_PID})${NC}"
    echo ""
    echo -e "${BLUE}   ┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}   │  Stage RDS 접속 명령어:                                      │${NC}"
    echo -e "${BLUE}   │  mysql -h 127.0.0.1 -P 13308 -u admin -p                    │${NC}"
    echo -e "${BLUE}   └─────────────────────────────────────────────────────────────┘${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}포트 포워딩 활성화 완료 (STAGE)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}📌 포트 정보:${NC}"
echo -e "   - Stage RDS: localhost:13308"
echo -e "   - Prod RDS:  localhost:13307 (aws-port-forward.sh 사용)"
echo ""
echo "종료하려면 Ctrl+C를 누르세요."
echo ""

# 무한 대기 (Ctrl+C로 종료)
wait
