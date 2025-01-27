#!/bin/bash
# Default values
USE_DOCKER=false
DOCKER_IMAGE="esbmc"
CONTAINER_ID=""
TEMP_DIR=""

# Function to show usage
show_usage() {
  echo "Usage: ./verify.sh [--docker] [--image IMAGE_NAME | --container CONTAINER_ID] <filename>"
  echo "Options:"
  echo "  --docker              Run ESBMC in Docker container"
  echo "  --image IMAGE_NAME    Specify Docker image (default: esbmc)"
  echo "  --container ID        Specify existing container ID"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
   case $1 in
       --docker) USE_DOCKER=true; shift ;;
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
   echo "Running ESBMC..."
   if [ "$USE_DOCKER" = true ]; then
       if [ ! -z "$CONTAINER_ID" ]; then
           docker exec "$CONTAINER_ID" mkdir -p /workspace
           docker cp . "$CONTAINER_ID":/workspace/
           docker exec -w /workspace "$CONTAINER_ID" \
               esbmc --std c++17 --segfault-handler \
               -I/usr/include -I/usr/local/include -I. \
               "${FILENAME}.cpp" --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets
           docker exec "$CONTAINER_ID" rm -rf /workspace/*
       else
           docker run --rm \
               -v "$(pwd)":/workspace \
               -w /workspace \
               "$DOCKER_IMAGE" \
               esbmc --std c++17 --segfault-handler \
               -I/usr/include -I/usr/local/include -I. \
               "${FILENAME}.cpp" --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets
       fi
   else
       GCC_LIB_PATH=$(dirname $(gcc -print-libgcc-file-name))
       ESBMC_EXTRA=""
       [ -d "$GCC_LIB_PATH/include" ] && ESBMC_EXTRA=" -I$GCC_LIB_PATH/include"
       esbmc --std c++17 --segfault-handler \
           -I/usr/include -I/usr/local/include -I. $ESBMC_EXTRA \
           "${FILENAME}.cpp" --no-bounds-check --no-div-by-zero-check \
           --incremental-bmc --no-pointer-check --no-align-check --add-symex-value-sets --compact-trace
       ESBMC_EXIT=$?
   fi
else
   echo "Warning: ${FILENAME}.cpp not found, skipping ESBMC"
   ESBMC_EXIT=1
fi

cd "$OLD_PWD"
echo "Temporary files available in: $TEMP_DIR"
exit $ESBMC_EXIT
