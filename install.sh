#!/bin/bash

# Function to check if a brew package is installed
check_brew_package() {
    brew list $1 &>/dev/null
    return $?
}

# Function to check if a debian package is installed
check_deb_package() {
    dpkg -l "$1" &>/dev/null
    return $?
}

# Function to check if a rpm package is installed
check_rpm_package() {
    rpm -q "$1" &>/dev/null
    return $?
}

install_timeout() {
    echo "🔍 Checking for 'timeout' command..."

    # Check if timeout is available
    if command -v timeout >/dev/null 2>&1; then
        echo "✅ 'timeout' is already installed."
        return
    fi

    # macOS: Install GNU coreutils for timeout
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "🍏 Detected macOS: Installing GNU coreutils..."
        if ! command -v brew >/dev/null 2>&1; then
            echo "🚨 Homebrew not found! Installing Homebrew first..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install coreutils
        export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
        echo "✅ Installed 'gtimeout' as 'timeout'."
        return
    fi

    # Linux: Install coreutils package
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "🐧 Detected Linux: Installing coreutils..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y coreutils
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y coreutils
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm coreutils
        else
            echo "❌ Unsupported Linux package manager. Please install 'coreutils' manually."
            exit 1
        fi
        echo "✅ Installed 'timeout'."
        return
    fi

    # Windows: Install GNU coreutils in WSL (if available)
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "🪟 Detected Windows (WSL/Cygwin): Installing coreutils..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y coreutils
        else
            echo "❌ Cannot install coreutils automatically. Please install manually from https://gnuwin32.sourceforge.net/packages/coreutils.htm"
            exit 1
        fi
        echo "✅ Installed 'timeout'."
        return
    fi

    echo "❌ Could not detect a supported operating system."
    exit 1
}

check_timeout() {
    echo "🔍 Checking if 'timeout' works..."
    
    # Test timeout command with a simple sleep
    if timeout 1 sleep 2 >/dev/null 2>&1; then
        echo "✅ 'timeout' works correctly."
        return 0
    fi

    # macOS: Check if gtimeout is available
    if gtimeout 1 sleep 2 >/dev/null 2>&1; then
        echo "✅ 'gtimeout' (GNU timeout) works correctly."
        export TIMEOUT_CMD="gtimeout"
        return 0
    fi

    # If timeout is missing or not working, return failure
    echo "⚠️ 'timeout' is missing or not working."
    return 1
}

if ! check_timeout; then
    install_timeout
fi

# Detect operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    if ! check_brew_package "bdw-gc"; then
        echo "Installing bdw-gc on macOS..."
        brew install bdw-gc
    else
        echo "bdw-gc is already installed"
    fi

    if ! check_brew_package "pcre"; then
        echo "Installing pcre on macOS..."
        brew install pcre
    else
        echo "pcre is already installed"
    fi

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt-get &> /dev/null; then
        echo "Checking dependencies on Debian/Ubuntu..."
        if ! check_deb_package "libgc-dev"; then
            echo "Installing libgc-dev..."
            sudo apt-get update
            sudo apt-get install -y libgc-dev
        else
            echo "libgc-dev is already installed"
        fi

        if ! check_deb_package "libpcre3-dev"; then
            echo "Installing libpcre3-dev..."
            sudo apt-get update
            sudo apt-get install -y libpcre3-dev
        else
            echo "libpcre3-dev is already installed"
        fi

    elif command -v dnf &> /dev/null; then
        echo "Checking dependencies on Fedora..."
        if ! check_rpm_package "gc-devel"; then
            echo "Installing gc-devel..."
            sudo dnf install -y gc-devel
        else
            echo "gc-devel is already installed"
        fi

        if ! check_rpm_package "pcre-devel"; then
            echo "Installing pcre-devel..."
            sudo dnf install -y pcre-devel
        else
            echo "pcre-devel is already installed"
        fi

    else
        echo "Unsupported Linux distribution. Please install libgc-dev and libpcre3-dev manually."
        exit 1
    fi
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

# Check if virtual environment already exists
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3.12 -m venv venv
else
    echo "Virtual environment already exists"
fi

echo "Activating virtual environment..."
source venv/bin/activate

echo "Installing Python requirements..."
pip install -r requirements.txt
#pipx install aider-chat
pip install --upgrade --upgrade-strategy only-if-needed git+https://github.com/Aider-AI/aider.git
echo "Installation completed successfully!"
