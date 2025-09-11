#!/bin/bash

# ESBMC Docker Wrapper Script
# This script makes the containerized ESBMC appear as a local command

# Container and image names
CONTAINER_NAME="esbmc-container"
IMAGE_NAME="esbmc_esbmc"  # This will be the name from docker-compose

# Function to check if container is running
is_container_running() {
    docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

# Function to start container if not running
ensure_container_running() {
    if ! is_container_running; then
        echo "Starting ESBMC container..." >&2
        docker-compose up -d
        # Wait a moment for container to be ready
        sleep 2
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
