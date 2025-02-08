#!/bin/bash
# Default values
USE_DOCKER=false
USE_LLM=false
DOCKER_IMAGE="esbmc"
CONTAINER_ID=""
TEMP_DIR=""

# Function to show usage
show_usage() {
  echo "Usage: ./verify.sh [--docker] [--llm] [--image IMAGE_NAME | --container CONTAINER_ID] <filename>"
  echo "Options:"
  echo "  --docker              Run ESBMC in Docker container"
  echo "  --llm                Use LLM to convert C++ to C before verification"
  echo "  --image IMAGE_NAME    Specify Docker image (default: esbmc)"
  echo "  --container ID        Specify existing container ID"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
   case $1 in
       --docker) USE_DOCKER=true; shift ;;
       --llm) USE_LLM=true; shift ;;
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

cd "$TEMP_DIR"

# Activate virtual environment from original directory if it exists
[ -d "$OLD_PWD/venv" ] && source "$OLD_PWD/venv/bin/activate"

# Run shedskin
echo "Running shedskin on ${FILENAME}.py..."
shedskin translate "${FILENAME}.py"
SHEDSKIN_EXIT=$?
[ $SHEDSKIN_EXIT -ne 0 ] && echo "Warning: shedskin compilation had errors (exit code $SHEDSKIN_EXIT)"

# Run ESBMC if cpp file exists
if [ -f "${FILENAME}.cpp" ]; then
   if [ "$USE_LLM" = true ]; then
       echo "Converting C++ to C using aider..."
       # Create a temporary message file for aider
       INSTRUCTION_FILE=$(mktemp)
       echo "Convert this C++ code to C code, maintaining the same functionality. Remove any C++ specific features and replace them with C equivalents. Keep the verification properties intact.
       
        General Guidelines:
        The resulting C code has to be verifiable by ESBMC.

        Avoid dynamic memory allocation when possible
        Use fixed-size arrays
        Model known results directly instead of computing them
        Break complex operations into simple, verifiable steps
        Use clear, simple assertions
        Avoid external library functions
        When using loops, keep them simple and bounded.
        Always #include <stdio.h> and #include <stdlib.h> as a header.
        Do not oversimplify functions so that the logic is lost.
        For ESBMC nondet_int() use this syntax: nondet_uint() without the keyword ESBMC in the function. 
        However do not define nondet_uint(), ESBMC just understands what that keyword means. 
        Do not declare a function stub like  int nondet_uint(); Just use the function in the code.
        When the code says assert, translate it to just assert(), do not add in extra ESBMC assume conditions, unless the code indicates to add those in.
       " > "$INSTRUCTION_FILE"
       
       # Initialize variables for the loop
       MAX_ATTEMPTS=5
       attempt=1
       clang_success=false

       while [ $attempt -le $MAX_ATTEMPTS ] && [ "$clang_success" = false ]; do
            echo "Attempt $attempt of $MAX_ATTEMPTS to generate valid C code..."
            
            # First attempt without parse check
            if [ $attempt -eq 1 ]; then
                aider --no-git --no-show-model-warnings --model openrouter/deepseek/deepseek-chat --yes --message-file "$INSTRUCTION_FILE" --read "${FILENAME}.cpp" "${FILENAME}.c"
            else
                # Subsequent attempts with parse check during generation
                aider --no-git --no-show-model-warnings --model openrouter/deepseek/deepseek-chat --test --auto-test --test-cmd "esbmc --parse-tree-only '${FILENAME}.c'" --yes --message-file "$INSTRUCTION_FILE" --read "${FILENAME}.cpp" "${FILENAME}.c"
            fi
            
            # Test if ESBMC parse was successful
            if esbmc --parse-tree-only "${FILENAME}.c" 2>/dev/null; then
                echo "Successfully generated valid C code on attempt $attempt"
                clang_success=true
            else
                echo "ESBMC parse tree check failed on attempt $attempt"
                if [ $attempt -lt $MAX_ATTEMPTS ]; then
                    echo "Retrying..."
                    sleep 1  # Add a small delay between attempts
                fi
            fi
            
            ((attempt++))
        done

       if [ "$clang_success" = false ]; then
           echo "Failed to generate valid C code after $MAX_ATTEMPTS attempts"
           exit 1
       fi

       # Clean up the temporary instruction file
       rm "$INSTRUCTION_FILE"
       
       TARGET_FILE="${FILENAME}.c"
   else
       TARGET_FILE="${FILENAME}.cpp"
   fi
   
   echo "Running ESBMC..."
   if [ "$USE_DOCKER" = true ]; then
       if [ ! -z "$CONTAINER_ID" ]; then
            docker exec "$CONTAINER_ID" mkdir -p /workspace
            docker cp . "$CONTAINER_ID":/workspace/
            docker exec -w /workspace "$CONTAINER_ID" \
               # Set C++ standard flag only if not using LLM (C code)
               CPP_STD_FLAG=""
               if [ "$USE_LLM" = false ]; then
                   CPP_STD_FLAG="--std c++17"
               fi
               
               esbmc $CPP_STD_FLAG --segfault-handler \
               -I/usr/include -I/usr/local/include -I. \
               "$TARGET_FILE" --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets --compact-trace
            ESBMC_EXIT=$?
            docker exec "$CONTAINER_ID" rm -rf /workspace/*
       else
            docker run --rm \
               -v "$(pwd)":/workspace \
               -w /workspace \
               "$DOCKER_IMAGE" \
               # Set C++ standard flag only if not using LLM (C code)
               CPP_STD_FLAG=""
               if [ "$USE_LLM" = false ]; then
                   CPP_STD_FLAG="--std c++17"
               fi
               
               esbmc $CPP_STD_FLAG --segfault-handler \
               -I/usr/include -I/usr/local/include -I. \
               "$TARGET_FILE" --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets --compact-trace
            ESBMC_EXIT=$?
       fi
   else
       GCC_LIB_PATH=$(dirname $(gcc -print-libgcc-file-name))
       ESBMC_EXTRA=""
       [ -d "$GCC_LIB_PATH/include" ] && ESBMC_EXTRA=" -I$GCC_LIB_PATH/include"
       # Set C++ standard flag only if not using LLM (C code)
       CPP_STD_FLAG=""
       if [ "$USE_LLM" = false ]; then
           CPP_STD_FLAG="--std c++17 -I."
       fi
       echo "Temporary files available in: $TEMP_DIR"
       
       esbmc $CPP_STD_FLAG  \
           -I/usr/include -I/usr/local/include --segfault-handler $ESBMC_EXTRA \
           "$TARGET_FILE" --no-bounds-check --no-div-by-zero-check \
           --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets
       ESBMC_EXIT=$?
   fi
else
   echo "Warning: ${FILENAME}.cpp not found, skipping ESBMC"
   ESBMC_EXIT=1
fi

cd "$OLD_PWD"
echo "Temporary files available in: $TEMP_DIR"
exit $ESBMC_EXIT