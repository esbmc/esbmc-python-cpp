#!/bin/bash

# Default values
USE_LOCAL_LLM=false
MODEL_NAME=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [--local-llm] [--model MODEL_NAME]"
    echo "Options:"
    echo "  --local-llm    Use local LLM via aider.sh"
    echo "  --model MODEL  Specify model name (for both local and cloud)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Use default cloud model"
    echo "  $0 --local-llm               # Use local LLM with default model"
    echo "  $0 --model claude-3-sonnet   # Use specific cloud model"
    echo "  $0 --local-llm --model llama-3.1-8b  # Use local LLM with specific model"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --local-llm)
            USE_LOCAL_LLM=true
            shift
            ;;
        --model)
            [ -z "$2" ] && { echo "Error: --model requires a model name"; show_usage; }
            MODEL_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            ;;
    esac
done

# Array of test cases with file paths and expected results
declare -a test_cases=(
    "examples/list_test.py:pass"
    "examples/assert_test.py:pass"
    "examples/random_test.py:fail"
    "examples/example_1_esbmc.py:fail"
    "examples/example_3_dataclasses.py:pass"
    "examples/test_class_inheritance.py:pass"
    "examples/example_15_dictionary.py:pass"
    "examples/example_13_sleep.py:pass"
    "examples/example_15_dictionary.py:pass"
    "examples/example_19_tuples.py:pass"
    "examples/example_31_for_loop.py:pass"
    "examples/example_32_for_loop2.py:fail"
    "examples/example_35_input.py:pass"
    "examples/example_36_comparison.py:pass"
    "examples/example_4_recursive.py:pass"
    "examples/example_27_list_lambda.py:pass"
    "examples/example_18_list.py:pass"
    "examples/example_6_lists.py:pass"
)

# Variable to track overall success
overall_success=0

# Print configuration at the start
echo -e "\nRegression Test Configuration:"
if [ "$USE_LOCAL_LLM" = true ]; then
    echo "  LLM Type: Local"
else
    echo "  LLM Type: Cloud"
fi

if [ ! -z "$MODEL_NAME" ]; then
    echo "  Model: $MODEL_NAME"
else
    echo "  Model: Default"
fi

# Print table header
echo -e "\nRunning Tests - Real-time Results:"
echo "+--------------------------------+-----------+-----------+--------+"
echo "| Test Name                      | Expected  | Actual    | Status |"
echo "+--------------------------------+-----------+-----------+--------+"
# Force output to appear immediately
echo -n "" >&2
sync

# Array to store all results
declare -a results=()

# Execute tests and display results immediately
for test in "${test_cases[@]}"; do
    file="${test%%:*}"
    expected="${test##*:}"

    # Convert expected result to numeric value
    [[ $expected == "pass" ]] && expected_result=0 || expected_result=1

    # Build verify.sh command with proper quoting
    VERIFY_CMD="./verify.sh \"$file\" --llm --direct"
    
    if [ "$USE_LOCAL_LLM" = true ]; then
        VERIFY_CMD="$VERIFY_CMD --local-llm"
    fi
    
    if [ ! -z "$MODEL_NAME" ]; then
        VERIFY_CMD="$VERIFY_CMD --model \"$MODEL_NAME\""
    fi
    
    echo "Running: $VERIFY_CMD"
    # Use eval to properly handle the quoted arguments, show output but capture result
    eval "$VERIFY_CMD"
    actual_result=$?

    # Get results in text form
    actual_text=$([ $actual_result -eq 0 ] && echo 'pass' || echo 'fail')
    match_symbol=$([ $actual_result -eq $expected_result ] && echo '✓' || echo '✗')

    # Store the result
    results+=("$(basename "$file")|$expected|$actual_text|$match_symbol")

    # Track overall success
    [[ $actual_result -ne $expected_result ]] && overall_success=1

    # Redraw the complete table
    echo -e "\nRunning Tests - Real-time Results:"
    echo "+--------------------------------+-----------+-----------+--------+"
    echo "| Test Name                      | Expected  | Actual    | Status |"
    echo "+--------------------------------+-----------+-----------+--------+"

    # Print all results so far
    for result in "${results[@]}"; do
        IFS='|' read -r test_name expected actual match <<< "$result"
        printf "| %-30s | %-9s | %-9s | %s   |\n" "$test_name" "$expected" "$actual" "$match"
    done

    echo "+--------------------------------+-----------+-----------+--------+"
    # Force output to appear immediately
    echo -n "" >&2
    sync
done

echo "+--------------------------------+-----------+-----------+--------+"

# Final status
if [[ $overall_success -eq 0 ]]; then
    echo -e "\nAll verifications passed."
    exit 0
else
    echo -e "\nSome verifications failed."
    exit 1
fi
