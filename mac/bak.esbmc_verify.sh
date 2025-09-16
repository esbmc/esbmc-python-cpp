#!/bin/bash

# ESBMC Python Verification with Auto-Fix Script
# This script verifies Python code with ESBMC and automatically fixes parse errors using aider

set -e

# Default configuration
ESBMC_SCRIPT="./esbmc-mac.sh"
AIDER_SCRIPT="./aider.sh"
MAX_ATTEMPTS=10
VERBOSE=false
ESBMC_ARGS=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] <python_file>

This script verifies Python code with ESBMC and automatically fixes parse errors using aider.

ARGUMENTS:
  python_file     The Python file to verify and potentially modify

OPTIONS:
  --esbmc SCRIPT      Path to ESBMC wrapper script (default: ./esbmc-mac.sh)
  --aider SCRIPT      Path to aider wrapper script (default: ./aider.sh)
  --max-attempts N    Maximum number of fix attempts (default: 10)
  --esbmc-args ARGS   Additional arguments to pass to ESBMC (in quotes)
  --verbose          Enable verbose output
  -h, --help         Show this help message

EXAMPLES:
  $0 program.py
  $0 --max-attempts 5 program.py
  $0 --esbmc /usr/local/bin/esbmc --aider ./custom-aider.sh program.py
  $0 --esbmc-args "--unwind 10 --no-bounds-check" program.py

WORKFLOW:
  1. Run ESBMC on python_file to verify it
  2. If verification fails due to parse issues, call aider to fix the code
  3. Repeat steps 1-2 until ESBMC accepts the file or max attempts reached
  4. Show final ESBMC verification result
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --esbmc)
            [ -z "$2" ] && { echo "Error: --esbmc requires a script path"; show_usage; exit 1; }
            ESBMC_SCRIPT="$2"
            shift 2
            ;;
        --aider)
            [ -z "$2" ] && { echo "Error: --aider requires a script path"; show_usage; exit 1; }
            AIDER_SCRIPT="$2"
            shift 2
            ;;
        --max-attempts)
            [ -z "$2" ] && { echo "Error: --max-attempts requires a number"; show_usage; exit 1; }
            if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -lt 1 ]; then
                echo "Error: --max-attempts must be a positive integer"
                exit 1
            fi
            MAX_ATTEMPTS="$2"
            shift 2
            ;;
        --esbmc-args)
            [ -z "$2" ] && { echo "Error: --esbmc-args requires arguments string"; show_usage; exit 1; }
            ESBMC_ARGS="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$PYTHON_FILE" ]; then
                PYTHON_FILE="$1"
            else
                echo "Error: Too many arguments"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$PYTHON_FILE" ]; then
    echo "Error: python_file is required"
    show_usage
    exit 1
fi

# Validate file exists and is a Python file
if [ ! -f "$PYTHON_FILE" ]; then
    echo "Error: Python file '$PYTHON_FILE' does not exist"
    exit 1
fi

if [[ ! "$PYTHON_FILE" =~ \.py$ ]]; then
    echo "Error: File '$PYTHON_FILE' is not a Python file (.py extension required)"
    exit 1
fi

# Validate script dependencies
if [ ! -x "$ESBMC_SCRIPT" ] && [ ! -f "$ESBMC_SCRIPT" ]; then
    echo "Error: ESBMC script '$ESBMC_SCRIPT' not found or not executable"
    exit 1
fi

if [ ! -x "$AIDER_SCRIPT" ] && [ ! -f "$AIDER_SCRIPT" ]; then
    echo "Error: Aider script '$AIDER_SCRIPT' not found or not executable"
    exit 1
fi

# Function to check if error is a parse error
is_parse_error() {
    local error_output="$1"
    # Common ESBMC parse error patterns
    if echo "$error_output" | grep -qE "(failed to open input file|parse error|syntax error|ERROR.*parsing|failed to parse)"; then
        return 0
    else
        return 1
    fi
}

# Function to run ESBMC
run_esbmc() {
    local file="$1"
    local temp_output=$(mktemp)
    local exit_code=0

    print_status "$BLUE" "Running ESBMC on $file..."

    if [ "$VERBOSE" = true ]; then
        echo "Command: $ESBMC_SCRIPT $ESBMC_ARGS $file"
    fi

    # Run ESBMC and capture both stdout and stderr
    if $ESBMC_SCRIPT $ESBMC_ARGS "$file" 2>&1 | tee "$temp_output"; then
        exit_code=0
    else
        exit_code=$?
    fi

    # Store output for analysis
    ESBMC_OUTPUT=$(cat "$temp_output")
    rm "$temp_output"

    return $exit_code
}

# Function to run aider to fix parse errors
run_aider_fix() {
    local python_file="$1"
    local error_output="$2"
    local temp_prompt=$(mktemp)

    print_status "$YELLOW" "Running aider to fix parse errors..."

    # Create prompt for aider
    {
        echo "The following Python code has parse errors that prevent ESBMC from processing it."
        echo "Please fix the syntax and parse errors to make it valid Python code that ESBMC can analyze."
        echo ""
        echo "ESBMC Error Output:"
        echo "===================="
        echo "$error_output"
        echo ""
        echo "Requirements:"
        echo "1. Fix all syntax errors and parse issues"
        echo "2. Ensure the code is valid Python syntax"
        echo "3. Preserve the original functionality and logic"
        echo "4. Add any missing imports or declarations"
        echo "5. Fix any malformed constructs or indentation issues"
        echo "6. Ensure compatibility with ESBMC's Python analysis"
        echo ""
        echo "Focus only on making the code parseable - do not change the core logic."
    } > "$temp_prompt"

    if [ "$VERBOSE" = true ]; then
        echo "Aider prompt:"
        cat "$temp_prompt"
        echo "---"
    fi

    # Prepare aider command - only modify the Python file
    local aider_cmd="$AIDER_SCRIPT --message-file $temp_prompt --add $python_file"

    if [ "$VERBOSE" = true ]; then
        echo "Running: $aider_cmd"
    fi

    # Run aider
    eval "$aider_cmd"
    local aider_exit=$?

    rm "$temp_prompt"
    return $aider_exit
}

# Main verification loop
main() {
    local attempt=1
    local esbmc_exit_code=0

    print_status "$GREEN" "Starting ESBMC Python verification with auto-fix"
    print_status "$BLUE" "Python file: $PYTHON_FILE"
    print_status "$BLUE" "Max attempts: $MAX_ATTEMPTS"
    echo ""

    while [ $attempt -le $MAX_ATTEMPTS ]; do
        print_status "$BLUE" "=== Attempt $attempt of $MAX_ATTEMPTS ==="

        # Run ESBMC
        if run_esbmc "$PYTHON_FILE"; then
            print_status "$GREEN" "SUCCESS: ESBMC verification completed successfully!"
            echo ""
            print_status "$GREEN" "Final ESBMC output:"
            echo "$ESBMC_OUTPUT"
            exit 0
        else
            esbmc_exit_code=$?
            print_status "$RED" "ESBMC verification failed (exit code: $esbmc_exit_code)"

            # Check if it's a parse error
            if is_parse_error "$ESBMC_OUTPUT"; then
                print_status "$YELLOW" "Detected parse error - attempting to fix with aider..."

                if [ $attempt -eq $MAX_ATTEMPTS ]; then
                    print_status "$RED" "Maximum attempts reached. Cannot fix parse errors."
                    break
                fi

                # Try to fix with aider
                if run_aider_fix "$PYTHON_FILE" "$ESBMC_OUTPUT"; then
                    print_status "$GREEN" "Aider completed - retrying ESBMC..."
                else
                    print_status "$RED" "Aider failed to fix the code"
                    exit 1
                fi
            else
                print_status "$YELLOW" "ESBMC failed but not due to parse errors."
                print_status "$GREEN" "Code is parseable. Final verification result:"
                echo ""
                print_status "$RED" "VERIFICATION FAILED:"
                echo "$ESBMC_OUTPUT"
                exit $esbmc_exit_code
            fi
        fi

        ((attempt++))
        echo ""
    done

    # If we get here, we've exceeded max attempts
    print_status "$RED" "FAILED: Could not fix parse errors after $MAX_ATTEMPTS attempts"
    print_status "$RED" "Final ESBMC output:"
    echo "$ESBMC_OUTPUT"
    exit 1
}

# Run main function
main
