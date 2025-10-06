#!/bin/bash
# ESBMC Docker Wrapper Script with Colima Support
# This script makes the containerized ESBMC appear as a local command
# and handles starting Colima Docker service if needed

# Container and image names
CONTAINER_NAME="esbmc-container"
IMAGE_NAME="esbmc_esbmc"  # This will be the name from docker-compose

# Function to check if Docker daemon is running
is_docker_running() {
    docker info >/dev/null 2>&1
}

# Function to check if Colima is running
is_colima_running() {
    colima status >/dev/null 2>&1 && [ "$(colima status | grep -o 'Running')" = "Running" ]
}

# Function to start Colima if not running
ensure_colima_running() {
    if ! is_docker_running; then
        if command -v colima >/dev/null 2>&1; then
            if ! is_colima_running; then
                echo "Starting Colima Docker service..." >&2
                colima start
                # Wait for Docker daemon to be ready
                echo "Waiting for Docker daemon to be ready..." >&2
                local timeout=30
                local count=0
                while ! is_docker_running && [ $count -lt $timeout ]; do
                    sleep 1
                    count=$((count + 1))
                done

                if ! is_docker_running; then
                    echo "Error: Docker daemon failed to start within ${timeout} seconds" >&2
                    exit 1
                fi
                echo "Colima started successfully" >&2
            fi
        else
            echo "Error: Docker daemon is not running and Colima is not installed" >&2
            echo "Please start your Docker service or install Colima" >&2
            exit 1
        fi
    fi
}

# Function to check if container is running
is_container_running() {
    docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

# Function to check if container exists (but may be stopped)
container_exists() {
    docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

# Function to start container if not running
ensure_container_running() {
    ensure_colima_running

    if ! is_container_running; then
        if container_exists; then
            echo "Starting existing ESBMC container..." >&2
            docker start "${CONTAINER_NAME}"
        else
            echo "Creating and starting ESBMC container..." >&2
            docker-compose up -d
        fi

        # Wait a moment for container to be ready
        echo "Waiting for container to be ready..." >&2
        sleep 3

        # Verify container is running
        if ! is_container_running; then
            echo "Error: Failed to start container" >&2
            exit 1
        fi
    fi
}

# Function to run esbmc in container
run_esbmc() {
    ensure_container_running

    # Get the current working directory
    CURRENT_DIR="$(pwd)"
    
    # Extract the target C file from arguments
    TARGET_FILE=$(echo "$@" | grep -o '\b[^[:space:]]*\.c\b' | head -1)
    if [ -z "$TARGET_FILE" ]; then
        # If no .c file found, just run normally
        docker exec -w "/workspace" "${CONTAINER_NAME}" esbmc "$@"
        return $?
    fi
    
    echo "=== ESBMC-MAC.SH DEBUG ===" >&2
    echo "Current directory: $CURRENT_DIR" >&2
    echo "Target file: $TARGET_FILE" >&2
    echo "Arguments: $*" >&2
    
    # Check if we're in a temp directory
    if [[ "$CURRENT_DIR" == */tmp.* ]]; then
        echo "Detected temp directory, copying files to container..." >&2
        
        # Create a unique container workspace using timestamp
        TIMESTAMP=$(date +%s)
        CONTAINER_WORKSPACE="/tmp/esbmc_work_${TIMESTAMP}"
        
        echo "Creating container workspace: $CONTAINER_WORKSPACE" >&2
        docker exec "${CONTAINER_NAME}" mkdir -p "$CONTAINER_WORKSPACE"
        docker exec "${CONTAINER_NAME}" chmod 777 "$CONTAINER_WORKSPACE"
        
        # Copy the target file directly to the unique workspace
        if [ -f "$CURRENT_DIR/$TARGET_FILE" ]; then
            echo "Copying $TARGET_FILE to container..." >&2
            echo "Source: $CURRENT_DIR/$TARGET_FILE" >&2
            echo "Destination: ${CONTAINER_NAME}:${CONTAINER_WORKSPACE}/" >&2
            echo "Command: docker cp \"$CURRENT_DIR/$TARGET_FILE\" \"${CONTAINER_NAME}:${CONTAINER_WORKSPACE}/\"" >&2
            
            docker cp "$CURRENT_DIR/$TARGET_FILE" "${CONTAINER_NAME}:${CONTAINER_WORKSPACE}/"
            cp_exit_code=$?
            echo "docker cp exit code for target file: $cp_exit_code" >&2
            
            # Verify the file was copied
            echo "Checking if file exists in container after copy:" >&2
            if docker exec "${CONTAINER_NAME}" test -f "${CONTAINER_WORKSPACE}/$TARGET_FILE"; then
                echo "✓ Target file successfully copied to container" >&2
            else
                echo "✗ Target file FAILED to copy to container" >&2
                echo "Files in container workspace:" >&2
                docker exec "${CONTAINER_NAME}" ls -la "$CONTAINER_WORKSPACE" >&2
                echo "Files in /workspace:" >&2
                docker exec "${CONTAINER_NAME}" ls -la /workspace >&2
                return 1
            fi
            
            # Headers are not needed - just copy the target C file
            echo "Headers copying skipped - only target file needed" >&2
            
            # Show final contents of the workspace
            echo "Final contents of container workspace:" >&2
            docker exec "${CONTAINER_NAME}" ls -la "$CONTAINER_WORKSPACE" >&2
            
            # Run esbmc from the unique workspace
            echo "Running esbmc from $CONTAINER_WORKSPACE..." >&2
            docker exec -w "$CONTAINER_WORKSPACE" "${CONTAINER_NAME}" esbmc "$@"
            
            # Clean up the workspace after execution
            echo "Cleaning up container workspace..." >&2
            docker exec "${CONTAINER_NAME}" rm -rf "$CONTAINER_WORKSPACE"
        else
            echo "ERROR: Target file not found: $CURRENT_DIR/$TARGET_FILE" >&2
            echo "Contents of current directory:" >&2
            ls -la "$CURRENT_DIR" >&2
            return 1
        fi
    else
        # Run esbmc in the container with current directory mounted
        echo "Running from regular workspace..." >&2
        docker exec -w "/workspace" "${CONTAINER_NAME}" esbmc "$@"
    fi
}

# Main execution
run_esbmc "$@"
