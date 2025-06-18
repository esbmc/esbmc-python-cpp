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

    # Install LLVM for OpenMP support on macOS
    if ! check_brew_package "llvm"; then
        echo "Installing LLVM for OpenMP support..."
        brew install llvm
    else
        echo "LLVM is already installed"
    fi

    # Force link OpenBLAS
    echo "Linking OpenBLAS..."
    brew link --force openblas

    # Set environment variables for OpenBLAS and OpenMP
    echo "Setting up environment variables..."
    export OPENBLAS=$(brew --prefix openblas)
    export LLVM_PATH=$(brew --prefix llvm)
    export CC="$LLVM_PATH/bin/clang"
    export CXX="$LLVM_PATH/bin/clang++"
    export CFLAGS="-I$OPENBLAS/include -I$LLVM_PATH/include ${CFLAGS}"
    export CXXFLAGS="-I$OPENBLAS/include -I$LLVM_PATH/include ${CXXFLAGS}"
    export LDFLAGS="-L$OPENBLAS/lib -L$LLVM_PATH/lib ${LDFLAGS}"
    export PKG_CONFIG_PATH="$OPENBLAS/lib/pkgconfig:$LLVM_PATH/lib/pkgconfig:${PKG_CONFIG_PATH}"

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
    python3 -m venv venv
else
    echo "Virtual environment already exists"
fi

echo "Activating virtual environment..."
source venv/bin/activate

# For M1/M2/M3 Macs, install scipy binary wheel and disable OpenMP
if [[ "$OSTYPE" == "darwin"* ]] && [[ $(uname -m) == 'arm64' ]]; then
    echo "Configuring for Apple Silicon..."
    # Disable OpenMP on macOS to avoid compilation issues
    export SCIPY_USE_PYTHRAN=0
    export SCIPY_USE_PROPACK=0
    export NPY_USE_BLAS_ILP64=0
    export OPENBLAS_NUM_THREADS=1
    export SCIPY_ALLOW_OPENMP_BUILD=0

    # Force binary wheel installation for scipy
    pip install --only-binary=scipy scipy

    # Install other requirements with binary preference
    pip install --prefer-binary -r requirements.txt
else
    # For other platforms
    pip install -r requirements.txt
fi

# Install aider from GitHub
echo "Installing aider-chat from GitHub..."
pip install --upgrade --upgrade-strategy only-if-needed git+https://github.com/Aider-AI/aider.git

echo "Installation completed successfully!"
