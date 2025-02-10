#!/bin/bash
# Default values
USE_DOCKER=false
USE_LLM=false
USE_DIRECT_CONVERSION=false
VALIDATE_TRANSLATION=false
DOCKER_IMAGE="esbmc"
CONTAINER_ID=""
TEMP_DIR=""
ESBMC_EXTRA_OPTS=""
LLM_MODEL="openrouter/anthropic/claude-3.5-sonnet"  # Default model
TRANSLATION_MODE=""

# Function to show usage
show_usage() {
  echo "Usage: ./verify.sh [--docker] [--llm] [--direct-conversion] [--image IMAGE_NAME | --container CONTAINER_ID] [--esbmc-opts \"ESBMC_OPTIONS\"] [--model MODEL_NAME] [--translate MODE] <filename>"
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
  exit 1
}

# Function to print ESBMC command
print_esbmc_cmd() {
    local cmd=$1
    echo "----------------------------------------"
    echo "ESBMC command to be executed:"
    echo "$cmd"
    echo "----------------------------------------"
}

# Check if the file contains threading code
check_threading() {
    local file=$1
    if grep -qE "pthread|Thread|threading" "$file"; then
        return 0  # Contains threading
    else
        return 1  # No threading found
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
   case $1 in
       --docker) USE_DOCKER=true; shift ;;
       --llm) USE_LLM=true; shift ;;
       --direct-conversion) USE_DIRECT_CONVERSION=true; shift ;;
       --validate-translation) VALIDATE_TRANSLATION=true; shift ;;
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

# Create temporary directory and copy files
TEMP_DIR=$(mktemp -d)
echo "Working directory: $TEMP_DIR"
OLD_PWD=$(pwd)

# Copy import file
filesImport=$(ls module_import/)
for file in $filesImport
do
    cp "module_import/$file" "$TEMP_DIR/${file}"
done

# Copy necessary files
cp "$FULLPATH" "$TEMP_DIR/${FILENAME}.py"
[ -f "esbmc.py" ] && cp "esbmc.py" "$TEMP_DIR/"
if [ -f "builtin.hpp" ]; then
   for file in *.hpp; do
       cp "$file" "$TEMP_DIR/${file}"
   done
fi

# Validate options
[ "$USE_DIRECT_CONVERSION" = true ] && [ "$USE_LLM" = false ] && { echo "Error: --direct-conversion requires --llm"; show_usage; }

cd "$TEMP_DIR"

# Activate virtual environment from original directory if it exists
[ -d "$OLD_PWD/venv" ] && source "$OLD_PWD/venv/bin/activate"

# Print translation mode if set
[ ! -z "$TRANSLATION_MODE" ] && echo "Using translation mode: $TRANSLATION_MODE with model: $LLM_MODEL"

# Function to validate and fix translation
validate_translation() {
    local original_file=$1
    local converted_file=$2
    local success=false
    local max_attempts=1
    local attempt=1

    echo "Validating translation..."
    
    # Create validation instruction file
    VALIDATION_INSTRUCTION_FILE=$(mktemp)
    echo "Compare these two code files. The first is the original code and the second is its translation to C.
    Verify that the translation maintains:
    1. All functional behavior
    2. All verification properties and assertions
    3. Proper handling of data structures
    4. Threading behavior (if present)
    5. Error handling
    6. Keep the same logical assertions
    7. Keep the loop original semantics. For example, for y in range(1, 5, 1) must be translated to for(y = 1; y < 5; y++). Pay attention to the logical conditions 
    If you find any issues, provide the corrected C code that fixes these issues, following the 7 items above.
    If no issues are found, just respond with 'TRANSLATION_OK'.
    
    Focus on correctness and verification properties." > "$VALIDATION_INSTRUCTION_FILE"

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo "Validation attempt $attempt of $max_attempts..."
        
        # Create a temporary file for potential fixes
        FIXED_CODE_FILE=$(mktemp)
        
        # Create a combined file for LLM review
        COMBINED_FILE=$(mktemp)
        echo "=== ORIGINAL CODE ===" > "$COMBINED_FILE"
        cat "$original_file" >> "$COMBINED_FILE"
        echo -e "\n=== TRANSLATED CODE ===" >> "$COMBINED_FILE"
        cat "$converted_file" >> "$COMBINED_FILE"

        # Run validation using aider and capture output
        echo "Sending code to LLM for validation..."
        echo "----------------------------------------"
        aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
            --message-file "$VALIDATION_INSTRUCTION_FILE" \
            --read "$original_file" $converted_file
        success=true
        # RESPONSE=$(aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
        
        # # Display LLM's analysis
        # echo "LLM Analysis:"
        # echo "$RESPONSE"
        # echo "----------------------------------------"
        
        # # Save response to fixed code file for processing
        # echo "$RESPONSE" > "$FIXED_CODE_FILE"
        
        # # Check if the validation response indicates the translation is OK
        # if echo "$RESPONSE" | grep -q "TRANSLATION_OK"; then
        #     echo "Translation validated successfully!"
        #     success=true
        # else
        #     echo "Issues found in translation. Applying fixes..."
        #     # Extract the C code from the response and update the converted file
        #     sed -n '/```c/,/```/p' "$FIXED_CODE_FILE" | sed '1d;$d' > "$converted_file"
            
        #     # Verify the fixed code compiles
        #     if esbmc --parse-tree-only "$converted_file" 2>/dev/null; then
        #         echo "Fixed code validated successfully!"
        #         success=true
        #     else
        #         echo "Fixed code failed validation"
        #         if [ $attempt -lt $max_attempts ]; then
        #             echo "Retrying..."
        #             sleep 1
        #         fi
        #     fi
        # fi
        
        rm "$FIXED_CODE_FILE"
        ((attempt++))
    done
    
    rm "$VALIDATION_INSTRUCTION_FILE"
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Function to attempt LLM conversion with given instruction
attempt_llm_conversion() {
    local input_file=$1
    local output_file=$2
    local instruction_file=$3
    local max_attempts=5
    local attempt=1
    local success=false

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo "Attempt $attempt of $max_attempts to generate valid code..."
        
        if [ $attempt -eq 1 ]; then
            aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes --message-file "$instruction_file" --read "$input_file" "$output_file"
        else
            aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test --test-cmd "esbmc --parse-tree-only '$output_file'" --yes --message-file "$instruction_file" --read "$input_file" "$output_file"
        fi
        
        if esbmc --parse-tree-only "$output_file" 2>/dev/null; then
            echo "Successfully generated valid code on attempt $attempt"
            success=true
        else
            echo "ESBMC parse tree check failed on attempt $attempt"
            if [ $attempt -lt $max_attempts ]; then
                echo "Retrying..."
                sleep 1
            fi
        fi
        
        ((attempt++))
    done

    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Run shedskin if not using direct conversion
SHEDSKIN_EXIT=1
if [ "$USE_DIRECT_CONVERSION" = false ]; then
    echo "Running shedskin on ${FILENAME}.py..."
    shedskin translate "${FILENAME}.py"
    SHEDSKIN_EXIT=$?
fi

if [ $SHEDSKIN_EXIT -ne 0 ] && [ "$USE_LLM" = true ]; then
    echo "Shedskin conversion failed. Attempting direct Python to C conversion using LLM..."
    
    # Create instruction file for Python to C conversion
    PYTHON_INSTRUCTION_FILE=$(mktemp)
    echo "Convert this Python code to C code that can be verified by ESBMC.

    Guidelines:
    - Convert Python data structures to C equivalents (lists -> arrays, etc.)
    - Use fixed-size arrays instead of dynamic allocation when possible
    - Preserve all verification properties and assertions
    - Include necessary headers (stdio.h, stdlib.h)
    - If the code uses threading:
        * Include pthread.h
        * Use standard pthread functions for thread creation and synchronization
        * Ensure thread functions have proper signatures (void* argument, void* return)
        * Add proper mutex initialization and cleanup
        * Keep thread count bounded and explicit
    - Handle Python-specific features appropriately
    - For random/arbitrary values, use nondet_uint() (no need to declare it)
    - Keep assertions as assert() without extra conditions
    - Keep the loop original semantics. For example, for y in range(1, 5, 1) must be translated to for(y = 1; y < 5; y++). Pay attention to the logical conditions
    - Add appropriate error handling
    - Keep variable names similar where possible
    - Break complex operations into simpler steps
    - Keep the same logical assertions in the original and converted code
    - Avoid external library functions" > "$PYTHON_INSTRUCTION_FILE"
    
    if attempt_llm_conversion "${FILENAME}.py" "${FILENAME}.c" "$PYTHON_INSTRUCTION_FILE"; then
        echo "Successfully converted Python to C directly"
        
        if [ "$VALIDATE_TRANSLATION" = true ]; then
            if ! validate_translation "${FILENAME}.py" "${FILENAME}.c"; then
                echo "Translation validation failed"
                rm "$PYTHON_INSTRUCTION_FILE"
                exit 1
            fi
        fi
        
        rm "$PYTHON_INSTRUCTION_FILE"
        TARGET_FILE="${FILENAME}.c"
        USE_CPP=false
    else
        echo "Failed to convert Python to C directly"
        rm "$PYTHON_INSTRUCTION_FILE"
        exit 1
    fi
elif [ -f "${FILENAME}.cpp" ]; then
    if [ "$USE_LLM" = true ]; then
        echo "Converting C++ to C using aider..."
        CPP_INSTRUCTION_FILE=$(mktemp)
        echo "Convert this C++ code to C code, maintaining the same functionality. Remove any C++ specific features and replace them with C equivalents. Keep the verification properties intact.
        
        General Guidelines:
        - The resulting C code has to be verifiable by ESBMC
        - Avoid dynamic memory allocation when possible
        - Use fixed-size arrays
        - Model known results directly instead of computing them
        - Break complex operations into simple, verifiable steps
        - Avoid external library functions
        - Keep the original loop semantics. For example, for y in range(1, 5, 1) must be translated to for(y = 1; y < 5; y++) Pay attention to the logial conditions in the loop
	- Do not change the logical conditions
        - Always include stdio.h and stdlib.h
        - Do not oversimplify functions
        - Use nondet_uint() without ESBMC keyword
	- Keep the same logical assertions
        - Keep assertions as assert() without extra conditions" > "$CPP_INSTRUCTION_FILE"
        
        if attempt_llm_conversion "${FILENAME}.cpp" "${FILENAME}.c" "$CPP_INSTRUCTION_FILE"; then
            echo "Successfully converted C++ to C"
            
            if [ "$VALIDATE_TRANSLATION" = true ]; then
                if ! validate_translation "${FILENAME}.cpp" "${FILENAME}.c"; then
                    echo "Translation validation failed"
                    rm "$CPP_INSTRUCTION_FILE"
                    exit 1
                fi
            fi
            
            rm "$CPP_INSTRUCTION_FILE"
            TARGET_FILE="${FILENAME}.c"
            USE_CPP=false
        else
            echo "Failed to convert C++ to C"
            rm "$CPP_INSTRUCTION_FILE"
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

# Check for threading
echo "Checking for threading..."
THREAD_OPTIONS=""
if check_threading "$TARGET_FILE"; then
    echo "Threading detected - adding context-bound option"
    THREAD_OPTIONS="--context-bound 3 --deadlock-check"
else
    echo "No threading detected"
fi

# Get GCC lib path for include path
GCC_LIB_PATH=$(dirname $(gcc -print-libgcc-file-name))
ESBMC_EXTRA=""
[ -d "$GCC_LIB_PATH/include" ] && ESBMC_EXTRA=" -I$GCC_LIB_PATH/include"

# Construct the ESBMC command once
ESBMC_CMD="esbmc $([ "$USE_CPP" = true ] && echo '--std c++17') --segfault-handler \
    -I/usr/include -I/usr/local/include -I. $ESBMC_EXTRA \
    $TARGET_FILE --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets --compact-trace $THREAD_OPTIONS $ESBMC_EXTRA_OPTS"

print_esbmc_cmd "$ESBMC_CMD"

echo "Running ESBMC..."
if [ "$USE_DOCKER" = true ]; then
    if [ ! -z "$CONTAINER_ID" ]; then
        docker exec "$CONTAINER_ID" mkdir -p /workspace
        docker cp . "$CONTAINER_ID":/workspace/
        docker exec -w /workspace "$CONTAINER_ID" bash -c "$ESBMC_CMD"
        ESBMC_EXIT=$?
        docker exec "$CONTAINER_ID" rm -rf /workspace/*
    else
        docker run --rm \
            -v "$(pwd)":/workspace \
            -w /workspace \
            "$DOCKER_IMAGE" \
            bash -c "$ESBMC_CMD"
        ESBMC_EXIT=$?
    fi
else
    eval "$ESBMC_CMD"
    ESBMC_EXIT=$?
fi

cd "$OLD_PWD"
echo "Temporary files available in: $TEMP_DIR"
exit $ESBMC_EXIT
