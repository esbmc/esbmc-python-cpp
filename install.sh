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
