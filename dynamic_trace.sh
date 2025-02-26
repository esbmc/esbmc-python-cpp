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
PROGRAM_OUTPUT="$TEMP_DIR/program.out"
LLM_INPUT="$TEMP_DIR/llm_input.txt"
touch "$TRACE_OUTPUT" "$FUNCTIONS_FILE" "$PROGRAM_OUTPUT" "$LLM_INPUT"
C_FILE_NAME="$(basename "${SCRIPT_PYTHON%.py}.c")"
C_OUTPUT="$TEMP_DIR/$C_FILE_NAME"

echo "📂 Temporary workspace: $TEMP_DIR"

# Copy the Python script to the temp directory
cp "$SCRIPT_PYTHON" "$TEMP_DIR/$(basename "$SCRIPT_PYTHON")"
echo "📄 Copied Python script to temporary directory"

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
    # Extract functions from the trace file, filter out system functions
    cat "$TRACE_OUTPUT" | grep -E "call function|funcname:" | 
    sed -E 's/.*call function: ([a-zA-Z0-9_]+).*|.*funcname: ([a-zA-Z0-9_]+).*/\1\2/' | 
    grep -v "^$" | grep -v "^<" | grep -v "^_" | 
    sort -u > "$FUNCTIONS_FILE"
}

# Create the monkey-patching tracer script
create_interceptor_script() {
    local py_script=$(basename "$SCRIPT_PYTHON")
    local wrapper_script="$TEMP_DIR/wrapper.py"
    
    cat > "$wrapper_script" <<EOF
#!/usr/bin/env python3
import sys
import os
import importlib.util
import builtins
import types
import signal
import traceback
import time
import inspect
import ast

# Store original built-in functions
original_print = builtins.print

# Global pause flag for signal handler
PAUSED = False

# Signal handler for SIGUSR1 (pause/resume)
def handle_pause(signum, frame):
    global PAUSED
    PAUSED = not PAUSED
    original_print(f"\n{'[PAUSED]' if PAUSED else '[RESUMED]'} tracing at frame: {frame.f_code.co_name}")
    if PAUSED:
        # Print stack trace when paused
        original_print("\n=== Current Stack Trace ===")
        traceback.print_stack(frame)
        original_print("===========================\n")

# Signal handler for SIGUSR2 (exit)
def handle_exit(signum, frame):
    original_print("\n[EXITING] Trace collection terminated by signal")
    sys.exit(0)

# Register signal handlers
signal.signal(signal.SIGUSR1, handle_pause)
signal.signal(signal.SIGUSR2, handle_exit)

# Print PID for external control
original_print(f"Trace process PID: {os.getpid()}")
original_print("Send SIGUSR1 (kill -SIGUSR1 PID) to pause/resume")
original_print("Send SIGUSR2 (kill -SIGUSR2 PID) to exit")

# Track function calls
CALL_COUNT = 0
MAX_CALLS = 500
TRACKED_FUNCTIONS = set()

# Override print to allow pausing
def intercepted_print(*args, **kwargs):
    global PAUSED
    while PAUSED:
        # Just wait while paused
        time.sleep(0.1)
    
    return original_print(*args, **kwargs)

# Replace built-in print
builtins.print = intercepted_print

# Extract function names statically from the source code
def extract_functions_from_source(filename):
    with open(filename, 'r') as file:
        source = file.read()
    
    functions = {}
    try:
        tree = ast.parse(source)
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                functions[node.name] = {
                    'lineno': node.lineno,
                    'args': [arg.arg for arg in node.args.args]
                }
    except Exception as e:
        original_print(f"Error parsing source: {e}")
    
    return functions

# Original script path
original_script_path = os.path.join(os.getcwd(), "$py_script")
static_functions = extract_functions_from_source(original_script_path)

# Log the statically discovered functions
original_print(f"Static analysis found {len(static_functions)} functions:")
for func_name, info in static_functions.items():
    if not func_name.startswith('_'):
        original_print(f"static function: {func_name} at line {info['lineno']}")

# Function to intercept and track function calls
def function_interceptor(func):
    def wrapper(*args, **kwargs):
        global CALL_COUNT, PAUSED
        
        # Wait if paused
        while PAUSED:
            time.sleep(0.1)
            
        # Only log real functions that aren't builtins
        func_name = func.__name__
        
        # Skip logging builtins, private functions, and already logged functions
        if (not func_name.startswith('_') and 
            func_name not in TRACKED_FUNCTIONS and
            CALL_COUNT < MAX_CALLS):
            
            # Log the function call
            caller_frame = inspect.currentframe().f_back
            caller_info = ""
            if caller_frame:
                caller_info = f" called from {caller_frame.f_code.co_name}:{caller_frame.f_lineno}"
            
            original_print(f"call function: {func_name}{caller_info}")
            TRACKED_FUNCTIONS.add(func_name)
            CALL_COUNT += 1
            
            # Print a message when we hit the limit
            if CALL_COUNT == MAX_CALLS:
                original_print("Function trace limit reached (500 unique functions)")
        
        # Call the original function
        return func(*args, **kwargs)
    
    return wrapper

# Import the script as a module
try:
    spec = importlib.util.spec_from_file_location("traced_module", original_script_path)
    module = importlib.util.module_from_spec(spec)
    
    # Apply function interceptors before executing
    for func_name in static_functions:
        if not func_name.startswith('_'):
            original_print(f"Preparing to trace function: {func_name}")
    
    # Execute the module
    try:
        # Set up command line args
        sys.argv = [original_script_path]
        
        # Load the module
        spec.loader.exec_module(module)
        
        # For scripts that complete quickly, wait a moment
        original_print("Script execution completed")
        
    except KeyboardInterrupt:
        original_print("\nScript execution interrupted by user")
    except Exception as e:
        original_print(f"Error during execution: {e}")
        traceback.print_exc()
        
except Exception as e:
    original_print(f"Error loading script: {e}")
    traceback.print_exc()
EOF

    chmod +x "$wrapper_script"
    echo "Created interception wrapper at $wrapper_script"
}

# Alternative approach using sys.settrace
create_trace_hook_script() {
    local py_script=$(basename "$SCRIPT_PYTHON")
    local hook_script="$TEMP_DIR/trace_hook.py"
    
    cat > "$hook_script" <<EOF
#!/usr/bin/env python3
import sys
import os
import signal
import traceback
import time
import inspect

# Original script path
TARGET_SCRIPT = "$py_script"

# Global state
PAUSED = False
CALL_COUNT = 0
MAX_CALLS = 500
TRACED_FUNCTIONS = set()

# Signal handler for pause/resume
def handle_pause(signum, frame):
    global PAUSED
    PAUSED = not PAUSED
    print(f"\n{'[PAUSED]' if PAUSED else '[RESUMED]'} at {frame.f_code.co_name}")
    if PAUSED:
        print("\n=== Current Stack ===")
        traceback.print_stack(frame)
        print("=====================")

# Signal handler for exit
def handle_exit(signum, frame):
    print("\n[EXITING] Trace terminated by signal")
    sys.exit(0)

# Register signal handlers
signal.signal(signal.SIGUSR1, handle_pause)
signal.signal(signal.SIGUSR2, handle_exit)

# Print PID for external control
print(f"Trace process PID: {os.getpid()}")
print("Send SIGUSR1 (kill -SIGUSR1 PID) to pause/resume")
print("Send SIGUSR2 (kill -SIGUSR2 PID) to exit")

# Trace function hook
def trace_calls(frame, event, arg):
    global PAUSED, CALL_COUNT, TRACED_FUNCTIONS
    
    # Wait if paused
    while PAUSED:
        time.sleep(0.1)
    
    if event == 'call':
        # Get function info
        func_name = frame.f_code.co_name
        filename = frame.f_code.co_filename
        
        # Only trace user functions from our script
        if TARGET_SCRIPT in filename and not func_name.startswith('_') and func_name not in TRACED_FUNCTIONS:
            if CALL_COUNT < MAX_CALLS:
                print(f"funcname: {func_name}")
                TRACED_FUNCTIONS.add(func_name)
                CALL_COUNT += 1
                
                if CALL_COUNT == MAX_CALLS:
                    print("Trace limit reached (500 functions)")
    
    return trace_calls

# Setup trace hook
sys.settrace(trace_calls)

# Execute the target script
try:
    with open(TARGET_SCRIPT) as f:
        script_content = f.read()
    
    # Set up globals for execution
    script_globals = {
        '__file__': TARGET_SCRIPT,
        '__name__': '__main__'
    }
    
    # Execute the script
    print(f"Starting execution of {TARGET_SCRIPT}")
    exec(script_content, script_globals)
    print("Script execution completed")
    
except KeyboardInterrupt:
    print("\nScript execution interrupted")
except Exception as e:
    print(f"Error during script execution: {e}")
    traceback.print_exc()
EOF

    chmod +x "$hook_script"
    echo "Created trace hook script at $hook_script"
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
#include <string.h>
#include <math.h>

// Converted from $(basename "$py_file")

$(cat "$FUNCTIONS_FILE" | while read func; do
    if [ "$func" != "<module>" ] && [ -n "$func" ]; then
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
    if [ "$func" != "<module>" ] && [ -n "$func" ]; then
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
    
    # Create a temporary file for the prompt in the TEMP_DIR
    local TEMP_PROMPT="$TEMP_DIR/prompt.txt"
    touch "$TEMP_PROMPT"
    
    # Create a simple starting C file to work with
    create_c_file_manually "$input_file" "$output_file"
    
    # Build a more compact message for the LLM
    {
        echo "Convert the following Python code directly to C code."
        echo "IMPORTANT: I've already created an initial C file for you to modify. DO NOT create a new file."
        echo "EDIT THE EXISTING FILE DIRECTLY."
        echo ""
        echo "The converted code should:"
        echo "1. Maintain all essential logic and algorithms"
        echo "2. Handle memory management appropriately"
        echo "3. Use equivalent C data structures and types"
        echo "4. Include necessary headers and dependencies"
        echo "5. Only output proper C code that can be parsed by a C compiler"
        cat "$SOURCE_INSTRUCTION_FILE"
        
        # Add list of functions we detected to focus on
        echo -e "\nImplement these functions identified during execution:"
        cat "$FUNCTIONS_FILE"
        
        # Add Python code
        echo -e "\n=== PYTHON CODE ==="
        cat "$input_file"
        
        # Add program output if available and not too large
        if [ -s "$PROGRAM_OUTPUT" ]; then
            local output_size=$(wc -l < "$PROGRAM_OUTPUT")
            if [ $output_size -lt 50 ]; then
                echo -e "\n=== PROGRAM OUTPUT (for reference) ==="
                head -n 50 "$PROGRAM_OUTPUT"
            else
                echo -e "\n=== PROGRAM OUTPUT SAMPLE (for reference) ==="
                head -n 25 "$PROGRAM_OUTPUT"
                echo "... (output truncated) ..."
            fi
        fi
        
        # Add initial C code
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
        # else
        #     # Start a new container
        #     CONTAINER_ID=$(docker run -d --rm -v "$TEMP_DIR":/workspace -w /workspace "$DOCKER_IMAGE" sleep 3600)
        #     debug_log "Started new container: $CONTAINER_ID"
        #     echo "🐳 Docker container started: $CONTAINER_ID (mounted $TEMP_DIR as /workspace)"
        fi
    fi

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo "Attempt $attempt of $max_attempts to generate valid C code..."

        if command -v timeout >/dev/null 2>&1; then
            TIMEOUT_CMD="timeout"
        elif command -v gtimeout >/dev/null 2>&1; then
            TIMEOUT_CMD="gtimeout"
        else
            TIMEOUT_CMD=""
        fi
        # Run aider to modify the C file (with a timeout)
        $TIMEOUT_CMD 180 aider --no-git --no-show-model-warnings --model "$LLM_MODEL" --yes \
            --message-file "$TEMP_PROMPT" --file "$output_file" || true
        
        # Show the output file contents for debugging
        debug_log "C code after aider (first 20 lines):"
        head -n 20 "$output_file"
        
        # Check if the generated C code is valid
        if [ "$USE_DOCKER" = true ]; then

            filename=$(basename "$output_file")
            output_dir=$(dirname "$output_file")

            # Montez le répertoire spécifique qui contient le fichier
            if [ -n "$CONTAINER_ID" ]; then
                # Pour un conteneur existant, copiez le fichier à l'intérieur
                docker cp "$output_file" "$CONTAINER_ID:/workspace/$filename"
                docker exec $CONTAINER_ID esbmc --parse-tree-only "/workspace/$filename"
                result=$?
            else
                echo "❌ Run in docker  $TEMP_DIR "
                echo "❌ Run in docker  $TEMP_DIR "
                # Pour un nouveau conteneur, montez le répertoire contenant le fichier
                docker run --rm -v $(pwd):/workspace -w /workspace "$DOCKER_IMAGE" esbmc --parse-tree-only "$filename"
                result=$?
            fi


            if [ $result -eq 0 ]; then
                echo "✅ Successfully generated valid C code on attempt $attempt"
                success=true
            else
                echo "❌ ESBMC parse tree check failed on attempt $attempt "
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
            esbmc --parse-tree-only "$output_file"
            result=$?
            if [ $result -eq 0 ]; then
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
    if [ "$USE_DOCKER" = true ] && [ -z "$1" ]; then
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
    
    local current_cmd="esbmc --function $function_name \"$C_OUTPUT\""

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

# Function to run the interactive tracing session using sys.settrace
run_tracing_session() {
    local py_script="$(basename "$SCRIPT_PYTHON")"
    
    echo "📌 Starting tracing for $SCRIPT_PYTHON..."
    
    # Create trace hook script for better function tracking
    create_trace_hook_script
    
    # Run the trace script
    cd "$TEMP_DIR"
    python3 "trace_hook.py" 2>&1 | tee "$TRACE_OUTPUT" &
    TRACE_PID=$!
    
    echo "📊 Tracing started with PID: $TRACE_PID"
    echo "- Press Enter to pause and analyze current trace"
    
    # Loop to allow interactive pausing and analysis
    while true; do
        read -t 1 || true  # Non-blocking read with 1-second timeout
        
        if [ $? -eq 0 ]; then
            # User pressed Enter, pause tracing and analyze
            kill -SIGUSR1 $TRACE_PID 2>/dev/null || true  # Send pause signal
            echo "⏸️ Pausing trace collection..."
            sleep 1  # Wait for pause to take effect
            
            # Extract functions from current trace
            extract_function_calls
            
            # Extract program output (non-trace lines)
            grep -v "funcname:" "$TRACE_OUTPUT" | grep -v "call function:" > "$PROGRAM_OUTPUT"
            
            # Check if we have any functions
            if [ ! -s "$FUNCTIONS_FILE" ]; then
                echo "⚠️ No functions detected in trace so far."
                echo "Please let the program run longer or check if tracing is working correctly."
                
                # Show last 20 lines of trace output for debugging
                echo "Last 20 lines of trace output:"
                tail -n 20 "$TRACE_OUTPUT"
            else
                # Show detected functions
                echo "Detected functions so far:"
                cat "$FUNCTIONS_FILE"
            fi
            
            # Show last 10 lines of program output
            echo -e "\nLast 10 lines of program output:"
            grep -v "funcname:" "$TRACE_OUTPUT" | grep -v "call function:" | tail -n 10
            
            # Ask user what to do
            echo -e "\nOptions:"
            echo "  1) Convert to C and verify with ESBMC"
            echo "  2) Resume tracing"
            echo "  3) Exit tracing and cleanup"
            read -p "Enter option (1-3): " OPTION
            
            case $OPTION in
                1)
                    # Convert and verify
                    convert_to_c
                    while read -r function_name; do
                        if [[ -n "$function_name" ]]; then
                            run_esbmc_for_function "$function_name"
                        fi
                    done < "$FUNCTIONS_FILE"
                    
                    # Ask whether to resume or exit
                    read -p "Resume tracing? (y/n): " RESUME
                    if [[ "$RESUME" =~ ^[Yy]$ ]]; then
                        kill -SIGUSR1 $TRACE_PID 2>/dev/null || true  # Resume
                        echo "▶️ Resuming trace collection..."
                    else
                        kill -SIGUSR2 $TRACE_PID 2>/dev/null || true  # Exit
                        wait $TRACE_PID 2>/dev/null || true
                        echo "✅ Tracing completed."
                        break
                    fi
                    ;;
                2)
                    # Resume tracing
                    kill -SIGUSR1 $TRACE_PID 2>/dev/null || true  # Resume
                    echo "▶️ Resuming trace collection..."
                    ;;
                3)
                    # Exit tracing
                    kill -SIGUSR2 $TRACE_PID 2>/dev/null || true  # Exit
                    wait $TRACE_PID 2>/dev/null || true
                    echo "✅ Tracing completed."
                    break
                    ;;
                *)
                    echo "Invalid option, resuming trace collection..."
                    kill -SIGUSR1 $TRACE_PID 2>/dev/null || true  # Resume
                    ;;
            esac
        fi
        
        # Check if trace process is still running
        if ! kill -0 $TRACE_PID 2>/dev/null; then
            echo "Trace process has ended."
            break
        fi
    done
    
    cd - > /dev/null # Return to previous directory
}

# Main tracing loop
while true; do
    run_tracing_session
    
    # Ask if tracing should be restarted
    while true; do
        echo -e "\n🔄 Do you want to restart tracing? (y = Yes, n = No)"
        read -r REPLY
        case "$REPLY" in
            [Yy]) break ;;  # Restart loop
            [Nn]) 
                echo "✅ Tracing completed."
                rm -rf "$TEMP_DIR" "$TRACE_OUTPUT" "$FUNCTIONS_FILE" "$PROGRAM_OUTPUT" "$LLM_INPUT"
                exit 0 
                ;;
            *) echo "⚠️ Invalid input. Please enter 'y' for Yes or 'n' for No." ;;
        esac
    done
done