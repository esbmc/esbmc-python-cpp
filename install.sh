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

    # Add OpenBLAS installation for M1/M2/M3 Macs
    if ! check_brew_package "openblas"; then
        echo "Installing OpenBLAS on macOS..."
        brew install openblas
    else
        echo "OpenBLAS is already installed"
    fi

    # Force link OpenBLAS
    echo "Linking OpenBLAS..."
    brew link --force openblas

    # Set environment variables for OpenBLAS
    echo "Setting up OpenBLAS environment variables..."
    export OPENBLAS=$(brew --prefix openblas)
    export CFLAGS="-I$(brew --prefix openblas)/include ${CFLAGS}"
    export LDFLAGS="-L$(brew --prefix openblas)/lib ${LDFLAGS}"
    export PKG_CONFIG_PATH="$(brew --prefix openblas)/lib/pkgconfig:${PKG_CONFIG_PATH}"

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
        # Add OpenBLAS for Linux
        if ! check_deb_package "libopenblas-dev"; then
            echo "Installing libopenblas-dev..."
            sudo apt-get update
            sudo apt-get install -y libopenblas-dev
        else
            echo "libopenblas-dev is already installed"
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
        # Add OpenBLAS for Fedora
        if ! check_rpm_package "openblas-devel"; then
            echo "Installing openblas-devel..."
            sudo dnf install -y openblas-devel
        else
            echo "openblas-devel is already installed"
        fi
    else
        echo "Unsupported Linux distribution. Please install libgc-dev, libpcre3-dev, and libopenblas-dev manually."
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

# Install scipy first on Apple Silicon with binary wheels
if [[ "$OSTYPE" == "darwin"* ]] && [[ $(uname -m) == 'arm64' ]]; then
    echo "Installing scipy binary wheel for Apple Silicon..."
    pip install --only-binary=scipy scipy
fi

echo "Installing Python requirements..."
if [[ "$OSTYPE" == "darwin"* ]] && [[ $(uname -m) == 'arm64' ]]; then
    # For Apple Silicon (M1/M2/M3) Macs, prefer binary wheels
    pip install --prefer-binary -r requirements.txt
else
    pip install -r requirements.txt
fi

# Install aider from GitHub
echo "Installing aider-chat from GitHub..."
pip install --upgrade --upgrade-strategy only-if-needed git+https://github.com/Aider-AI/aider.git

echo "Installation completed successfully!"
