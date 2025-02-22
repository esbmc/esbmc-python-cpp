#!/bin/bash

# Function to check the operating system
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Set OS type
OS_TYPE=$(detect_os)

# Check if a script file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <python_script.py>"
    exit 1
fi

SCRIPT_PATH="$1"

# Ensure the script file exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: File '$SCRIPT_PATH' not found!"
    exit 1
fi

# Determine the virtual environment path
VENV_DIR="./venv"

# Check if venv exists, otherwise create it
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate the virtual environment
if [ "$OS_TYPE" == "windows" ]; then
    source "$VENV_DIR/Scripts/activate"
else
    source "$VENV_DIR/bin/activate"
fi

# Ensure required packages are installed
pip install --upgrade pip > /dev/null
pip install trace > /dev/null

# Run the script with Python trace
echo "Running script with Python trace..."
python -m trace --count -C . "$SCRIPT_PATH"

# Deactivate the virtual environment
deactivate
