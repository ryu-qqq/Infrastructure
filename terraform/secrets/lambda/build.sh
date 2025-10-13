#!/bin/bash
# Build script for Lambda rotation function

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Lambda rotation function..."

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Copy Python file
cp rotation.py "$TMP_DIR/index.py"

# Create ZIP file
cd "$TMP_DIR"
zip -q rotation.zip index.py

# Move ZIP to lambda directory
mv rotation.zip "$SCRIPT_DIR/"

echo "Lambda function built successfully: rotation.zip"
