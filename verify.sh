#!/bin/bash
# Default values
USE_DOCKER=false
USE_LLM=false
USE_DIRECT_CONVERSION=false
VALIDATE_TRANSLATION=false
EXPLAIN_VIOLATION=false
FAST_MODE=false
DOCKER_IMAGE="esbmc"
CONTAINER_ID=""
TEMP_DIR=""
ESBMC_EXTRA_OPTS=""
LLM_MODEL="openrouter/anthropic/claude-3.5-sonnet"
TRANSLATION_MODE=""

# Prompt file paths
PYTHON_INSTRUCTION_FILE="prompts/python_prompt.txt"
CPP_INSTRUCTION_FILE="prompts/cpp_prompt.txt"
VALIDATION_INSTRUCTION_FILE="prompts/validation_prompt.txt"
EXPLANATION_INSTRUCTION_FILE="prompts/explanation_prompt.txt"

show_usage() {
  echo "Usage: ./verify.sh [--docker] [--llm] [--direct-conversion] [--image IMAGE_NAME | --container CONTAINER_ID] [--esbmc-opts \"ESBMC_OPTIONS\"] [--model MODEL_NAME] [--translate MODE] [--explain] [--fast] <filename>"
  echo "Options:"
  echo "  --docker              Run ESBMC in Docker container"
  echo "  --llm                Use LLM to convert Python/C++ to C before verification"
  echo "  --direct-conversion   Skip Shedskin and use LLM directly (requires --llm)"
  echo "  --image IMAGE_NAME    Specify Docker image (default: esbmc)"
  echo "  --container ID        Specify existing container ID"
  echo "  --esbmc-opts OPTS    Additional ESBMC options (in quotes)"
  echo "  --model MODEL_NAME    Specify LLM model (default: openrouter/anthropic/claude-3.5-sonnet)"
  echo "  --translate MODE      Set translation mode (fast|reasoning)"
  echo "                        fast: Use Gemini for quick translations"
  echo "                        reasoning: Use DeepSeek for complex translations"
  echo "  --validate-translation Validate and fix translated code"
  echo "  --explain            Explain ESBMC violations in terms of Python code"
  echo "  --fast               Enable fast mode (adds --unwind 10 --no-unwinding-assertions)"
  exit 1
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
    if grep -qE "pthread|Thread|threading" "$file"; then
        return 0
    else
        return 1
    fi
}

while [[ $# -gt 0 ]]; do
   case $1 in
       --docker) USE_DOCKER=true; shift ;;
       --llm) USE_LLM=true; shift ;;
       --direct-conversion) USE_DIRECT_CONVERSION=true; shift ;;
       --validate-translation) VALIDATE_TRANSLATION=true; shift ;;
       --explain) EXPLAIN_VIOLATION=true; shift ;;
       --fast) FAST_MODE=true; shift ;;
       --translate)
           [ -z "$2" ] && { echo "Error: --translate requires mode (fast|reasoning)"; show_usage; }
           case "$2" in
               fast)
                   USE_LLM=true
                   LLM_MODEL="openrouter/google/gemini-2.0-flash-001"
                   TRANSLATION_MODE="fast"
                   ;;
               reasoning)
                   USE_LLM=true
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

FILENAME=$(basename "$FULLPATH" .py)
DIRNAME=$(dirname "$FULLPATH")

TEMP_DIR=$(mktemp -d)
echo "Working directory: $TEMP_DIR"
OLD_PWD=$(pwd)

# Check if prompts directory exists and contains required files
[ ! -d "prompts" ] && { echo "Error: prompts directory not found"; exit 1; }
[ ! -f "prompts/explanation_prompt.txt" ] && { echo "Error: explanation_prompt.txt not found in prompts directory"; exit 1; }

# Copy import files and prompts
cp -r module_import/* "$TEMP_DIR/" 2>/dev/null
cp "$FULLPATH" "$TEMP_DIR/${FILENAME}.py"
[ -f "esbmc.py" ] && cp "esbmc.py" "$TEMP_DIR/"
[ -d "prompts" ] && cp -r prompts "$TEMP_DIR/"
for file in *.hpp; do
    [ -f "$file" ] && cp "$file" "$TEMP_DIR/${file}"
done

[ "$USE_DIRECT_CONVERSION" = true ] && [ "$USE_LLM" = false ] && { echo "Error: --direct-conversion requires --llm"; show_usage; }

cd "$TEMP_DIR"
[ -d "$OLD_PWD/venv" ] && source "$OLD_PWD/venv/bin/activate"
[ ! -z "$TRANSLATION_MODE" ] && echo "Using translation mode: $TRANSLATION_MODE with model: $LLM_MODEL"

validate_translation() {
    local original_file=$1
    local converted_file=$2
    local success=false
    local max_attempts=1
    local attempt=1

    echo "Validating translation..."
    
    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo "Validation attempt $attempt of $max_attempts..."
        FIXED_CODE_FILE=$(mktemp)
        COMBINED_FILE=$(mktemp)
        
        echo "=== ORIGINAL CODE ===" > "$COMBINED_FILE"
        cat "$original_file" >> "$COMBINED_FILE"
        echo -e "\n=== TRANSLATED CODE ===" >> "$COMBINED_FILE"
        cat "$converted_file" >> "$COMBINED_FILE"

        echo "Sending code to LLM for validation..."
        echo "----------------------------------------"
        aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
            --message-file "$VALIDATION_INSTRUCTION_FILE" \
            --read "$original_file" "$converted_file"
        success=true
        
        rm "$FIXED_CODE_FILE"
        ((attempt++))
    done
    
    return $([ "$success" = true ] && echo 0 || echo 1)
}

explain_violation() {
    local python_file=$1
    local c_file=$2
    local violation_output=$3
    local temp_file=$(mktemp)
    
    echo "Analyzing ESBMC violation..."
    
    # Create a combined file with original code, translated code, and violation
    echo "=== ORIGINAL PYTHON CODE ===" > "$temp_file"
    cat "$python_file" >> "$temp_file"
    echo -e "\n=== TRANSLATED C CODE ===" >> "$temp_file"
    cat "$c_file" >> "$temp_file"
    echo -e "\n=== ESBMC VIOLATION ===" >> "$temp_file"
    echo "$violation_output" >> "$temp_file"
    
    echo "Requesting explanation from LLM..."
    echo "----------------------------------------"
    
    # Call aider to get explanation
    aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
        --message-file "$EXPLANATION_INSTRUCTION_FILE" \
        --read "$temp_file"
    
    rm "$temp_file"
}

attempt_llm_conversion() {
    local input_file=$1
    local output_file=$2
    local instruction_file=$3
    local max_attempts=5
    local attempt=1
    local success=false

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        local CMDRUN
        echo "Attempt $attempt of $max_attempts to generate valid code..."
        
        if [ $attempt -eq 1 ]; then
            aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes --message-file "$instruction_file" --read "$input_file" "$output_file"
        else
            if [ "$USE_DOCKER" = true ]; then
                aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test --test-cmd " docker run --rm -v "$(pwd)":/workspace -w /workspace '$DOCKER_IMAGE' esbmc --parse-tree-only '$output_file'" --yes --message-file "$instruction_file" --read "$input_file" "$output_file"
            else
                aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test --test-cmd " esbmc --parse-tree-only '$output_file'" --yes --message-file "$instruction_file" --read "$input_file" "$output_file"
            fi
        fi

        if [ "$USE_DOCKER" = true ]; then
            CMDRUN="docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc"
        else
            CMDRUN="esbmc"
        fi

        if  $CMDRUN --parse-tree-only "$output_file" 2>/dev/null; then
            echo "Successfully generated valid code on attempt $attempt"
            success=true
        else
            echo "ESBMC parse tree check failed on attempt $attempt"
            [ $attempt -lt $max_attempts ] && echo "Retrying..." && sleep 1
        fi
        
        ((attempt++))
    done

    return $([ "$success" = true ] && echo 0 || echo 1)
}

SHEDSKIN_EXIT=1
if [ "$USE_DIRECT_CONVERSION" = false ]; then
    echo "Running shedskin on ${FILENAME}.py..."
    shedskin translate "${FILENAME}.py"
    SHEDSKIN_EXIT=$?
fi

if [ $SHEDSKIN_EXIT -ne 0 ] && [ "$USE_LLM" = true ]; then
    echo "Shedskin conversion failed. Attempting direct Python to C conversion using LLM..."
    
    if attempt_llm_conversion "${FILENAME}.py" "${FILENAME}.c" "$PYTHON_INSTRUCTION_FILE"; then
        echo "Successfully converted Python to C directly"
        
        if [ "$VALIDATE_TRANSLATION" = true ]; then
            if ! validate_translation "${FILENAME}.py" "${FILENAME}.c"; then
                echo "Translation validation failed"
                exit 1
            fi
        fi
        
        TARGET_FILE="${FILENAME}.c"
        USE_CPP=false
    else
        echo "Failed to convert Python to C directly"
        exit 1
    fi
elif [ -f "${FILENAME}.cpp" ]; then
    if [ "$USE_LLM" = true ]; then
        echo "Converting C++ to C using aider..."
        
        if attempt_llm_conversion "${FILENAME}.cpp" "${FILENAME}.c" "$CPP_INSTRUCTION_FILE"; then
            echo "Successfully converted C++ to C"
            
            if [ "$VALIDATE_TRANSLATION" = true ]; then
                if ! validate_translation "${FILENAME}.cpp" "${FILENAME}.c"; then
                    echo "Translation validation failed"
                    exit 1
                fi
            fi
            
            TARGET_FILE="${FILENAME}.c"
            USE_CPP=false
        else
            echo "Failed to convert C++ to C"
            exit 1
        fi
    else
        TARGET_FILE="${FILENAME}.cpp"
        USE_CPP=true
    fi
else
    echo "Error: No source file generated for verification"
    exit 1
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

ESBMC_CMD="esbmc $([ "$USE_CPP" = true ] && echo '--std c++17') --segfault-handler \
    -I/usr/include -I/usr/local/include -I. $ESBMC_EXTRA \
    $TARGET_FILE --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets --compact-trace $THREAD_OPTIONS $ESBMC_EXTRA_OPTS"

print_esbmc_cmd "$ESBMC_CMD"

# Capture ESBMC output for potential explanation
ESBMC_OUTPUT_FILE=$(mktemp)

echo "Running ESBMC..."
if [ "$USE_DOCKER" = true ]; then
    if [ ! -z "$CONTAINER_ID" ]; then
        docker exec "$CONTAINER_ID" mkdir -p /workspace
        docker cp . "$CONTAINER_ID":/workspace/
        docker exec -w /workspace "$CONTAINER_ID" bash -c "$ESBMC_CMD" 2>&1 | tee "$ESBMC_OUTPUT_FILE"
        ESBMC_EXIT=${PIPESTATUS[0]}
        docker exec "$CONTAINER_ID" rm -rf /workspace/*
    else
        docker run --rm \
            -v "$(pwd)":/workspace \
            -w /workspace \
            "$DOCKER_IMAGE" \
            bash -c "$ESBMC_CMD" 2>&1 | tee "$ESBMC_OUTPUT_FILE"
        ESBMC_EXIT=${PIPESTATUS[0]}
    fi
else
    eval "$ESBMC_CMD" 2>&1 | tee "$ESBMC_OUTPUT_FILE"
    ESBMC_EXIT=${PIPESTATUS[0]}
fi

# If verification failed and explanation was requested, explain the violation
if [ $ESBMC_EXIT -ne 0 ] && [ "$EXPLAIN_VIOLATION" = true ]; then
    echo -e "\nAnalyzing verification failure..."
    explain_violation "${FILENAME}.py" "$TARGET_FILE" "$(cat $ESBMC_OUTPUT_FILE)"
fi

rm "$ESBMC_OUTPUT_FILE"
cd "$OLD_PWD"
echo "Temporary files available in: $TEMP_DIR"
exit $ESBMC_EXIT