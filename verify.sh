#!/bin/bash
# Default values
USE_DOCKER=false
USE_LLM=false
VALIDATE_TRANSLATION=false
VALIDATION_MODE="partial"
EXPLAIN_VIOLATION=false
FAST_MODE=false
TEST_FUNCTION=false
TEMP_DIR=""
ESBMC_EXTRA_OPTS=""
ESBMC_EXECUTABLE="esbmc"
#LLM_MODEL="openrouter/anthropic/claude-3.7-sonnet"
#LLM_MODEL="openrouter/qwen/qwen3-coder-plus"
#LLM_MODEL="openai/mlx-community/GLM-4.5-Air-4bit"
LLM_MODEL="openrouter/z-ai/glm-4.6"
TEST_FUNCTION_NAME=""
TRANSLATION_MODE=""
USE_ANALYSIS=false
LIST_TEST_FUNCTIONS=""
ANALYZED_FUNCTIONS=""
DIRECT_TRANSLATION=false  # Flag for direct translation mode
MULTI_FILE_MODE=false     # Flag for multi-file mode
INPUT_FILES=()            # Array to store multiple input files
MAIN_FILE=""              # Main file to be verified
FORCE_CONVERT=false       # Flag to force conversion of all lines/functions
USE_LOCAL_LLM=false       # Flag for using local LLM via aider.sh
C_FILE_MODE=false         # Flag for processing .c files directly


# Prompt file paths
SOURCE_INSTRUCTION_FILE="prompts/python_prompt.txt"
VALIDATION_INSTRUCTION_FILE="prompts/validation_prompt.txt"
EXPLANATION_INSTRUCTION_FILE="prompts/explanation_prompt.txt"
MULTI_FILE_INSTRUCTION_FILE="prompts/multi_file_prompt.txt"

# Run aider from venv
run_aider() {
    if [ "$USE_LOCAL_LLM" = true ]; then
        # Set environment variables for local LLM
        export OPENAI_API_KEY=dummy
        export OPENAI_API_BASE=http://localhost:8080/v1
        echo "Using local LLM with OPENAI_API_BASE=$OPENAI_API_BASE"
    fi

    if [ -d "$OLD_PWD/venv" ]; then
        PYTHON_BIN="$OLD_PWD/venv/bin/python"
        AIDER_BIN="$OLD_PWD/venv/bin/aider"
        if [ -f "$AIDER_BIN" ]; then
            "$AIDER_BIN" "$@"
        else
            "$PYTHON_BIN" -m aider "$@"
        fi
    else
        echo "Warning: Virtual environment not found, using system aider"
        aider "$@"
    fi
}

show_usage() {
    echo "Usage: ./verify.sh [--docker] [--llm] [--image IMAGE_NAME | --container CONTAINER_ID] [--esbmc-opts \"ESBMC_OPTIONS\"] [--esbmc-exec EXECUTABLE] [--model MODEL_NAME] [--translate MODE] [--function FUNCTION_NAME] [--explain] [--fast] [--validate-translation MODE] [--analyze] [--direct] [--multi-file MAIN_FILE] [--force-convert] [--local-llm] [--c-file] <filename> [<filename2> <filename3> ...]"
    echo "Options:"
    echo "  --docker              Run ESBMC in Docker container"
    echo "  --image IMAGE_NAME    Specify Docker image (default: esbmc)"
    echo "  --container ID        Specify existing container ID"
    echo "  --esbmc-opts OPTS     Additional ESBMC options (in quotes)"
    echo "  --esbmc-exec EXECUTABLE  Specify custom ESBMC executable path (default: esbmc)"
    echo "  --function FUNCTION_NAME   Test function mode (adds --function)"
    echo "  --model MODEL_NAME    Specify LLM model (default: openrouter/anthropic/claude-3.7-sonnet)"
    echo "  --translate MODE      Set translation mode (fast|reasoning)"
    echo "                        fast: Use Gemini for quick translations"
    echo "                        reasoning: Use DeepSeek for complex translations"
    echo "  --validate-translation MODE Validate and fix translated code (partial|complete)"
    echo "                        partial: Basic validation of syntax and structure"
    echo "                        complete: Ensure full functional equivalence"
    echo "  --explain             Explain ESBMC violations in terms of source code"
    echo "  --fast                Enable fast mode (adds --unwind 10 --no-unwinding-assertions)"
    echo "  --analyze             Analyze and test functions that may have errors"
    echo "  --direct              Use direct LLM translation (Python to C) without shedskin"
    echo "  --multi-file MAIN_FILE Verify multiple files with MAIN_FILE as entry point"
    echo "                        (Can be used with or without --llm)"
    echo "                        Can also accept a glob pattern like '*.py' or 'src/*.py'"
    echo "  --force-convert       Force conversion of all functions with reasonable implementations"
    echo "  --model MODEL_NAME    Specify LLM model for both cloud and local LLMs"
    echo "                        Examples: openrouter/anthropic/claude-3-sonnet"
    echo "                                  openrouter/google/gemini-2.0-flash-001"
    echo "                                  openai/gpt-4"
    echo "                                  local-model-name (use with --local-llm)"
    echo "  --local-llm           Use local LLM via aider.sh (sets OPENAI_API_KEY=dummy and OPENAI_API_BASE=http://localhost:8080/v1)"
    echo "                        Use --model to specify which local model to use"
    echo "  --c-file              Process .c files directly without conversion (for debugging)"
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
    OUTPUT=$(run_aider --no-git --no-show-model-warnings --no-pretty \
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

        run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
            --message-file "$VALIDATION_INSTRUCTION_FILE" \
            --read "$COMBINED_FILE" "$converted_file"

        echo "Checking if code compiles..."
        if [ "$USE_DOCKER" = true ]; then
            CMDRUN="docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc"
                 # Run esbmc in the container with current directory mounted
            CMRUN='docker exec -w "/workspace" "${CONTAINER_NAME}" $ESBMC_EXECUTABLE "$@"'
        else
            CMDRUN="esbmc"
        fi

        if [ "$USE_DOCKER" = true ]; then
            # For Docker, we need to capture the exit code differently
            $CMDRUN --parse-tree-only "$converted_file" 2>/dev/null
            docker_exit_code=$?
            if [ $docker_exit_code -eq 0 ]; then
                echo "Compilation successful"
                success=true
            else
                echo "Compilation failing on attempt $attempt (exit code: $docker_exit_code) - will retry with fixes..."
                echo "Requesting LLM to fix compilation errors and try again..."
                sleep 1
            fi
        else
            # For local execution, use the original method
            if $CMDRUN --parse-tree-only "$converted_file" 2>/dev/null; then
                echo "Compilation successful"
                success=true
            else
                echo "Compilation failing on attempt $attempt - will retry with fixes..."
                echo "Requesting LLM to fix compilation errors and try again..."
                sleep 1
            fi
        fi

        ((attempt++))
    done

    rm -f "$VALIDATION_LOG" "$COMBINED_FILE"
    return 0
}

attempt_llm_conversion() {
    local input_file=$1
    local output_file=$2
    local max_attempts=10
    local attempt=1
    local success=false
    local file_extension="${input_file##*.}"

    local TEMP_PROMPT="$TEMP_DIR/aider_prompt.txt"
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
        echo "6. CRITICAL: NEVER define ESBMC-specific functions like __ESBMC_assume, __ESBMC_assert, etc."
        echo "   ESBMC provides its own headers and definitions for these functions"
        echo "7. Do NOT include any ESBMC internal headers or definitions"
        if [ "$TEST_FUNCTION" = true ]; then
            echo "6. Ensure the function '$TEST_FUNCTION_NAME' is correctly converted with:"
            echo "   - Same function name preserved in C"
            echo "   - Equivalent parameter types and return type"
            echo "   - All function logic maintained exactly"
        fi
        if [ ! -z "$analysis_message" ]; then
            echo -e "$analysis_message"
        fi
        if [ "$FORCE_CONVERT" = true ]; then
            echo "IMPORTANT: Implement ALL functions with complete, reasonable implementations."
            echo "Do NOT leave any function bodies empty or with just comments."
            echo "For functions with missing implementations in the source:"
            echo "  - Infer the intended behavior from function names, parameters, and context"
            echo "  - Implement reasonable default behavior based on the function signature"
            echo "  - Add appropriate error handling and return values"
            echo "  - Document your implementation choices with comments"
            echo "  - EVERY function must have a complete implementation with actual code"
            echo "  - Replace ALL placeholder comments like '// Implementation of X' with actual code"
            echo "  - If a function modifies state, ensure the state changes are implemented"
            echo "  - For monitor functions, implement actual monitoring logic"
            echo "  - For command functions, implement the command's actual behavior"
            echo "  - ENSURE there is a main() function in the code that demonstrates the functionality"
            echo "  - Remove any comments like 'This is a basic structure' or 'You will need to fill in'"
        fi
        cat "$SOURCE_INSTRUCTION_FILE" 2>/dev/null
    } > "$TEMP_PROMPT"

    # # Add these lines after creating the temp_prompt
    # echo "=== TEMP_PROMPT CONTENTS START ==="
    # cat "$TEMP_PROMPT"
    # echo "=== TEMP_PROMPT CONTENTS END ==="

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo "Attempt $attempt of $max_attempts to generate valid C code from ${file_extension}..."
        echo "Filename: $input_file"
        # echo "Prompt: $TEMP_PROMPT"
            # cat "$TEMP_PROMPT"  # Add this line to show the actual contents



        if [ $attempt -eq 1 ]; then
            run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
                --message-file "$TEMP_PROMPT" --read "$input_file" "$output_file"
        else
            # Include error information in subsequent attempts
            if [ -f "$TEMP_DIR/esbmc_error_$((attempt-1)).txt" ]; then
                {
                    echo ""
                    echo "=== PREVIOUS ATTEMPT ERROR ==="
                    echo "The previous compilation failed with these errors:"
                    cat "$TEMP_DIR/esbmc_error_$((attempt-1)).txt"
                    echo ""
                    echo "=== FIX INSTRUCTIONS ==="
                    echo "Please fix these specific errors:"
                    echo "1. If you see 'conflicting types for __ESBMC_assume' or similar ESBMC function errors:"
                    echo "   - REMOVE any definitions of __ESBMC_assume, __ESBMC_assert, or other ESBMC functions"
                    echo "   - These are provided by ESBMC itself and should NOT be defined"
                    echo "   - Only include standard C headers like <assert.h>, <stdlib.h>, etc."
                    echo "2. If you see syntax errors, missing semicolons, or other C compilation errors:"
                    echo "   - Fix the syntax issues in the code"
                    echo "   - Ensure all statements end with semicolons"
                    echo "   - Check for unmatched braces or parentheses"
                    echo "3. If you see 'undefined reference' errors:"
                    echo "   - Add missing function implementations"
                    echo "   - Ensure all declared functions are defined"
                    echo "4. Fix any other compilation errors shown above"
                    echo "5. Ensure the code compiles cleanly without ESBMC-specific definitions"
                    echo ""
                } >> "$TEMP_PROMPT"
            fi
            
            if [ "$USE_DOCKER" = true ]; then
                run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test \
                    --test-cmd "docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc --parse-tree-only $output_file" \
                    --yes --message-file "$TEMP_PROMPT" --read "$input_file" "$output_file"
            else
                run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test \
                    --test-cmd "esbmc --parse-tree-only $output_file" \
                    --yes --message-file "$TEMP_PROMPT" --read "$input_file" "$output_file"
            fi
        fi

        if [ "$USE_DOCKER" = true ]; then
            CMDRUN="docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc"
        else
            CMDRUN="$ESBMC_EXECUTABLE"
        fi

        # Check if the ESBMC executable is a Docker wrapper
        if [[ "$ESBMC_EXECUTABLE" == *"docker"* || "$ESBMC_EXECUTABLE" == *"esbmc-mac"* ]]; then
            # For Docker-based execution, we need to capture the exit code differently
            echo "=== VERIFY.SH DEBUG INFO ===" >&2
            echo "Detected Docker-based ESBMC executable: $ESBMC_EXECUTABLE" >&2
            echo "Current working directory: $(pwd)" >&2
            echo "Original PWD: $OLD_PWD" >&2
            
            # Convert relative path to absolute if needed
            if [[ "$ESBMC_EXECUTABLE" == ./* ]]; then
                CMDRUN="$OLD_PWD/$ESBMC_EXECUTABLE"
                echo "Converted relative path to absolute: $CMDRUN" >&2
            else
                CMDRUN="$ESBMC_EXECUTABLE"
            fi
            
            echo "Output file: $output_file" >&2
            echo "Command to be executed: $CMDRUN --parse-tree-only \"$output_file\"" >&2
            echo "File exists check: $(test -f "$output_file" && echo "EXISTS" || echo "MISSING")" >&2
            echo "File size: $(test -f "$output_file" && wc -c < "$output_file" || echo "N/A") bytes" >&2
            echo "ESBMC executable exists: $(test -f "$CMDRUN" && echo "YES" || echo "NO")" >&2
            echo "ESBMC executable is executable: $(test -x "$CMDRUN" && echo "YES" || echo "NO")" >&2
            
            # Show first few lines of the file for debugging
            if [ -f "$output_file" ]; then
                echo "First 10 lines of output file:" >&2
                head -10 "$output_file" >&2
                echo "--- End of file preview ---" >&2
            fi
            
            # Run with explicit error output for debugging
            echo "Running command with stderr visible:" >&2
            ESBMC_ERROR_OUTPUT=$("$CMDRUN" --parse-tree-only "$output_file" 2>&1)
            docker_exit_code=$?
            echo "ESBMC command exit code: $docker_exit_code" >&2
            echo "Exit code meaning: "
            case $docker_exit_code in
                0) echo "SUCCESS" >&2 ;;
                1) echo "GENERAL ERROR" >&2 ;;
                126) echo "COMMAND NOT EXECUTABLE" >&2 ;;
                127) echo "COMMAND NOT FOUND" >&2 ;;
                *) echo "UNKNOWN ERROR CODE" >&2 ;;
            esac
            
            # Save the error output for the next attempt
            if [ $docker_exit_code -ne 0 ]; then
                echo "$ESBMC_ERROR_OUTPUT" > "$TEMP_DIR/esbmc_error_$attempt.txt"
                echo "ESBMC error output saved to: $TEMP_DIR/esbmc_error_$attempt.txt"
                echo "Full error output:" >&2
                echo "$ESBMC_ERROR_OUTPUT" >&2
            fi
            
            if [ $docker_exit_code -eq 0 ]; then
                echo "Successfully generated valid C code on attempt $attempt"
                success=true
            else
                echo "ESBMC parse tree check failed on attempt $attempt (exit code: $docker_exit_code)"
                [ $attempt -lt $max_attempts ] && echo "Retrying..." && sleep 1
            fi
        else
            # For local execution, use the original method
            echo "=== VERIFY.SH DEBUG INFO ===" >&2
            echo "Using local ESBMC executable: $ESBMC_EXECUTABLE" >&2
            echo "Current working directory: $(pwd)" >&2
            echo "Output file: $output_file" >&2
            echo "Command to be executed: $CMDRUN --parse-tree-only \"$output_file\"" >&2
            
            # Capture error output for local execution too
            ESBMC_ERROR_OUTPUT=$("$CMDRUN" --parse-tree-only "$output_file" 2>&1)
            local_exit_code=$?
            
            if [ $local_exit_code -eq 0 ]; then
                echo "Successfully generated valid C code on attempt $attempt"
                success=true
            else
                echo "ESBMC parse tree check failed on attempt $attempt (exit code: $local_exit_code)"
                # Save the error output for the next attempt
                echo "$ESBMC_ERROR_OUTPUT" > "$TEMP_DIR/esbmc_error_$attempt.txt"
                echo "ESBMC error output saved to: $TEMP_DIR/esbmc_error_$attempt.txt"
                echo "Full error output:" >&2
                echo "$ESBMC_ERROR_OUTPUT" >&2
                [ $attempt -lt $max_attempts ] && echo "Retrying..." && sleep 1
            fi
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

    run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
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
        --direct) DIRECT_TRANSLATION=true; USE_LLM=true; shift ;;
        --local-llm)
            USE_LOCAL_LLM=true
            USE_LLM=true
            # Use default local model if no custom model was specified via --model
            if [ -z "$MODEL_NAME_OVERRIDE" ]; then
                LLM_MODEL="openai/mlx-community/GLM-4.5-Air-4bit"
                echo "Using local LLM with default model: $LLM_MODEL"
            else
                echo "Using local LLM with custom model: $LLM_MODEL"
            fi
            shift
            ;;
        --c-file)
            C_FILE_MODE=true
            echo "Processing .c file directly (no conversion)"
            shift
            ;;
        --multi-file)
            [ -z "$2" ] && { echo "Error: --multi-file requires a main file name or pattern"; show_usage; }
            MULTI_FILE_MODE=true
            # Check if the argument is a glob pattern (contains * or ?)
            if [[ "$2" == *\** || "$2" == *\?* ]]; then
                GLOB_PATTERN="$2"
                # Will set MAIN_FILE later after expanding the pattern
                MAIN_FILE=""
            else
                MAIN_FILE=$(basename "$2")  # Extract just the filename, not the full path
                GLOB_PATTERN=""
            fi
            shift 2
            ;;
        --force-convert)
            FORCE_CONVERT=true
            shift
            ;;
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
        --esbmc-exec)
            [ -z "$2" ] && { echo "Error: --esbmc-exec requires executable path"; show_usage; }
            ESBMC_EXECUTABLE="$2"
            echo "Using custom ESBMC executable: $ESBMC_EXECUTABLE"
            shift 2
            ;;
        --model)
            [ -z "$2" ] && { echo "Error: --model requires a model name"; show_usage; }
            LLM_MODEL="$2"
            MODEL_NAME_OVERRIDE="$2"  # Track that a custom model was specified
            echo "Using LLM model: $LLM_MODEL"
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
        *)
            if [ "$MULTI_FILE_MODE" = true ]; then
                INPUT_FILES+=("$1")
                shift
            else
                [ -z "$FULLPATH" ] && FULLPATH="$1" || show_usage
                shift
            fi
            ;;
    esac
done

# Validate input files
if [ "$MULTI_FILE_MODE" = true ]; then
    # If a glob pattern was provided, expand it now
    if [ ! -z "$GLOB_PATTERN" ]; then
        echo "Expanding glob pattern: $GLOB_PATTERN"
        # Save the original INPUT_FILES array
        ORIGINAL_INPUT_FILES=("${INPUT_FILES[@]}")
        # Clear the INPUT_FILES array
        INPUT_FILES=()

        # Find files matching the pattern
        for file in $GLOB_PATTERN; do
            if [ -f "$file" ]; then
                INPUT_FILES+=("$file")
                echo "Added file from pattern: $file"
            fi
        done

        # Add any explicitly specified files
        for file in "${ORIGINAL_INPUT_FILES[@]}"; do
            # Check if the file is already in the INPUT_FILES array
            FILE_ALREADY_ADDED=false
            for added_file in "${INPUT_FILES[@]}"; do
                if [ "$file" = "$added_file" ]; then
                    FILE_ALREADY_ADDED=true
                    break
                fi
            done

            if [ "$FILE_ALREADY_ADDED" = false ]; then
                INPUT_FILES+=("$file")
                echo "Added explicitly specified file: $file"
            fi
        done

        # If no files were found, show an error
        [ ${#INPUT_FILES[@]} -eq 0 ] && { echo "Error: No files match the pattern $GLOB_PATTERN"; show_usage; }

        # Set the main file to the first file if not specified
        if [ -z "$MAIN_FILE" ]; then
            MAIN_FILE=$(basename "${INPUT_FILES[0]}")
            echo "Using first matched file as main: $MAIN_FILE"
        fi
    else
        [ ${#INPUT_FILES[@]} -eq 0 ] && { echo "Error: No input files provided"; show_usage; }
    fi

    # Check if main file is in the input files
    MAIN_FILE_FOUND=false
    for file in "${INPUT_FILES[@]}"; do
        if [ "$(basename "$file")" = "$MAIN_FILE" ]; then
            MAIN_FILE_FOUND=true
            break
        fi
    done

    if [ "$MAIN_FILE_FOUND" = false ]; then
        echo "Warning: Main file $MAIN_FILE not found by exact name in input files"
        echo "Looking for main file with path..."

        # Try to find the file with the full path
        for file in "${INPUT_FILES[@]}"; do
            if [[ "$file" == *"/$MAIN_FILE" || "$file" == *"$MAIN_FILE" ]]; then
                MAIN_FILE=$(basename "$file")
                MAIN_FILE_FOUND=true
                echo "Found main file as: $file"
                break
            fi
        done

        # If still not found, use the first file as main
        if [ "$MAIN_FILE_FOUND" = false ]; then
            MAIN_FILE=$(basename "${INPUT_FILES[0]}")
            echo "Using first input file as main: $MAIN_FILE"
        fi
    fi

    # Check if all files exist
    for file in "${INPUT_FILES[@]}"; do
        [ ! -f "$file" ] && { echo "Error: Source file $file does not exist"; exit 1; }
    done

    FULLPATH="${INPUT_FILES[0]}"  # Use first file for directory info
    FILENAME=$(basename "$MAIN_FILE")
    BASENAME="${FILENAME%.*}"
    EXTENSION="${FILENAME##*.}"
    DIRNAME=$(dirname "$FULLPATH")
else
    [ -z "$FULLPATH" ] && show_usage
    [ ! -f "$FULLPATH" ] && { echo "Error: Source file $FULLPATH does not exist"; exit 1; }

    FILENAME=$(basename "$FULLPATH")
    BASENAME="${FILENAME%.*}"
    EXTENSION="${FILENAME##*.}"
    DIRNAME=$(dirname "$FULLPATH")
fi

TEMP_DIR=$(mktemp -d)
echo "Working directory: $TEMP_DIR"
OLD_PWD=$(pwd)

# Check if prompts directory exists
[ ! -d "prompts" ] && { echo "Error: prompts directory not found"; exit 1; }
[ ! -f "prompts/explanation_prompt.txt" ] && { echo "Error: explanation_prompt.txt not found in prompts directory"; exit 1; }

# Copy prompt files to local directory first
mkdir -p prompts
cp "$SOURCE_INSTRUCTION_FILE" prompts/aider_prompt.txt 2>/dev/null

# Copy files to temp directory
cp -r module_import/* "$TEMP_DIR/" 2>/dev/null
if [ "$MULTI_FILE_MODE" = true ]; then
    for file in "${INPUT_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "Copying $file to $TEMP_DIR/$(basename "$file")"
            cp "$file" "$TEMP_DIR/$(basename "$file")"
            # Verify file was copied
            if [ ! -f "$TEMP_DIR/$(basename "$file")" ]; then
                echo "Warning: Failed to copy $file to $TEMP_DIR/$(basename "$file")"
                # Try again with absolute path
                cp "$(realpath "$file")" "$TEMP_DIR/$(basename "$file")"
                if [ ! -f "$TEMP_DIR/$(basename "$file")" ]; then
                    echo "Error: Second attempt to copy file failed"
                else
                    echo "Successfully copied $(basename "$file") to temp directory on second attempt"
                fi
            else
                echo "Successfully copied $(basename "$file") to temp directory"
            fi
        else
            echo "Warning: Source file $file does not exist"
        fi
    done
else
    cp "$FULLPATH" "$TEMP_DIR/$FILENAME"
    # Verify file was copied
    if [ ! -f "$TEMP_DIR/$FILENAME" ]; then
        echo "Warning: Failed to copy $FULLPATH to $TEMP_DIR/$FILENAME"
        # Try again with absolute path
        cp "$(realpath "$FULLPATH")" "$TEMP_DIR/$FILENAME"
    fi
fi
[ -f "esbmc.py" ] && cp "esbmc.py" "$TEMP_DIR/"
[ -d "prompts" ] && cp -r prompts "$TEMP_DIR/"
for file in *.hpp; do
    [ -f "$file" ] && cp "$file" "$TEMP_DIR/${file}"
done

# Create multi-file prompt if it doesn't exist
if [ "$MULTI_FILE_MODE" = true ] && [ ! -f "$TEMP_DIR/prompts/multi_file_prompt.txt" ]; then
    mkdir -p "$TEMP_DIR/prompts"
    cat > "$TEMP_DIR/prompts/multi_file_prompt.txt" << 'EOF'
Convert the following multiple Python files into a single coherent C program.

Important guidelines:
1. Preserve the dependency structure between files
2. Maintain all function signatures and behaviors
3. Ensure proper header includes and forward declarations
4. Organize the code logically with clear separation between modules
5. Handle imports and module references correctly
6. Preserve global variables and their initialization order
7. Ensure the main entry point works correctly

The main file is specified, and all other files are dependencies.
EOF
fi

cd "$TEMP_DIR"
[ -d "$OLD_PWD/venv" ] && source "$OLD_PWD/venv/bin/activate"
[ ! -z "$TRANSLATION_MODE" ] && echo "Using translation mode: $TRANSLATION_MODE with model: $LLM_MODEL"

# Function to check for incomplete implementations and fix them
verify_complete_implementations() {
    local c_file=$1
    local is_main_file=${2:-true}  # Default to true if not specified
    local temp_file=$(mktemp)
    local incomplete_found=false

    echo "Checking for incomplete implementations in $c_file..."

    # Check for common patterns of incomplete implementations
    if grep -E "\/\/ Implementation of|\/\/ TODO|\/\/ Not implemented|{[ \t]*\/\*[ \t]*\*\/[ \t]*}|{[ \t]*\/\/.*[ \t]*}|{[ \t]*}|\/\*[ \t]*Empty implementation[ \t]*\*\/|This is a basic|You will need to fill in|You need to fill in" "$c_file" > /dev/null; then
        incomplete_found=true
        echo "Found incomplete implementations in $c_file"

        # Create a prompt to fix incomplete implementations
        {
            echo "The C code has incomplete function implementations that need to be completed."
            echo "Please implement ALL functions with reasonable behavior based on their names, parameters, and context."
            echo ""
            echo "IMPORTANT REQUIREMENTS:"
            echo "1. Replace ALL placeholder comments with actual code"
            echo "2. No empty function bodies or bodies with just comments"
            echo "3. Implement reasonable default behavior for all functions"
            echo "4. Add appropriate error handling and return values"
            echo "5. If a function is supposed to modify state, implement the state changes"
            echo "6. For monitor functions, implement actual monitoring logic"
            echo "7. For command functions, implement the command's actual behavior"
            echo "8. Document your implementation choices with comments"
            if [ "$is_main_file" = true ]; then
                echo "9. ENSURE there is a main() function in the code"
            fi
            echo "10. Remove any comments like 'This is a basic structure' or 'You will need to fill in'"
            echo ""
            echo "=== CURRENT CODE WITH INCOMPLETE IMPLEMENTATIONS ==="
            cat "$c_file"
        } > "$temp_file"

        echo "Requesting LLM to complete implementations..."
        run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
            --message-file "$temp_file" "$c_file"

        # Verify if there are still incomplete implementations
        if grep -E "\/\/ Implementation of|\/\/ TODO|\/\/ Not implemented|{[ \t]*\/\*[ \t]*\*\/[ \t]*}|{[ \t]*\/\/.*[ \t]*}|{[ \t]*}|\/\*[ \t]*Empty implementation[ \t]*\*\/|This is a basic|You will need to fill in|You need to fill in" "$c_file" > /dev/null; then
            echo "WARNING: Some implementations may still be incomplete. Running a second pass..."

            # Create a more forceful prompt for the second pass
            {
                echo "CRITICAL: The C code STILL has incomplete function implementations that MUST be completed."
                echo "Every single function MUST have a complete implementation with actual code."
                echo ""
                echo "STRICT REQUIREMENTS:"
                echo "1. Replace ALL placeholder comments with actual code"
                echo "2. No empty function bodies or bodies with just comments"
                echo "3. Implement reasonable default behavior for all functions"
                echo "4. Add appropriate error handling and return values"
                echo "5. If a function is supposed to modify state, implement the state changes"
                echo "6. For monitor functions, implement actual monitoring logic"
                echo "7. For command functions, implement the command's actual behavior"
                echo "8. Document your implementation choices with comments"
                if [ "$is_main_file" = true ]; then
                    echo "9. ENSURE there is a main() function in the code"
                fi
                echo "10. Remove any comments like 'This is a basic structure' or 'You will need to fill in'"
                echo ""
                echo "=== CURRENT CODE WITH INCOMPLETE IMPLEMENTATIONS ==="
                cat "$c_file"
            } > "$temp_file"

            run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
                --message-file "$temp_file" "$c_file"
        fi
    else
        echo "No incomplete implementations found in $c_file"
    fi

    # Check if main function exists (only for main files)
    if [ "$is_main_file" = true ] && ! grep -q "int main" "$c_file"; then
        echo "WARNING: No main function found in $c_file. Skipping main function addition to preserve original output."
    fi

    rm -f "$temp_file"
    return 0
}

# Function to combine multiple files for LLM processing
combine_files() {
    local output_file=$1
    local main_file=$2
    shift 2
    local files=("$@")

    # Check if files exist before trying to combine them
    if [ ! -f "$main_file" ]; then
        echo "Error: Main file $main_file not found"
        return 1
    fi

    # Create the output file
    echo "=== MAIN FILE: $(basename "$main_file") ===" > "$output_file"
    echo '```python' >> "$output_file"
    if [ -f "$main_file" ]; then
        cat "$main_file" >> "$output_file"
    else
        echo "# ERROR: File $main_file not found" >> "$output_file"
    fi
    echo '```' >> "$output_file"
    echo "" >> "$output_file"

    for file in "${files[@]}"; do
        if [ "$(basename "$file")" != "$(basename "$main_file")" ] && [ -f "$file" ]; then
            echo "=== DEPENDENCY FILE: $(basename "$file") ===" >> "$output_file"
            echo '```python' >> "$output_file"
            cat "$file" >> "$output_file"
            echo '```' >> "$output_file"
            echo "" >> "$output_file"
        elif [ ! -f "$file" ]; then
            basename_file=$(basename "$file")
            echo "=== DEPENDENCY FILE: $basename_file (NOT FOUND) ===" >> "$output_file"
            echo '```python' >> "$output_file"
            echo "# ERROR: File $basename_file not found" >> "$output_file"
            echo '```' >> "$output_file"
            echo "" >> "$output_file"
        fi
    done
}

# Function for multi-file LLM conversion
attempt_multi_file_conversion() {
    local combined_file=$1
    local output_file=$2
    local main_file=$3
    local max_attempts=10
    local attempt=1
    local success=false

    # Always use combined.c as the output file name for consistency
    local original_output_file="$output_file"
    output_file="combined.c"

    # Create a copy of the combined file for reference
    local combined_file_copy=$(mktemp)
    cp "$combined_file" "$combined_file_copy"

    local TEMP_PROMPT="$TEMP_DIR/aider_prompt.txt"

    # Create the prompt file with proper permissions
    touch "$TEMP_PROMPT"
    chmod 644 "$TEMP_PROMPT"

    {
        echo "Convert the following multiple Python files into a single coherent C program."
        echo ""
        echo "The main file is: $main_file"
        echo ""
        echo "Important guidelines:"
        echo "1. Preserve the dependency structure between files"
        echo "2. Maintain all function signatures and behaviors"
        echo "3. Ensure proper header includes and forward declarations"
        echo "4. Organize the code logically with clear separation between modules"
        echo "5. Handle imports and module references correctly"
        echo "6. Preserve global variables and their initialization order"
        echo "7. Ensure the main entry point works correctly"
        echo "8. COMBINE ALL FILES into a single C file - do not create multiple output files"
        echo "9. Include ALL functionality from ALL input files in the output"
        echo "10. CRITICAL: NEVER define ESBMC-specific functions like __ESBMC_assume, __ESBMC_assert, etc."
        echo "    ESBMC provides its own headers and definitions for these functions"
        echo "11. Do NOT include any ESBMC internal headers or definitions"
        if [ "$FORCE_CONVERT" = true ]; then
            echo "10. IMPORTANT: Implement ALL functions with complete, reasonable implementations"
            echo "   Do NOT leave any function bodies empty or with just comments"
            echo "   For functions with missing implementations in the source:"
            echo "     - Infer the intended behavior from function names, parameters, and context"
            echo "     - Implement reasonable default behavior based on the function signature"
            echo "     - Add appropriate error handling and return values"
            echo "     - Document your implementation choices with comments"
            echo "     - EVERY function must have a complete implementation with actual code"
            echo "     - Replace ALL placeholder comments like '// Implementation of X' with actual code"
            echo "     - If a function modifies state, ensure the state changes are implemented"
            echo "     - For monitor functions, implement actual monitoring logic"
            echo "     - For command functions, implement the command's actual behavior"
            echo "11. ENSURE there is a main() function in the code that demonstrates the functionality"
            echo "12. Remove any comments like 'This is a basic structure' or 'You will need to fill in'"
        fi
        cat "$MULTI_FILE_INSTRUCTION_FILE" 2>/dev/null
    } > "$TEMP_PROMPT"

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo "Attempt $attempt of $max_attempts to generate valid C code from multiple Python files..."

        # Don't create an empty file before running aider

        if [ $attempt -eq 1 ]; then
            echo "Running first attempt with combined file: $combined_file"
            echo "Output will be written to: $output_file"

            # Capture aider output for debugging
            AIDER_OUTPUT=$(mktemp)
            # Verify the prompt file exists and has content
            if [ ! -s "$TEMP_PROMPT" ]; then
                echo "ERROR: Prompt file is empty or does not exist"
                echo "Prompt file path: $TEMP_PROMPT"
                echo "Prompt file contents:"
                cat "$TEMP_PROMPT"
                exit 1
            fi

            # Verify the combined file exists and has content
            if [ ! -s "$combined_file" ]; then
                echo "ERROR: Combined file is empty or does not exist"
                echo "Combined file path: $combined_file"
                exit 1
            fi

            echo "Running aider with:"
            echo "  Prompt file: $TEMP_PROMPT"
            echo "  Input file: $combined_file"
            echo "  Output file: $(pwd)/$output_file"

            # Check if we're using GLM-4.5-Air-4bit model which has known shutdown issues
            if [[ "$LLM_MODEL" == *"GLM-4.5-Air-4bit"* ]]; then
                echo "Using GLM-4.5-Air-4bit model with special error handling..."
                # Use a temporary file to capture stderr separately
                STDERR_FILE=$(mktemp)

                # Run aider with stderr redirected to a separate file
                run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
                    --message-file "$TEMP_PROMPT" --read "$combined_file" "$(pwd)/$output_file" 2> "$STDERR_FILE" | tee "$AIDER_OUTPUT"

                # Check if the specific error occurred
                if grep -q "cannot schedule new futures after shutdown" "$STDERR_FILE"; then
                    echo "WARNING: Detected GLM-4.5-Air-4bit shutdown error"
                    echo "Trying again with a different model..."

                    # Try again with a more stable model
                    BACKUP_MODEL="openrouter/anthropic/claude-3-haiku"
                    echo "Switching to backup model: $BACKUP_MODEL"

                    run_aider --no-git --no-show-model-warnings --model "$BACKUP_MODEL" --yes \
                        --message-file "$TEMP_PROMPT" --read "$combined_file" "$(pwd)/$output_file" 2>&1 | tee -a "$AIDER_OUTPUT"
                fi

                rm -f "$STDERR_FILE"
            else
                # Normal execution for other models
                run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
                    --message-file "$TEMP_PROMPT" --read "$combined_file" "$(pwd)/$output_file" 2>&1 | tee "$AIDER_OUTPUT"
            fi

            # Debug: Show aider output
            echo "=== Aider output ==="
            cat "$AIDER_OUTPUT"
            echo "=== End of aider output ==="

            # Verify output file
            if [ ! -s "$output_file" ]; then
                echo "WARNING: Output file is empty after aider run"
                echo "Aider command was:"
                echo "run_aider --no-git --no-show-model-warnings --model $LLM_MODEL --yes" \
                    "--message-file $TEMP_PROMPT --read $combined_file $(pwd)/$output_file"

                echo "ERROR: LLM failed to generate content for $output_file"
                echo "This may be due to a model error or resource limitation."
                echo "Try using a different model with --model option."
                exit 1
            fi

            rm "$AIDER_OUTPUT"
        else
            if [ "$USE_DOCKER" = true ]; then
                run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test \
                    --test-cmd "docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc --parse-tree-only $(pwd)/$output_file" \
                    --yes --message-file "$TEMP_PROMPT" --read "$combined_file" "$(pwd)/$output_file"
            else
                run_aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --test --auto-test \
                    --test-cmd "esbmc --parse-tree-only $(pwd)/$output_file" \
                    --yes --message-file "$TEMP_PROMPT" --read "$combined_file" "$(pwd)/$output_file"
            fi
        fi

        # Check if the file exists and is not empty after running aider
        if [ ! -s "$output_file" ]; then
            echo "WARNING: Output file is empty after aider run."
            echo "ERROR: LLM failed to generate content for $output_file"
            echo "This may be due to a model error or resource limitation."
            echo "Try using a different model with --model option."
            exit 1
        fi

        if [ "$USE_DOCKER" = true ]; then
            CMDRUN="docker run --rm -v $(pwd):/workspace -w /workspace $DOCKER_IMAGE esbmc"
        else
            CMDRUN="$ESBMC_EXECUTABLE"
        fi

        if [ "$USE_DOCKER" = true ]; then
            file_path="/workspace/$output_file"
        else
            file_path="$output_file"
        fi

        if [ "$USE_DOCKER" = true ]; then
            # For Docker, we need to capture the exit code differently
            $CMDRUN --parse-tree-only "$file_path" 2>/dev/null
            docker_exit_code=$?
            if [ $docker_exit_code -eq 0 ]; then
                echo "Successfully generated valid C code on attempt $attempt"
                success=true
            else
                echo "ESBMC parse tree check failed on attempt $attempt (exit code: $docker_exit_code)"
                [ $attempt -lt $max_attempts ] && echo "Retrying..." && sleep 1
            fi
        else
            # For local execution, use the original method
            if $CMDRUN --parse-tree-only "$file_path" 2>/dev/null; then
                echo "Successfully generated valid C code on attempt $attempt"
                success=true
            else
                echo "ESBMC parse tree check failed on attempt $attempt"
                [ $attempt -lt $max_attempts ] && echo "Retrying..." && sleep 1
            fi
        fi

        #if $CMDRUN --parse-tree-only "$output_file" 2>/dev/null; then
        #    echo "Successfully generated valid C code on attempt $attempt"
        #    success=true
        #else
        #    echo "ESBMC parse tree check failed on attempt $attempt"
        #    [ $attempt -lt $max_attempts ] && echo "Retrying..." && sleep 1
        #fi

        ((attempt++))
    done

    # Check if the file contains a main function
    if [ "$success" = true ] && ! grep -q "int main" "$output_file"; then
        echo "WARNING: No main function found in $output_file. Skipping main function addition to preserve original output."
    fi

    # Check for incomplete implementations
    if [ "$success" = true ] && [ "$FORCE_CONVERT" = true ]; then
        verify_complete_implementations "$output_file"
    fi

    rm -f "$TEMP_PROMPT"
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# Check if we're in C file mode
if [ "$C_FILE_MODE" = true ]; then
    echo "Processing C file directly (no conversion needed)..."
    
    # Validate that the input file is a .c file
    if [ "$EXTENSION" != "c" ]; then
        echo "Error: --c-file mode requires a .c file as input"
        exit 1
    fi
    
    # Copy the C file to temp directory
    cp "$FULLPATH" "$TEMP_DIR/$FILENAME"
    TARGET_FILE="$FILENAME"
    
    # Verify and fix incomplete implementations if force convert is enabled
    if [ "$FORCE_CONVERT" = true ]; then
        verify_complete_implementations "$TARGET_FILE"
    fi
    
elif [ "$MULTI_FILE_MODE" = true ]; then
    echo "Processing multiple Python files..."

    # Create a combined file for LLM processing in the temp dir
    COMBINED_FILE="$TEMP_DIR/combined.py"
    FILE_PATHS=()

    echo "Creating combined Python file at: $COMBINED_FILE"

    # Debug information
    echo "Files to be processed:"
    for file in "${INPUT_FILES[@]}"; do
        temp_path="$TEMP_DIR/$(basename "$file")"
        echo "  - Original: $file"
        echo "  - Temp path: $temp_path"
        if [ -f "$temp_path" ]; then
            echo "    ✓ File exists in temp directory"
        else
            echo "    ✗ File MISSING in temp directory"
        fi
        FILE_PATHS+=("$temp_path")
    done

    echo "Main file: $TEMP_DIR/$MAIN_FILE"
    if [ -f "$TEMP_DIR/$MAIN_FILE" ]; then
        echo "  ✓ Main file exists in temp directory"
    else
        echo "  ✗ Main file MISSING in temp directory"
        # Try to find the main file with full path
        for file in "${INPUT_FILES[@]}"; do
            if [[ "$file" == *"$MAIN_FILE" ]]; then
                echo "  Copying $file directly to $TEMP_DIR/$MAIN_FILE"
                cp "$file" "$TEMP_DIR/$MAIN_FILE"
                if [ -f "$TEMP_DIR/$MAIN_FILE" ]; then
                    echo "  ✓ Successfully copied main file"
                else
                    echo "  ✗ Failed to copy main file"
                fi
                break
            fi
        done
    fi

    # Convert all Python files to C files first
    if [ "$USE_LLM" = true ]; then
        echo "Converting all Python files to C using LLM..."

        # First, convert the main file
        combine_files "$COMBINED_FILE" "$TEMP_DIR/$MAIN_FILE" "${FILE_PATHS[@]}"
        echo "Combined files for LLM processing into $COMBINED_FILE"

        # Debug: Show contents of combined file
        echo "=== Combined file contents ==="
        cat "$COMBINED_FILE"
        echo "=== End of combined file ==="

        # Verify combined file exists and has content
        if [ ! -s "$COMBINED_FILE" ]; then
            echo "ERROR: Combined file is empty or does not exist"
            echo "Files attempted to combine:"
            for file in "${FILE_PATHS[@]}"; do
                echo "  - $file"
                if [ -f "$file" ]; then
                    echo "    ✓ File exists"
                    echo "    Size: $(wc -c < "$file") bytes"
                else
                    echo "    ✗ File MISSING"
                fi
            done
            exit 1
        fi

        if attempt_multi_file_conversion "$COMBINED_FILE" "${BASENAME}.c" "$MAIN_FILE"; then
            TARGET_FILE="combined.c"

            # Ensure the file exists and is not empty
            if [ ! -s "$TARGET_FILE" ]; then
                echo "ERROR: Output file $TARGET_FILE is empty or does not exist"
                # Try to debug the issue
                echo "Debugging information:"
                echo "Current directory: $(pwd)"
                echo "Files in current directory:"
                ls -la
                exit 1
            fi

            # Verify and fix incomplete implementations if force convert is enabled
            if [ "$FORCE_CONVERT" = true ]; then
                verify_complete_implementations "$TARGET_FILE"
            fi

            echo "Successfully converted main file and dependencies to C"
        else
            echo "Failed to convert multiple Python files to C using LLM"
            exit 1
        fi
    else
        # Shedskin-based conversion for multi-file
        echo "Using shedskin for multi-file conversion..."

        # Create a temporary Python file that imports all modules
        IMPORT_FILE="$TEMP_DIR/combined_imports.py"
        echo "# Auto-generated import file for shedskin multi-file processing" > "$IMPORT_FILE"
        echo "# Main file: $MAIN_FILE" >> "$IMPORT_FILE"

        # Add import statements for all files
        for file in "${FILE_PATHS[@]}"; do
            if [ -f "$file" ] && [ "$(basename "$file")" != "$MAIN_FILE" ]; then
                module_name=$(basename "$file" .py)
                echo "import $module_name" >> "$IMPORT_FILE"
            fi
        done

        # Add import for main file
        main_module=$(basename "$MAIN_FILE" .py)
        echo "import $main_module" >> "$IMPORT_FILE"
        echo "# End of imports" >> "$IMPORT_FILE"

        # Run shedskin on the main file
        echo "Running shedskin on main file: $MAIN_FILE"
        shedskin translate "$MAIN_FILE"
        SHEDSKIN_EXIT=$?

        if [ $SHEDSKIN_EXIT -eq 0 ]; then
            echo "Shedskin conversion of main file successful"
            if [ -f "${BASENAME}.cpp" ]; then
                if [ "$USE_LLM" = true ]; then
                    echo "Converting shedskin C++ output to C using LLM..."
                    if attempt_llm_conversion "${BASENAME}.cpp" "${BASENAME}.c"; then
                        TARGET_FILE="${BASENAME}.c"

                        # Verify and fix incomplete implementations if force convert is enabled
                        if [ "$FORCE_CONVERT" = true ]; then
                            verify_complete_implementations "$TARGET_FILE"
                        fi
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
            echo "Shedskin conversion failed for multi-file project"
            if [ "$USE_LLM" = true ]; then
                echo "Falling back to LLM conversion..."
                combine_files "$COMBINED_FILE" "$TEMP_DIR/$MAIN_FILE" "${FILE_PATHS[@]}"
                if attempt_multi_file_conversion "$COMBINED_FILE" "${BASENAME}.c" "$MAIN_FILE"; then
                    TARGET_FILE="combined.c"

                    # Ensure the file exists and is not empty
                    if [ ! -s "$TARGET_FILE" ]; then
                        echo "ERROR: Output file $TARGET_FILE is empty or does not exist"
                        echo "This may be due to a model error or resource limitation."

                        # Check if we're using GLM-4.5-Air-4bit model which has known shutdown issues
                        if [[ "$LLM_MODEL" == *"GLM-4.5-Air-4bit"* ]]; then
                            echo "The GLM-4.5-Air-4bit model has known issues with 'cannot schedule new futures after shutdown'"
                            echo "Try using a different model with --model option, such as:"
                            echo "  --model openrouter/anthropic/claude-3-haiku"
                            echo "  --model openrouter/anthropic/claude-3-sonnet"
                            echo "  --model openrouter/google/gemini-1.5-pro"
                        else
                            echo "Try using a different model with --model option."
                        fi

                        # Try to debug the issue
                        echo "Debugging information:"
                        echo "Current directory: $(pwd)"
                        echo "Files in current directory:"
                        ls -la
                        exit 1
                    fi

                    # Verify and fix incomplete implementations if force convert is enabled
                    if [ "$FORCE_CONVERT" = true ]; then
                        verify_complete_implementations "$TARGET_FILE"
                    fi
                else
                    echo "Failed to convert multiple Python files to C using LLM fallback"
                    exit 1
                fi
            else
                echo "Error: Shedskin conversion failed and --llm option not specified for fallback"
                exit 1
            fi
        fi
    fi

    rm -f "$COMBINED_FILE"
else
    # Single file processing (original logic)
    if [ "$EXTENSION" = "py" ]; then
        if [ "$DIRECT_TRANSLATION" = true ]; then
            echo "Using direct LLM translation from Python to C..."
            if attempt_llm_conversion "$FILENAME" "${BASENAME}.c"; then
                TARGET_FILE="${BASENAME}.c"

                # Verify and fix incomplete implementations if force convert is enabled
                if [ "$FORCE_CONVERT" = true ]; then
                    verify_complete_implementations "$TARGET_FILE"
                fi
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

                            # Verify and fix incomplete implementations if force convert is enabled
                            if [ "$FORCE_CONVERT" = true ]; then
                                verify_complete_implementations "$TARGET_FILE"
                            fi
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

                        # Verify and fix incomplete implementations if force convert is enabled
                        if [ "$FORCE_CONVERT" = true ]; then
                            verify_complete_implementations "$TARGET_FILE"
                        fi
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

                # Verify and fix incomplete implementations if force convert is enabled
                if [ "$FORCE_CONVERT" = true ]; then
                    verify_complete_implementations "$TARGET_FILE"
                fi
            else
                echo "Failed to convert source to C"
                exit 1
            fi
        else
            echo "Error: Non-Python files require --llm option for conversion"
            exit 1
        fi
    fi
fi

if [ "$VALIDATE_TRANSLATION" = true ]; then
    if ! validate_translation "$FILENAME" "$TARGET_FILE" "$VALIDATION_MODE"; then
        echo "Translation validation failed"
        exit 1
    fi
fi

# Always do a final check for incomplete implementations
echo "Performing final check for incomplete implementations..."
verify_complete_implementations "$TARGET_FILE"

# Check if the file has a main function (only for the main target file)
if ! grep -q "int main" "$TARGET_FILE"; then
    echo "WARNING: No main function found in $TARGET_FILE after all conversion steps."
    echo "Skipping main function addition to preserve original output."
    # ESBMC will likely fail without a main function, but we're preserving the original output
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

ESBMC_CMD="$ESBMC_EXECUTABLE --segfault-handler \
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

    eval "$current_cmd" 2>&1 | tee "$current_output_file"
    local exit_code=${PIPESTATUS[0]}

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
    echo "=== FINAL ESBMC EXECUTION DEBUG ===" >&2
    echo "ESBMC_EXECUTABLE: $ESBMC_EXECUTABLE" >&2
    echo "Current directory: $(pwd)" >&2
    echo "Original PWD: $OLD_PWD" >&2
            
    # Convert relative path to absolute if needed
    if [[ "$ESBMC_EXECUTABLE" == ./* ]]; then
        FINAL_ESBMC_CMD="$OLD_PWD/$ESBMC_EXECUTABLE"
        echo "Converted relative path to absolute: $FINAL_ESBMC_CMD" >&2
        # Update the command to use the absolute path
        ESBMC_CMD="${ESBMC_CMD/$ESBMC_EXECUTABLE/$FINAL_ESBMC_CMD}"
    else
        FINAL_ESBMC_CMD="$ESBMC_EXECUTABLE"
    fi
            
    echo "Target file: $TARGET_FILE" >&2
    echo "Full ESBMC command: $ESBMC_CMD" >&2
    echo "Checking if target file exists: $(test -f "$TARGET_FILE" && echo "YES" || echo "NO")" >&2
    echo "ESBMC executable exists: $(test -f "$FINAL_ESBMC_CMD" && echo "YES" || echo "NO")" >&2
    
    if [ -f "$TARGET_FILE" ]; then
        echo "Target file size: $(wc -c < "$TARGET_FILE") bytes" >&2
        echo "First 5 lines of target file:" >&2
        head -5 "$TARGET_FILE" >&2
    fi
    
    eval "$ESBMC_CMD" 2>&1 | tee "$ESBMC_OUTPUT_FILE"
    OVERALL_EXIT=${PIPESTATUS[0]}
    echo "ESBMC final exit code: $OVERALL_EXIT" >&2

    if [ $OVERALL_EXIT -ne 0 ] && [ "$EXPLAIN_VIOLATION" = true ]; then
        echo -e "\nAnalyzing verification failure..."
        explain_violation "$FILENAME" "$TARGET_FILE" "$(cat $ESBMC_OUTPUT_FILE)"
    fi

    rm "$ESBMC_OUTPUT_FILE"
fi

cd "$OLD_PWD"
echo "Temporary files available in: $TEMP_DIR"
exit $OVERALL_EXIT
