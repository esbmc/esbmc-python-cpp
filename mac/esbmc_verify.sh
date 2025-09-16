#!/bin/bash

# ESBMC Python Verification with Auto-Fix Script - NO TEMP FILES
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

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] <python_file>

OPTIONS:
  --esbmc SCRIPT      Path to ESBMC wrapper script (default: ./esbmc-mac.sh)
  --aider SCRIPT      Path to aider wrapper script (default: ./aider.sh)
  --max-attempts N    Maximum number of fix attempts (default: 10)
  --esbmc-args ARGS   Additional arguments to pass to ESBMC (in quotes)
  --verbose          Enable verbose output
  -h, --help         Show this help message
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --esbmc)
            ESBMC_SCRIPT="$2"
            shift 2
            ;;
        --aider)
            AIDER_SCRIPT="$2"
            shift 2
            ;;
        --max-attempts)
            MAX_ATTEMPTS="$2"
            shift 2
            ;;
        --esbmc-args)
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
        *)
            if [ -z "$PYTHON_FILE" ]; then
                PYTHON_FILE="$1"
            else
                echo "Error: Too many arguments"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$PYTHON_FILE" ]; then
    echo "Error: python_file is required"
    exit 1
fi

if [ ! -f "$PYTHON_FILE" ]; then
    echo "Error: Python file '$PYTHON_FILE' does not exist"
    exit 1
fi

is_parse_error() {
    local error_output="$1"
    if echo "$error_output" | grep -qE "(failed to open input file|parse error|syntax error|ERROR.*parsing|failed to parse|SyntaxError|IndentationError|TypeError.*string argument|Function is missing.*return type|Call to untyped function)"; then
        return 0
    else
        return 1
    fi
}

run_esbmc() {
    local file="$1"
    local temp_output=$(mktemp)
    local exit_code=0

    print_status "$BLUE" "Running ESBMC on $file..."

    if [ "$VERBOSE" = true ]; then
        echo "Command: $ESBMC_SCRIPT $ESBMC_ARGS $file"
    fi

    if $ESBMC_SCRIPT $ESBMC_ARGS "$file" 2>&1 | tee "$temp_output"; then
        exit_code=0
    else
        exit_code=$?
    fi

    ESBMC_OUTPUT=$(cat "$temp_output")
    rm "$temp_output"

    if echo "$ESBMC_OUTPUT" | grep -qE "(ERROR:|error:|failed to open|TypeError|SyntaxError|NameError|AttributeError|ImportError)"; then
        return 1
    fi

    if echo "$ESBMC_OUTPUT" | grep -qE "(VERIFICATION SUCCESSFUL|No property violation found|VERIFICATION PASSED)"; then
        return 0
    fi

    if echo "$ESBMC_OUTPUT" | grep -qE "Found [0-9]+ error"; then
        return 1
    fi

    return $exit_code
}

run_aider_fix() {
    local python_file="$1"
    local error_output="$2"
    local temp_prompt=$(mktemp)

    print_status "$YELLOW" "Running aider to fix parse errors..."

    cat > "$temp_prompt" << EOF
The following Python code has parse errors that prevent ESBMC from processing it. Please fix the syntax and parse errors to make it valid Python code that ESBMC can analyze.

ESBMC Error Output:
====================
$error_output

Requirements:
1. Fix all syntax errors and parse issues
2. Ensure the code is valid Python syntax
3. Preserve the original functionality and logic
4. Add any missing imports or declarations
5. Fix any malformed constructs or indentation issues
6. Ensure compatibility with ESBMC's Python analysis

Focus only on making the code parseable - do not change the core logic.
EOF

    if [ "$VERBOSE" = true ]; then
        echo "File BEFORE aider:"
        cat "$python_file"
        echo "--- END BEFORE ---"
    fi

    echo '"$AIDER_SCRIPT" --message-file "$temp_prompt" --yes-always "$python_file"'

    "$AIDER_SCRIPT" --message-file "$temp_prompt" --yes --file "$python_file"
    local aider_exit=$?

    if [ "$VERBOSE" = true ]; then
        echo "File AFTER aider:"
        cat "$python_file"
        echo "--- END AFTER ---"
    fi

    rm "$temp_prompt"
    return $aider_exit
}

# Main loop
main() {
    local attempt=1
    local esbmc_exit_code=0

    print_status "$GREEN" "Starting ESBMC Python verification with auto-fix"
    print_status "$BLUE" "Python file: $PYTHON_FILE"
    print_status "$BLUE" "Max attempts: $MAX_ATTEMPTS"
    echo ""

    while [ $attempt -le $MAX_ATTEMPTS ]; do
        print_status "$BLUE" "=== Attempt $attempt of $MAX_ATTEMPTS ==="

        if run_esbmc "$PYTHON_FILE"; then
            print_status "$GREEN" "SUCCESS: ESBMC verification completed successfully!"
            echo ""
            print_status "$GREEN" "Final ESBMC output:"
            echo "$ESBMC_OUTPUT"
            exit 0
        else
            esbmc_exit_code=$?
            print_status "$RED" "ESBMC verification failed (exit code: $esbmc_exit_code)"

            if is_parse_error "$ESBMC_OUTPUT"; then
                print_status "$YELLOW" "Detected parse error - attempting to fix with aider..."

                if [ $attempt -eq $MAX_ATTEMPTS ]; then
                    print_status "$RED" "Maximum attempts reached. Cannot fix parse errors."
                    break
                fi

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

    print_status "$RED" "FAILED: Could not fix parse errors after $MAX_ATTEMPTS attempts"
    print_status "$RED" "Final ESBMC output:"
    echo "$ESBMC_OUTPUT"
    exit 1
}

main
