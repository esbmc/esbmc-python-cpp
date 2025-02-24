#!/bin/bash

# Check if a Python script is provided as an argument
if [ $# -lt 1 ]; then
    echo "Usage: $0 <python_script> [verify.sh options]"
    exit 1
fi

# Retrieve the Python script and any additional options for verify.sh
SCRIPT_PYTHON="$1"
shift  # Remove the first argument, keeping only verify.sh options

# Check if the Python file exists
if [ ! -f "$SCRIPT_PYTHON" ]; then
    echo "Error: File $SCRIPT_PYTHON does not exist."
    exit 1
fi

# Create temporary directories and files
TRACE_DIR=$(mktemp -d)  # Temporary directory for trace output
TRACE_OUTPUT=$(mktemp)  # Temporary file for trace logs
FUNCTIONS_FILE=$(mktemp) # Temporary file to store executed function names

echo "Temporary directory created: $TRACE_DIR"

# Check and activate virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -f "requirements.txt" ]; then
    echo "Creating virtual environment and installing dependencies..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
else
    echo "No virtual environment found and no requirements.txt. Running without venv."
fi

# Function to extract executed functions in real-time
extract_function_calls() {
    grep -oE 'funcname: [a-zA-Z_][a-zA-Z0-9_]*' | awk '{print $2}' | sort -u > "$FUNCTIONS_FILE"
}

# Loop to run tracing continuously
while true; do
    echo "Starting tracing for $SCRIPT_PYTHON..."
    
    # Run Python trace in real-time and capture output
    python -m trace --trace --count -C "$TRACE_DIR" "$SCRIPT_PYTHON" 2>&1 | tee "$TRACE_OUTPUT"

    # Extract function names from trace output
    extract_function_calls < "$TRACE_OUTPUT"

    # Run verify.sh for each detected function
    while read -r function_name; do
        if [[ -n "$function_name" ]]; then
            echo -e "\n🔍 Function detected: $function_name"
            echo "🛠️ Running verify.sh with ESBMC for function $function_name..."

            # Execute verify.sh in real-time
            ./verify.sh "$SCRIPT_PYTHON" --function "$function_name" "$@" 2>&1 | tee /dev/tty
        fi
    done < "$FUNCTIONS_FILE"

    # Ask if tracing should be restarted
    while true; do
        echo -e "\nDo you want to restart tracing? (y = Yes, n = No)"
        read -r REPLY
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
            break  # Restart the loop
        elif [[ "$REPLY" =~ ^[Nn]$ ]]; then
            echo "✅ Tracing completed."
            rm -rf "$TRACE_DIR" "$TRACE_OUTPUT" "$FUNCTIONS_FILE"  # Clean up temporary files
            exit 0
        else
            echo "⚠️ Invalid input. Please enter 'y' for Yes or 'n' for No."
        fi
    done
done
