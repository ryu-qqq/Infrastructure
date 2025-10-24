#!/usr/bin/env bash
#
# Infrastructure Wizard - Shell Wrapper
#
# This script provides a convenient entry point for the Infrastructure Wizard.
# It checks dependencies and launches the Python CLI.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔧 Infrastructure Wizard"
echo "========================"
echo ""

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed${NC}"
    echo "Please install Python 3.9 or later"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo -e "${GREEN}✅ Python ${PYTHON_VERSION}${NC}"

# Check if venv exists
VENV_DIR="$SCRIPT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
    echo ""
    echo -e "${YELLOW}⚙️  Creating virtual environment...${NC}"
    python3 -m venv "$VENV_DIR"

    echo -e "${YELLOW}📦 Installing dependencies...${NC}"
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip
    "$VENV_DIR/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"

    echo -e "${GREEN}✅ Setup complete${NC}"
    echo ""
fi

# Activate venv and run wizard
source "$VENV_DIR/bin/activate"

# Run the wizard
exec python3 "$SCRIPT_DIR/infra-wizard.py" "$@"
