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

    # Get the current working directory relative to where docker-compose.yml is
    # This assumes the script is run from the same directory as docker-compose.yml
    CURRENT_DIR="$(pwd)"

    # Run esbmc in the container with current directory mounted
    docker exec -w "/workspace" "${CONTAINER_NAME}" esbmc "$@"
}

# Main execution
run_esbmc "$@"
