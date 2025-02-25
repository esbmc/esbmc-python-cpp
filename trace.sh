#!/bin/bash

# Default configuration
USE_DOCKER=false
DOCKER_IMAGE="esbmc"
LLM_MODEL="openrouter/anthropic/claude-3.5-sonnet"
CONTAINER_ID=""
SOURCE_INSTRUCTION_FILE="prompts/python_prompt.txt"
ESBMC_CMD="esbmc"

# Set DEBUG for more output
DEBUG=true

# Ensure ESBMC is installed or provide its full path

show_usage() {
    echo "Usage: ./trace.sh [--docker]  [--image IMAGE_NAME | --container CONTAINER_ID] [--model MODEL_NAME] <filename>"
    echo "Options:"
    echo "  --docker              Run ESBMC in Docker container"
    echo "  --image IMAGE_NAME    Specify Docker image (default: esbmc)"
    echo "  --container ID        Specify existing container ID"
    echo "  --model MODEL_NAME    Specify LLM model (default: openrouter/anthropic/claude-3.5-sonnet)"
    exit 1
}

debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1"
    fi
}

# Capture the Python script first
SCRIPT_PYTHON=""
PARAMS=()

# Parse command-line arguments correctly
while [[ $# -gt 0 ]]; do
    case $1 in
        --docker) USE_DOCKER=true; shift ;;
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
        *) [ -z "$SCRIPT_PYTHON" ] && SCRIPT_PYTHON="$1" || show_usage; shift ;;
    esac
done

# Validate Python script existence
if [[ -z "$SCRIPT_PYTHON" || ! -f "$SCRIPT_PYTHON" ]]; then
    echo "❌ Error: Python file '$SCRIPT_PYTHON' does not exist."
    exit 1
fi

# Create temporary workspace
TEMP_DIR=$(mktemp -d)
# Create all temporary files inside the TEMP_DIR
TRACE_OUTPUT="$TEMP_DIR/trace.out"
FUNCTIONS_FILE="$TEMP_DIR/functions.list"
LLM_INPUT="$TEMP_DIR/llm_input.txt"
touch "$TRACE_OUTPUT" "$FUNCTIONS_FILE" "$LLM_INPUT"
C_FILE_NAME="$(basename "${SCRIPT_PYTHON%.py}.c")"
C_OUTPUT="$TEMP_DIR/$C_FILE_NAME"

echo "📂 Temporary workspace: $TEMP_DIR"

# Activate virtual environment if available
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -f "requirements.txt" ]; then
    echo "🚀 Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
fi

# Function to extract executed functions from trace output
extract_function_calls() {
    grep -oE 'funcname: [a-zA-Z_][a-zA-Z0-9_]*' | awk '{print $2}' | sort -u > "$FUNCTIONS_FILE"
}

# Function to directly create C file without using aider
create_c_file_manually() {
    local py_file="$1"
    local c_file="$2"
    
    # Create a basic C version of the Python code
    cat > "$c_file" <<EOF
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>

// Converted from $(basename "$py_file")

$(cat "$FUNCTIONS_FILE" | while read func; do
    if [ "$func" != "<module>" ]; then
        echo "// Function: $func"
        echo "int $func(int a, int b) {"
        echo "    return a + b;"
        echo "}"
        echo ""
    fi
done)

int main() {
    // Main function converted from Python
    printf("Hello from C version of $(basename "$py_file")\\n");
    
    // Add assertions for each detected function
$(cat "$FUNCTIONS_FILE" | while read func; do
    if [ "$func" != "<module>" ]; then
        echo "    assert($func(1, 2) == 3);"
    fi
done)
    
    return 0;
}
EOF

    debug_log "Created initial C file: $c_file"
    return 0
}

# Function to convert Python to C using LLM with multiple attempts
convert_to_c() {
    local input_file="$SCRIPT_PYTHON"
    local output_file="$C_OUTPUT"
    local max_attempts=5
    local attempt=1
    local success=false
    local file_extension="${input_file##*.}"
    
    # Create a temporary file for the prompt in the TEMP_DIR
    local TEMP_PROMPT="$TEMP_DIR/prompt.txt"
    touch "$TEMP_PROMPT"
    
    # Add function analysis if we have traced functions
    if [ -f "$FUNCTIONS_FILE" ]; then
        local analysis_message="6. Pay special attention to these potentially problematic functions:\n"
        local ANALYZED_FUNCTIONS=$(cat "$FUNCTIONS_FILE" | tr '\n' ',' | sed 's/,$//')
        
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

    # Create a simple starting C file to work with
    create_c_file_manually "$input_file" "$output_file"
    
    # Create the prompt
    {
        echo "Convert the following Python code directly to C code."
        echo "IMPORTANT: I've already created an initial C file for you to modify. DO NOT create a new file."
        echo "EDIT THE EXISTING FILE DIRECTLY."
        echo ""
        echo "Ensure the core functionality and behavior is preserved."
        echo "The converted code should:"
        echo "1. Maintain all essential logic and algorithms"
        echo "2. Handle memory management appropriately"
        echo "3. Use equivalent C data structures and types"
        echo "4. Preserve any concurrent/parallel behavior"
        echo "5. Include necessary headers and dependencies"
        echo "6. DO NOT include compilation or execution instructions in your response"
        echo "7. Only output proper C code that can be parsed by a C compiler"
        echo "$analysis_message"
        
        # Add trace information
        echo -e "\n=== PYTHON CODE ==="
        cat "$input_file"
        
        if [ -f "$TRACE_OUTPUT" ]; then
            echo -e "\n=== TRACE INFORMATION ==="
            cat "$TRACE_OUTPUT"
        fi
        
        if [ -f "$FUNCTIONS_FILE" ]; then
            echo -e "\n=== EXECUTED FUNCTIONS ==="
            cat "$FUNCTIONS_FILE"
        fi
        
        # Include additional instructions if they exist
        cat "$SOURCE_INSTRUCTION_FILE" 2>/dev/null
        
        echo -e "\n=== INITIAL C CODE (MODIFY THIS) ==="
        cat "$output_file"
    } > "$TEMP_PROMPT"

    echo "📤 Sending code to LLM for conversion..."

    # Prepare Docker for testing if needed
    if [ "$USE_DOCKER" = true ]; then
        if [ -n "$CONTAINER_ID" ]; then
            # Use existing container
            docker exec "$CONTAINER_ID" mkdir -p /workspace
            debug_log "Using existing container: $CONTAINER_ID"
        else
            # Start a new container that stays alive for the duration of the conversion
            # Mount the TEMP_DIR as the workspace
            CONTAINER_ID=$(docker run -d --rm -v "$TEMP_DIR":/workspace -w /workspace "$DOCKER_IMAGE" sleep 3600)
            debug_log "Started new container: $CONTAINER_ID"
            echo "🐳 Docker container started: $CONTAINER_ID (mounted $TEMP_DIR as /workspace)"
        fi
    fi

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo "Attempt $attempt of $max_attempts to generate valid C code from ${file_extension}..."

        # Run aider to modify the C file
        aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
            --message-file "$TEMP_PROMPT" --file "$output_file"
        
        # Show the output file contents for debugging
        debug_log "C code after aider (first 20 lines):"
        head -n 20 "$output_file"
        
        # Check if the generated C code is valid
        if [ "$USE_DOCKER" = true ]; then
            # The file should already be accessible in the container since we're mounting TEMP_DIR
            debug_log "File $output_file should be available in the container at /workspace/$C_FILE_NAME"
            
            # Check syntax with ESBMC in Docker
            echo "Checking C syntax in Docker..."
            if docker exec "$CONTAINER_ID" esbmc --parse-tree-only "/workspace/$C_FILE_NAME" 2>/dev/null; then
                echo "✅ Successfully generated valid C code on attempt $attempt"
                success=true
            else
                echo "❌ ESBMC parse tree check failed on attempt $attempt"
                if [ $attempt -lt $max_attempts ]; then
                    echo "Retrying with additional instructions..."
                    # Add more specific instructions to fix syntax errors
                    echo -e "\n=== CORRECTION INSTRUCTIONS ===" >> "$TEMP_PROMPT"
                    echo "The previous code had syntax errors. Please fix the C code to make it valid." >> "$TEMP_PROMPT"
                    echo "Ensure you include all necessary headers and that all functions are properly defined." >> "$TEMP_PROMPT"
                    echo "Use standard C syntax and avoid any C++ features." >> "$TEMP_PROMPT"
                fi
                sleep 1
            fi
        else
            # Local ESBMC
            if esbmc --parse-tree-only "$output_file" 2>/dev/null; then
                echo "✅ Successfully generated valid C code on attempt $attempt"
                success=true
            else
                echo "❌ ESBMC parse tree check failed on attempt $attempt"
                if [ $attempt -lt $max_attempts ]; then
                    echo "Retrying with additional instructions..."
                    # Add more specific instructions to fix syntax errors
                    echo -e "\n=== CORRECTION INSTRUCTIONS ===" >> "$TEMP_PROMPT"
                    echo "The previous code had syntax errors. Please fix the C code to make it valid." >> "$TEMP_PROMPT"
                    echo "Ensure you include all necessary headers and that all functions are properly defined." >> "$TEMP_PROMPT"
                    echo "Use standard C syntax and avoid any C++ features." >> "$TEMP_PROMPT"
                fi
                sleep 1
            fi
        fi

        ((attempt++))
    done

    # Cleanup temporary container if we created one
    if [ "$USE_DOCKER" = true ] && [ -z "$CONTAINER_ID" ]; then
        docker stop "$CONTAINER_ID" >/dev/null
        echo "🐳 Docker container stopped: $CONTAINER_ID"
    fi
    
    rm -f "$TEMP_PROMPT"
    
    if [ "$success" = true ]; then
        echo "✅ LLM conversion completed successfully."
        return 0
    else
        echo "❌ Failed to generate valid C code after $max_attempts attempts."
        return 1
    fi
}

# Function to run ESBMC per function
run_esbmc_for_function() {
    local function_name=$1
    
    if [ "$function_name" = "<module>" ]; then
        function_name="main"
    fi
    
    local current_cmd="esbmc --function $function_name $C_FILE_NAME"

    echo "----------------------------------------"
    echo "🛠️ Testing function: $function_name"
    echo "ESBMC command to be executed:"
    echo "$current_cmd"
    echo "----------------------------------------"

    if [ "$USE_DOCKER" = true ]; then
        if [ -n "$CONTAINER_ID" ]; then
            # The file should already be in the container since we're mounting TEMP_DIR
            docker exec -w /workspace "$CONTAINER_ID" bash -c "$current_cmd"
        else
            docker run --rm -v "$TEMP_DIR":/workspace -w /workspace "$DOCKER_IMAGE" bash -c "$current_cmd"
        fi
    else
        cd "$TEMP_DIR" && eval "$current_cmd"
    fi
}

# Main tracing loop
while true; do
    echo "📌 Starting tracing for $SCRIPT_PYTHON..."

    # Copy the input script to the temp directory first if it's not already there
    if [ ! -f "$TEMP_DIR/$(basename "$SCRIPT_PYTHON")" ]; then
        cp "$SCRIPT_PYTHON" "$TEMP_DIR/"
    fi
    
    # Run Python trace in real-time using the copy in TEMP_DIR
    cd "$TEMP_DIR"
    python -m trace --trace --count -C "$TEMP_DIR" "$(basename "$SCRIPT_PYTHON")" 2>&1 | tee "$TRACE_OUTPUT"
    cd - > /dev/null # Return to previous directory

    # Extract function names
    extract_function_calls < "$TRACE_OUTPUT"
    
    # Show detected functions
    echo "Detected functions:"
    cat "$FUNCTIONS_FILE"

    # Convert to C
    convert_to_c

    # Run ESBMC for each detected function
    while read -r function_name; do
        if [[ -n "$function_name" ]]; then
            run_esbmc_for_function "$function_name"
        fi
    done < "$FUNCTIONS_FILE"

    # Ask if tracing should be restarted
    while true; do
        echo -e "\n🔄 Do you want to restart tracing? (y = Yes, n = No)"
        read -r REPLY
        case "$REPLY" in
            [Yy]) break ;;  # Restart loop
            [Nn]) 
                echo "✅ Tracing completed."
                rm -rf "$TEMP_DIR" "$TRACE_OUTPUT" "$FUNCTIONS_FILE" "$LLM_INPUT"
                exit 0 
                ;;
            *) echo "⚠️ Invalid input. Please enter 'y' for Yes or 'n' for No." ;;
        esac
    done
done