#!/bin/bash
# Build Lambda deployment package for Secrets Manager rotation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
ZIP_FILE="${SCRIPT_DIR}/rotation.zip"

echo "🔨 Building Lambda deployment package..."

# Clean previous build
rm -rf "${BUILD_DIR}" "${ZIP_FILE}"
mkdir -p "${BUILD_DIR}"

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r "${SCRIPT_DIR}/requirements.txt" -t "${BUILD_DIR}" --quiet

# Copy Lambda function code
echo "📄 Copying Lambda function..."
cp "${SCRIPT_DIR}/index.py" "${BUILD_DIR}/"

# Create ZIP file
echo "📦 Creating deployment package..."
cd "${BUILD_DIR}"
zip -r "${ZIP_FILE}" . -q

# Cleanup
cd "${SCRIPT_DIR}"
rm -rf "${BUILD_DIR}"

echo "✅ Build complete: ${ZIP_FILE}"
echo "📊 Package size: $(du -h "${ZIP_FILE}" | cut -f1)"
