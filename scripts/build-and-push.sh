#!/bin/bash

# ECR Build and Push Script for Atlantis
# This script builds the Atlantis Docker image and pushes it to AWS ECR

set -euo pipefail

# Configuration
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
ECR_REPOSITORY="atlantis"
ATLANTIS_VERSION="${ATLANTIS_VERSION:-v0.28.1}"
CUSTOM_TAG="${CUSTOM_TAG:-latest}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get AWS Account ID if not set
if [ -z "$AWS_ACCOUNT_ID" ]; then
    log_info "Fetching AWS Account ID..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_info "AWS Account ID: $AWS_ACCOUNT_ID"
fi

# Construct ECR repository URL
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY_URL="${ECR_URL}/${ECR_REPOSITORY}"

# Generate image tags
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Tag strategy:
# 1. Atlantis version + timestamp (e.g., v0.28.1-20240110-123456)
# 2. Atlantis version + git commit (e.g., v0.28.1-abc123)
# 3. Custom tag (e.g., latest, prod, staging)
TAG_VERSION="${ATLANTIS_VERSION}-${TIMESTAMP}"
TAG_GIT="${ATLANTIS_VERSION}-${GIT_COMMIT}"

log_info "Building Atlantis Docker image..."
log_info "Base Atlantis version: $ATLANTIS_VERSION"
log_info "Tags to be created:"
log_info "  - ${ECR_REPOSITORY_URL}:${TAG_VERSION}"
log_info "  - ${ECR_REPOSITORY_URL}:${TAG_GIT}"
log_info "  - ${ECR_REPOSITORY_URL}:${CUSTOM_TAG}"

# Build Docker image
cd "$(dirname "$0")/../docker"
docker build \
    --build-arg ATLANTIS_VERSION="$ATLANTIS_VERSION" \
    -t "${ECR_REPOSITORY}:${TAG_VERSION}" \
    -t "${ECR_REPOSITORY}:${TAG_GIT}" \
    -t "${ECR_REPOSITORY}:${CUSTOM_TAG}" \
    .

log_info "Docker image built successfully"

# Login to ECR
log_info "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_URL"

# Check if ECR repository exists
log_info "Checking if ECR repository exists..."
if ! aws ecr describe-repositories \
    --repository-names "$ECR_REPOSITORY" \
    --region "$AWS_REGION" &>/dev/null; then
    log_warn "ECR repository does not exist. Creating it..."
    log_warn "Please run 'terraform apply' in terraform/atlantis/ first"
    exit 1
fi

# Tag images for ECR
log_info "Tagging images for ECR..."
docker tag "${ECR_REPOSITORY}:${TAG_VERSION}" "${ECR_REPOSITORY_URL}:${TAG_VERSION}"
docker tag "${ECR_REPOSITORY}:${TAG_GIT}" "${ECR_REPOSITORY_URL}:${TAG_GIT}"
docker tag "${ECR_REPOSITORY}:${CUSTOM_TAG}" "${ECR_REPOSITORY_URL}:${CUSTOM_TAG}"

# Push images to ECR
log_info "Pushing images to ECR..."
docker push "${ECR_REPOSITORY_URL}:${TAG_VERSION}"
docker push "${ECR_REPOSITORY_URL}:${TAG_GIT}"
docker push "${ECR_REPOSITORY_URL}:${CUSTOM_TAG}"

log_info "Successfully pushed images to ECR:"
log_info "  - ${ECR_REPOSITORY_URL}:${TAG_VERSION}"
log_info "  - ${ECR_REPOSITORY_URL}:${TAG_GIT}"
log_info "  - ${ECR_REPOSITORY_URL}:${CUSTOM_TAG}"

# Print image digest
log_info "Fetching image digest..."
IMAGE_DIGEST=$(aws ecr describe-images \
    --repository-name "$ECR_REPOSITORY" \
    --image-ids imageTag="$TAG_VERSION" \
    --region "$AWS_REGION" \
    --query 'imageDetails[0].imageDigest' \
    --output text)

log_info "Image digest: $IMAGE_DIGEST"
log_info "Done!"
