#!/bin/bash
#
# Enhanced Verification Agent - Automated Setup Script
# This script sets up the complete verification environment
#

set -e  # Exit on error

echo "=========================================="
echo "Enhanced Verification Agent - Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Python version
echo "Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed${NC}"
    echo "Please install Python 3.8 or higher"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo -e "${GREEN}✓ Found Python $PYTHON_VERSION${NC}"

# Check pip
echo "Checking pip..."
if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
    echo -e "${RED}❌ pip is not installed${NC}"
    echo "Please install pip"
    exit 1
fi
echo -e "${GREEN}✓ pip is available${NC}"

# Create virtual environment
echo ""
echo "Creating virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✓ Virtual environment created${NC}"
else
    echo -e "${YELLOW}⚠ Virtual environment already exists${NC}"
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip > /dev/null 2>&1
echo -e "${GREEN}✓ pip upgraded${NC}"

# Install requirements
echo ""
echo "Installing Python packages..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    echo -e "${GREEN}✓ All packages installed${NC}"
else
    echo -e "${RED}❌ requirements.txt not found${NC}"
    exit 1
fi

# Verify installations
echo ""
echo "Verifying tool installations..."

check_tool() {
    if command -v $1 &> /dev/null; then
        VERSION=$($1 --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓ $1${NC} - $VERSION"
        return 0
    else
        echo -e "${RED}✗ $1 not found${NC}"
        return 1
    fi
}

ALL_INSTALLED=true

check_tool "mypy" || ALL_INSTALLED=false
check_tool "pylint" || ALL_INSTALLED=false
check_tool "bandit" || ALL_INSTALLED=false
check_tool "flake8" || ALL_INSTALLED=false

# Check for optional ESBMC
echo ""
echo "Checking optional tools..."
if command -v esbmc &> /dev/null; then
    echo -e "${GREEN}✓ esbmc (optional)${NC} - $(esbmc --version 2>&1 | head -n 1)"
else
    echo -e "${YELLOW}⚠ esbmc not installed (optional)${NC}"
    echo "  ESBMC enables formal verification of C code"
    echo "  Install from: https://github.com/esbmc/esbmc"
fi

# Check API key
echo ""
echo "Checking Anthropic API key..."

# Check if .env file exists
if [ -f ".env" ]; then
    # Load .env file
    export $(cat .env | grep -v '^#' | xargs)
    if [ ! -z "$ANTHROPIC_API_KEY" ]; then
        echo -e "${GREEN}✓ API key loaded from .env file${NC}"
    else
        echo -e "${YELLOW}⚠ .env file exists but ANTHROPIC_API_KEY not set${NC}"
    fi
elif [ ! -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${GREEN}✓ API key found in environment${NC}"
else
    echo -e "${YELLOW}⚠ ANTHROPIC_API_KEY not set${NC}"
    echo ""
    read -p "Enter your Anthropic API key (or press Enter to skip): " API_KEY
    if [ ! -z "$API_KEY" ]; then
        # Create .env file
        echo "ANTHROPIC_API_KEY=$API_KEY" > .env
        echo -e "${GREEN}✓ Created .env file with API key${NC}"

        # Add to .gitignore
        if [ ! -f ".gitignore" ]; then
            echo ".env" > .gitignore
            echo -e "${GREEN}✓ Created .gitignore${NC}"
        elif ! grep -q "^\.env$" .gitignore; then
            echo ".env" >> .gitignore
            echo -e "${GREEN}✓ Added .env to .gitignore${NC}"
        fi

        export ANTHROPIC_API_KEY="$API_KEY"
    else
        echo -e "${YELLOW}⚠ Skipped. Create .env file manually with:${NC}"
        echo "ANTHROPIC_API_KEY=your-key-here"
    fi
fi

# Final summary
echo ""
echo "=========================================="
echo "Setup Summary"
echo "=========================================="

if [ "$ALL_INSTALLED" = true ]; then
    echo -e "${GREEN}✓ All required tools installed successfully${NC}"
else
    echo -e "${RED}✗ Some tools failed to install${NC}"
    echo "Try: pip install --force-reinstall -r requirements.txt"
fi

echo ""
echo "Next steps:"
echo "1. Activate environment: source venv/bin/activate"
if [ ! -f ".env" ] && [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "2. Create .env file with your API key:"
    echo "   echo 'ANTHROPIC_API_KEY=your-key-here' > .env"
    echo "3. Run demo: python enhanced_verification_agent.py"
else
    echo "2. Run demo: python enhanced_verification_agent.py"
fi
echo ""
echo "For detailed usage, see SETUP.md"
echo ""

# Create example test file
cat > example_test.py << 'EOF'
def divide(a: int, b: int) -> float:
    """Safely divide two numbers."""
    if b != 0:
        return a / b
    return 0.0

result = divide(10, 2)
assert result == 5.0
print(f"Result: {result}")
EOF

echo -e "${GREEN}✓ Created example_test.py for testing${NC}"
echo "Try: python enhanced_verification_agent.py example_test.py"
echo ""
