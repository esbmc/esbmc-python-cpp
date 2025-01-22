#!/bin/bash

# Default values
USE_DOCKER=false
DOCKER_IMAGE="esbmc"  # Default Docker image
CONTAINER_ID=""       # Default empty container ID

# Function to show usage
show_usage() {
   echo "Usage: ./verify.sh [--docker] [--image IMAGE_NAME | --container CONTAINER_ID] <filename>"
   echo "Options:"
   echo "  --docker              Run ESBMC in Docker container"
   echo "  --image IMAGE_NAME    Specify Docker image (default: esbmc)"
   echo "  --container ID        Specify existing container ID"
   echo "Examples:"
   echo "  ./verify.sh examples/example_1_esbmc.py"
   echo "  ./verify.sh --docker examples/example_1_esbmc.py"
   echo "  ./verify.sh --docker --image custom_esbmc examples/example_1_esbmc.py"
   echo "  ./verify.sh --docker --container abc123def456 examples/example_1_esbmc.py"
   exit 1
}

# Restore header files function
restore_headers() {
   if [ -f builtin.hpp.bak ]; then
       echo "Restoring header files..."
       for file in *.hpp.bak; do
           mv "$file" "${file%.bak}"
       done
   fi
}

# Cleanup function for final cleanup
cleanup() {
   if [ "$USE_DOCKER" = true ] && [ -d "./temp_verify" ]; then
       rm -rf ./temp_verify
   elif [ "$DIRNAME" != "." ] && [ -f "${FILENAME}.py" ]; then
       rm "${FILENAME}.py"
   fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Parse arguments
while [[ $# -gt 0 ]]; do
   case $1 in
       --docker)
           USE_DOCKER=true
           shift
           ;;
       --image)
           if [ -z "$2" ]; then
               echo "Error: --image requires a Docker image name"
               show_usage
           fi
           if [ ! -z "$CONTAINER_ID" ]; then
               echo "Error: Cannot use both --image and --container"
               show_usage
           fi
           DOCKER_IMAGE="$2"
           shift 2
           ;;
       --container)
           if [ -z "$2" ]; then
               echo "Error: --container requires a container ID"
               show_usage
           fi
           if [ ! -z "$DOCKER_IMAGE" ] && [ "$DOCKER_IMAGE" != "esbmc" ]; then
               echo "Error: Cannot use both --image and --container"
               show_usage
           fi
           CONTAINER_ID="$2"
           shift 2
           ;;
       -h|--help)
           show_usage
           ;;
       *)
           if [ -z "$FULLPATH" ]; then
               FULLPATH="$1"
           else
               show_usage
           fi
           shift
           ;;
   esac
done

# Check if a filename is provided
if [ -z "$FULLPATH" ]; then
   show_usage
fi

# Get the filename and directory
FILENAME=$(basename "$FULLPATH" .py)
DIRNAME=$(dirname "$FULLPATH")

# Check if source file exists
if [ ! -f "$FULLPATH" ]; then
   echo "Error: Source file $FULLPATH does not exist"
   exit 1
fi

# Create backup of header files if they exist
if [ -f builtin.hpp ]; then
   for file in *.hpp; do
       cp "$file" "${file}.bak"
       rm "$file"
   done
fi

# Copy file if not in current directory
if [ "$DIRNAME" != "." ]; then
   echo "Copying $FULLPATH to current directory..."
   cp "$FULLPATH" "${FILENAME}.py"
fi

# Activate virtual environment if it exists
if [ -d "venv" ]; then
   source venv/bin/activate
fi

# Run shedskin on the Python file
echo "Running shedskin on ${FILENAME}.py..."
shedskin "${FILENAME}.py"
SHEDSKIN_EXIT=$?

if [ $SHEDSKIN_EXIT -ne 0 ]; then
   echo "Warning: shedskin compilation had errors (exit code $SHEDSKIN_EXIT)"
   echo "Continuing with the rest of the process..."
fi

make "${FILENAME}"
./"${FILENAME}"
# Restore header files before running ESBMC
restore_headers
exit 0
# Run ESBMC if cpp file exists
if [ -f "${FILENAME}.cpp" ]; then
   echo "Running ESBMC..."
   if [ "$USE_DOCKER" = true ]; then
       if [ ! -z "$CONTAINER_ID" ]; then
           echo "Using existing container: $CONTAINER_ID"
           # Create directory in container
           docker exec "$CONTAINER_ID" mkdir -p /workspace
           # Copy files to container
           docker cp . "$CONTAINER_ID":/workspace/
           # Execute ESBMC in container
           docker exec -w /workspace "$CONTAINER_ID" \
               esbmc --std c++17 --segfault-handler \
               -I. -I/usr/include -I/usr/local/include \
               "${FILENAME}.cpp" --incremental-bmc
           # Clean up container workspace
           docker exec "$CONTAINER_ID" rm -rf /workspace/*
       else
           echo "Using Docker image: $DOCKER_IMAGE"
           docker run --rm \
               -v "$(pwd)":/workspace \
               -w /workspace \
               "$DOCKER_IMAGE" \
               esbmc --std c++17 --segfault-handler \
               -I. -I/usr/include -I/usr/local/include \
               "${FILENAME}.cpp" --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets
       fi
   else
       GCC_LIB_PATH=$(dirname $(gcc -print-libgcc-file-name))
       if [ -d "$GCC_LIB_PATH"/include ]; then
           ESBMC_EXTRA=" -I$GCC_LIB_PATH/include"
       else
           ESBMC_EXTRA=""
       fi

       echo "Extra GCC libs folder: $ESBMC_EXTRA"

       esbmc --std c++17 --segfault-handler \
           -I. -I/usr/include -I/usr/local/include $ESBMC_EXTRA \
           "${FILENAME}.cpp" --incremental-bmc
   fi
else
   echo "Warning: ${FILENAME}.cpp not found, skipping ESBMC"
fi
