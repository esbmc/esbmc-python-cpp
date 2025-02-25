#!/bin/bash
# Default values
USE_DOCKER=false
USE_LLM=false
VALIDATE_TRANSLATION=false
VALIDATION_MODE="partial"
EXPLAIN_VIOLATION=false
FAST_MODE=false
TEST_FUNCTION=false
DOCKER_IMAGE="esbmc"
CONTAINER_ID=""
TEMP_DIR=""
ESBMC_EXTRA_OPTS=""
LLM_MODEL="openrouter/anthropic/claude-3.5-sonnet"
TEST_FUNCTION_NAME=""
TRANSLATION_MODE=""
USE_ANALYSIS=false
LIST_TEST_FUNCTIONS=""
ANALYZED_FUNCTIONS=""
DIRECT_TRANSLATION=false  # New flag for direct translation mode

# Prompt file paths
SOURCE_INSTRUCTION_FILE="prompts/python_prompt.txt"
VALIDATION_INSTRUCTION_FILE="prompts/validation_prompt.txt"
EXPLANATION_INSTRUCTION_FILE="prompts/explanation_prompt.txt"

show_usage() {
    echo "Usage: ./verify.sh [--docker] [--llm] [--image IMAGE_NAME | --container CONTAINER_ID] [--esbmc-opts \"ESBMC_OPTIONS\"] [--model MODEL_NAME] [--translate MODE] [--function FUNCTION_NAME] [--explain] [--fast] [--validate-translation MODE] [--analyze] [--direct] <filename>"
    echo "Options:"
    echo "  --docker              Run ESBMC in Docker container"
    echo "  --image IMAGE_NAME    Specify Docker image (default: esbmc)"
    echo "  --container ID        Specify existing container ID"
    echo "  --esbmc-opts OPTS    Additional ESBMC options (in quotes)"
    echo "  --function FUNCTION_NAME   Test function mode (adds --function)"
    echo "  --model MODEL_NAME    Specify LLM model (default: openrouter/anthropic/claude-3.5-sonnet)"
    echo "  --translate MODE      Set translation mode (fast|reasoning)"
    echo "                        fast: Use Gemini for quick translations"
    echo "                        reasoning: Use DeepSeek for complex translations"
    echo "  --validate-translation MODE Validate and fix translated code (partial|complete)"
    echo "                        partial: Basic validation of syntax and structure"
    echo "                        complete: Ensure full functional equivalence"
    echo "  --explain            Explain ESBMC violations in terms of source code"
    echo "  --fast               Enable fast mode (adds --unwind 10 --no-unwinding-assertions)"
    echo "  --analyze            Analyze and test functions that may have errors"
    echo "  --direct             Use direct LLM translation (Python to C) without shedskin"
    exit 1
}

analyze_code_for_errors() {
    local input_file=$1
    local temp_file=$(mktemp)
    local functions_to_test=""

    exec 1>&1
    echo "Analyzing code for potential errors..." >&2

    {
        echo "Analyze the following code and identify functions that might contain errors."
        echo ""
        echo "Return ONLY a comma-separated list of function names that should be tested."
        echo "Return the exact name of the function "
        echo "Do NOT include any other text, explanations, or formatting."
        echo ""
        echo "=== SOURCE CODE ==="
        cat "$input_file"
    } > "$temp_file"

    # Get raw output and create a list of potential function names
    OUTPUT=$(aider --no-git --no-show-model-warnings --no-pretty \
       --model "$LLM_MODEL" --yes --message-file "$temp_file" | tee /dev/tty)

    sync
    rm "$temp_file"
    echo "$OUTPUT"
}

print_esbmc_cmd() {
    local cmd=$1
    echo "----------------------------------------"
    echo "ESBMC command to be executed:"
    echo "$cmd"
    echo "----------------------------------------"
}

check_threading() {
    local file=$1
    if grep -qE "pthread|Thread|threading|goroutine|java.lang.Thread" "$file"; then
        return 0
    else
        return 1
    fi
}

validate_translation() {
    local original_file=$1
    local converted_file=$2
    local validation_mode=$3
    local attempt=1
    local success=false

    echo "Validating translation in $validation_mode mode..."

    local VALIDATION_LOG=$(mktemp)
    local COMBINED_FILE=$(mktemp)

    while [ "$success" = false ]; do
        echo "Translation attempt $attempt..."

        if [ "$USE_ANALYSIS" = true ]; then
            local analysis_message="3. Pay special attention to these potentially problematic functions:\n"
            ANALYZED_FUNCTIONS=$(analyze_code_for_errors "$input_file" | tr -d '[:space:]')
            if [ ! -z "$ANALYZED_FUNCTIONS" ]; then
                for func in $(echo "$ANALYZED_FUNCTIONS" | tr ',' ' '); do
                    if [[ $func =~ ^[a-zA-Z0-9_]+$ ]]; then
                        analysis_message+="   - Ensure function '$func' is correctly converted:\n"
                        analysis_message+="     * Same function name preserved in C\n"
                        analysis_message+="     * Equivalent parameter types and return type\n"
                        analysis_message+="     * All function logic maintained exactly\n"
                        analysis_message+="     * The function converts to c must be the same even the content is very important \n"
                    fi
                done
            fi
        fi

        {
            echo "=== TRANSLATION STATUS REQUEST ==="
            echo "Please review the current translation state and:"
            echo "1. Implement any missing functions if needed"
            echo "2. Fix any compilation errors in the current code"
            echo "$analysis_message"
            echo ""
            echo "=== ORIGINAL CODE ==="
            cat "$original_file"
            echo -e "\n=== CURRENT TRANSLATION ==="
            cat "$converted_file"
        } > "$COMBINED_FILE"

        aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
            --message-file "$VALIDATION_INSTRUCTION_FILE" \
            --read "$COMBINED_FILE" "$converted_file"

        echo "Checking if code compiles..."
        if [ "$USE_DOCKER" = true ]; then
            CMDRUN="docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc"
        else
            CMDRUN="esbmc"
        fi

        if $CMDRUN --parse-tree-only "$converted_file" 2>/dev/null; then
            echo "Compilation successful"
            success=true
        else
            echo "Compilation failing on attempt $attempt - will retry with fixes..."
            echo "Requesting LLM to fix compilation errors and try again..."
            sleep 1
        fi

        ((attempt++))
    done

    rm -f "$VALIDATION_LOG" "$COMBINED_FILE"
    return 0
}

attempt_llm_conversion() {
    local input_file=$1
    local output_file=$2
    local max_attempts=5
    local attempt=1
    local success=false
    local file_extension="${input_file##*.}"

    local TEMP_PROMPT=$(mktemp)
    if [ "$USE_ANALYSIS" = true ]; then
        local analysis_message="6. Pay special attention to these potentially problematic functions:\n"
        ANALYZED_FUNCTIONS=$(analyze_code_for_errors "$input_file" | tr -d '[:space:]')
        if [ ! -z "$ANALYZED_FUNCTIONS" ]; then
            for func in $(echo "$ANALYZED_FUNCTIONS" | tr ',' ' '); do
                if [[ $func =~ ^[a-zA-Z0-9_]+$ ]]; then
                    analysis_message+="   - Ensure function '$func' is correctly converted:\n"
                    analysis_message+="     * Same function name preserved in C\n"
                    analysis_message+="     * Equivalent parameter types and return type\n"
                    analysis_message+="     * All function logic maintained exactly\n"
                    analysis_message+="     * The function converts to c must be the same even the content is very important \n"
                fi
            done
        fi
    fi

    {
        if [ "$DIRECT_TRANSLATION" = true ] && [ "$file_extension" = "py" ]; then
            echo "Convert the following Python code directly to C code without using any intermediate steps."
        else
            echo "Convert the following ${file_extension} code to C code that can be verified by ESBMC."
        fi
        echo "Ensure the core functionality and behavior is preserved."
        echo "The converted code should:"
        echo "1. Maintain all essential logic and algorithms"
        echo "2. Handle memory management appropriately"
        echo "3. Use equivalent C data structures and types"
        echo "4. Preserve any concurrent/parallel behavior"
        echo "5. Include necessary headers and dependencies"
        if [ "$TEST_FUNCTION" = true ]; then
            echo "6. Ensure the function '$TEST_FUNCTION_NAME' is correctly converted with:"
            echo "   - Same function name preserved in C"
            echo "   - Equivalent parameter types and return type"
            echo "   - All function logic maintained exactly"
        fi
        echo "$analysis_message"
        cat "$SOURCE_INSTRUCTION_FILE" 2>/dev/null
    } > "$TEMP_PROMPT"

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo "Attempt $attempt of $max_attempts to generate valid C code from ${file_extension}..."

        if [ $attempt -eq 1 ]; then
            aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
                --message-file "$TEMP_PROMPT" --read "$input_file" "$output_file"
        else
            if [ "$USE_DOCKER" = true ]; then
                aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test \
                    --test-cmd "docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc --parse-tree-only $output_file" \
                    --yes --message-file "$TEMP_PROMPT" --read "$input_file" "$output_file"
            else
                aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test \
                    --test-cmd "esbmc --parse-tree-only $output_file" \
                    --yes --message-file "$TEMP_PROMPT" --read "$input_file" "$output_file"
            fi
        fi

        if [ "$USE_DOCKER" = true ]; then
            CMDRUN="docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc"
        else
            CMDRUN="esbmc"
        fi

        if $CMDRUN --parse-tree-only "$output_file" 2>/dev/null; then
            echo "Successfully generated valid C code on attempt $attempt"
            success=true
        else
            echo "ESBMC parse tree check failed on attempt $attempt"
            [ $attempt -lt $max_attempts ] && echo "Retrying..." && sleep 1
        fi

        ((attempt++))
    done

    rm -f "$TEMP_PROMPT"
    return $([ "$success" = true ] && echo 0 || echo 1)
}

explain_violation() {
    local source_file=$1
    local c_file=$2
    local violation_output=$3
    local temp_file=$(mktemp)

    echo "Analyzing ESBMC violation..."

    {
        echo "=== ORIGINAL SOURCE CODE ===" > "$temp_file"
        cat "$source_file" >> "$temp_file"
        echo -e "\n=== TRANSLATED C CODE ===" >> "$temp_file"
        cat "$c_file" >> "$temp_file"
        echo -e "\n=== ESBMC VIOLATION (LAST 30 LINES) ===" >> "$temp_file"
        echo "$violation_output" | tail -n 30 >> "$temp_file"
    }

    echo "Requesting explanation from LLM..."
    echo "----------------------------------------"

    aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
        --message-file "$EXPLANATION_INSTRUCTION_FILE" \
        --read "$temp_file"

    rm "$temp_file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --docker) USE_DOCKER=true; shift ;;
        --llm) USE_LLM=true; shift ;;
        --analyze) USE_ANALYSIS=true; shift ;;
        --direct) DIRECT_TRANSLATION=true; USE_LLM=true; shift ;;  # Added direct translation option
        --validate-translation)
            case "$2" in
                partial|complete)
                    VALIDATE_TRANSLATION=true
                    VALIDATION_MODE="$2"
                    shift 2
                    ;;
                *)
                    echo "Error: --validate-translation requires mode (partial|complete)"
                    show_usage
                    ;;
            esac
            ;;
        --explain) EXPLAIN_VIOLATION=true; shift ;;
        --fast) FAST_MODE=true; shift ;;
        --translate)
            [ -z "$2" ] && { echo "Error: --translate requires mode (fast|reasoning)"; show_usage; }
            case "$2" in
                fast)
                    LLM_MODEL="openrouter/google/gemini-2.0-flash-001"
                    TRANSLATION_MODE="fast"
                    ;;
                reasoning)
                    LLM_MODEL="openrouter/deepseek/deepseek-r1"
                    TRANSLATION_MODE="reasoning"
                    ;;
                *)
                    echo "Error: Invalid translation mode. Use 'fast' or 'reasoning'"
                    show_usage
                    ;;
            esac
            shift 2
            ;;
        --esbmc-opts)
            [ -z "$2" ] && { echo "Error: --esbmc-opts requires options string"; show_usage; }
            ESBMC_EXTRA_OPTS="$2"
            shift 2
            ;;
        --model)
            [ -z "$2" ] && { echo "Error: --model requires a model name"; show_usage; }
            LLM_MODEL="$2"
            shift 2
            ;;
        --function)
            [ -z "$2" ] && { echo "Error: --function requires a function name"; show_usage; }
            TEST_FUNCTION_NAME="$2"
            TEST_FUNCTION=true
            shift 2
            ;;
        --image)
            [ -z "$2" ] && { echo "Error: --image requires a Docker image name"; show_usage; }
            [ ! -z "$CONTAINER_ID" ] && { echo "Error: Cannot use both --image and --container"; show_usage; }
            DOCKER_IMAGE="$2"
            shift 2
            ;;
        --container)
            [ -z "$2" ] && { echo "Error: --container requires a container ID"; show_usage; }
            [ ! -z "$DOCKER_IMAGE" ] && [ "$DOCKER_IMAGE" != "esbmc" ] && { echo "Error: Cannot use both --image and --container"; show_usage; }
            CONTAINER_ID="$2"
            shift 2
            ;;
        -h|--help) show_usage ;;
        *) [ -z "$FULLPATH" ] && FULLPATH="$1" || show_usage; shift ;;
    esac
done

[ -z "$FULLPATH" ] && show_usage
[ ! -f "$FULLPATH" ] && { echo "Error: Source file $FULLPATH does not exist"; exit 1; }


FILENAME=$(basename "$FULLPATH")
BASENAME="${FILENAME%.*}"
EXTENSION="${FILENAME##*.}"
DIRNAME=$(dirname "$FULLPATH")

TEMP_DIR=$(mktemp -d)
echo "Working directory: $TEMP_DIR"
OLD_PWD=$(pwd)

# Check if prompts directory exists
[ ! -d "prompts" ] && { echo "Error: prompts directory not found"; exit 1; }
[ ! -f "prompts/explanation_prompt.txt" ] && { echo "Error: explanation_prompt.txt not found in prompts directory"; exit 1; }

# Copy files to temp directory
cp -r module_import/* "$TEMP_DIR/" 2>/dev/null
cp "$FULLPATH" "$TEMP_DIR/$FILENAME"
[ -f "esbmc.py" ] && cp "esbmc.py" "$TEMP_DIR/"
[ -d "prompts" ] && cp -r prompts "$TEMP_DIR/"
for file in *.hpp; do
    [ -f "$file" ] && cp "$file" "$TEMP_DIR/${file}"
done

cd "$TEMP_DIR"
[ -d "$OLD_PWD/venv" ] && source "$OLD_PWD/venv/bin/activate"
[ ! -z "$TRANSLATION_MODE" ] && echo "Using translation mode: $TRANSLATION_MODE with model: $LLM_MODEL"

# Process the input file
if [ "$EXTENSION" = "py" ]; then
    if [ "$DIRECT_TRANSLATION" = true ]; then
        echo "Using direct LLM translation from Python to C..."
        if attempt_llm_conversion "$FILENAME" "${BASENAME}.c"; then
            TARGET_FILE="${BASENAME}.c"
        else
            echo "Failed to convert Python to C using direct translation"
            exit 1
        fi
    else
        echo "Processing Python file with shedskin..."
        shedskin translate "$FILENAME"
        SHEDSKIN_EXIT=$?

        if [ $SHEDSKIN_EXIT -eq 0 ]; then
            echo "Shedskin conversion successful"
            if [ -f "${BASENAME}.cpp" ]; then
                if [ "$USE_LLM" = true ]; then
                    echo "Converting shedskin C++ output to C..."
                    if attempt_llm_conversion "${BASENAME}.cpp" "${BASENAME}.c"; then
                        TARGET_FILE="${BASENAME}.c"
                    else
                        echo "Failed to convert shedskin output to C"
                        exit 1
                    fi
                else
                    TARGET_FILE="${BASENAME}.cpp"
                fi
            else
                echo "Error: Shedskin did not generate expected output"
                exit 1
            fi
        else
            if [ "$USE_LLM" = true ]; then
                echo "Shedskin conversion failed, attempting LLM conversion..."
                if attempt_llm_conversion "$FILENAME" "${BASENAME}.c"; then
                    TARGET_FILE="${BASENAME}.c"
                else
                    echo "Failed to convert Python to C"
                    exit 1
                fi
            else
                echo "Error: Shedskin conversion failed and --llm option not specified"
                exit 1
            fi
        fi
    fi
else
    if [ "$USE_LLM" = true ]; then
        echo "Converting $EXTENSION source to C using LLM..."
        if attempt_llm_conversion "$FILENAME" "${BASENAME}.c"; then
            TARGET_FILE="${BASENAME}.c"
        else
            echo "Failed to convert source to C"
            exit 1
        fi
    else
        echo "Error: Non-Python files require --llm option for conversion"
        exit 1
    fi
fi

if [ "$VALIDATE_TRANSLATION" = true ]; then
    if ! validate_translation "$FILENAME" "$TARGET_FILE" "$VALIDATION_MODE"; then
        echo "Translation validation failed"
        exit 1
    fi
fi

echo "Checking for threading..."
THREAD_OPTIONS=""
if check_threading "$TARGET_FILE"; then
    echo "Threading detected - adding context-bound option"
    THREAD_OPTIONS="--context-bound 3 --deadlock-check"
else
    echo "No threading detected"
fi

GCC_LIB_PATH=$(dirname $(gcc -print-libgcc-file-name))
ESBMC_EXTRA=""
[ -d "$GCC_LIB_PATH/include" ] && ESBMC_EXTRA=" -I$GCC_LIB_PATH/include"

# Determine additional ESBMC options for fast mode
if [ "$FAST_MODE" = true ]; then
    ESBMC_EXTRA_OPTS="$ESBMC_EXTRA_OPTS --unwind 10 --no-unwinding-assertions"
fi

ESBMC_CMD="esbmc --segfault-handler \
    -I/usr/include -I/usr/local/include -I. $ESBMC_EXTRA \
    $TARGET_FILE --incremental-bmc --no-bounds-check --no-pointer-check --no-align-check --add-symex-value-sets $THREAD_OPTIONS"

# Function to run ESBMC for a specific function
run_esbmc_for_function() {
    local function_name=$1
    local current_opts="$ESBMC_EXTRA_OPTS --function $function_name"
    local current_cmd="$ESBMC_CMD $current_opts"
    local current_output_file=$(mktemp)

    print_esbmc_cmd "$current_opts"

    echo "----------------------------------------"
    echo "Testing function: $function_name"
    echo "ESBMC command to be executed:"
    echo "$current_cmd"
    echo "----------------------------------------"

    if [ "$USE_DOCKER" = true ]; then
        if [ ! -z "$CONTAINER_ID" ]; then
            docker exec "$CONTAINER_ID" mkdir -p /workspace
            docker cp . "$CONTAINER_ID:/workspace/"
            docker exec -w /workspace "$CONTAINER_ID" bash -c "$current_cmd" 2>&1 | tee "$current_output_file"
            local exit_code=${PIPESTATUS[0]}
            docker exec "$CONTAINER_ID" rm -rf /workspace/*
        else
            docker run --rm \
                -v "$(pwd)":/workspace \
                -w /workspace \
                "$DOCKER_IMAGE" \
                bash -c "$current_cmd" 2>&1 | tee "$current_output_file"
            local exit_code=${PIPESTATUS[0]}
        fi
    else
        eval "$current_cmd" 2>&1 | tee "$current_output_file"
        local exit_code=${PIPESTATUS[0]}
    fi

    # If verification failed and explanation was requested, explain the violation
    if [ $exit_code -ne 0 ] && [ "$EXPLAIN_VIOLATION" = true ]; then
        echo -e "\nAnalyzing verification failure for function: $function_name..."
        explain_violation "$FILENAME" "$TARGET_FILE" "$(cat $current_output_file)"
    fi

    rm "$current_output_file"
    return $exit_code
}

# Variable to track overall exit status
OVERALL_EXIT=0

if [ "$USE_ANALYSIS" = true ]; then
    echo "Running ESBMC for multiple functions..."
    if [ ! -z "$ANALYZED_FUNCTIONS" ]; then
        for func in $(echo "$ANALYZED_FUNCTIONS" | tr ',' ' '); do
            if [[ $func =~ ^[a-zA-Z0-9_]+$ ]]; then
                run_esbmc_for_function "$func"
                if [ $? -ne 0 ]; then
                    OVERALL_EXIT=1
                fi
            fi
        done
    fi
elif [ "$TEST_FUNCTION" = true ]; then
    # Single function test mode
    run_esbmc_for_function "$TEST_FUNCTION_NAME"
    OVERALL_EXIT=$?
else
    # Default mode without specific function
    ESBMC_CMD="$ESBMC_CMD $ESBMC_EXTRA_OPTS"
    print_esbmc_cmd "$ESBMC_CMD"
    ESBMC_OUTPUT_FILE=$(mktemp)

    echo "Running ESBMC..."
    if [ "$USE_DOCKER" = true ]; then
        if [ ! -z "$CONTAINER_ID" ]; then
            docker exec "$CONTAINER_ID" mkdir -p /workspace
            docker cp . "$CONTAINER_ID:/workspace/"
            docker exec -w /workspace "$CONTAINER_ID" bash -c "$ESBMC_CMD" 2>&1 | tee "$ESBMC_OUTPUT_FILE"
            OVERALL_EXIT=${PIPESTATUS[0]}
            docker exec "$CONTAINER_ID" rm -rf /workspace/*
        else
            docker run --rm \
                -v "$(pwd)":/workspace \
                -w /workspace \
                "$DOCKER_IMAGE" \
                bash -c "$ESBMC_CMD" 2>&1 | tee "$ESBMC_OUTPUT_FILE"
            OVERALL_EXIT=${PIPESTATUS[0]}
        fi
    else
        eval "$ESBMC_CMD" 2>&1 | tee "$ESBMC_OUTPUT_FILE"
        OVERALL_EXIT=${PIPESTATUS[0]}
    fi

    if [ $OVERALL_EXIT -ne 0 ] && [ "$EXPLAIN_VIOLATION" = true ]; then
        echo -e "\nAnalyzing verification failure..."
        explain_violation "$FILENAME" "$TARGET_FILE" "$(cat $ESBMC_OUTPUT_FILE)"
    fi

    rm "$ESBMC_OUTPUT_FILE"
fi

cd "$OLD_PWD"
echo "Temporary files available in: $TEMP_DIR"
exit $OVERALL_EXIT