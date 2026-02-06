#!/usr/bin/env bash
# Helper script to run docker-compose or podman-compose with proper GPU support
# Supports both Docker (with nvidia-docker/nvidia-runtime) and Podman (with device mounting)

set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect container runtime
if command -v podman-compose &> /dev/null; then
    RUNTIME="podman"
    COMPOSE_CMD="podman-compose"
    GPU_FILE="docker-compose.gpu.podman.yml"
elif command -v docker-compose &> /dev/null; then
    RUNTIME="docker"
    COMPOSE_CMD="docker-compose"
    GPU_FILE="docker-compose.gpu.docker.yml"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
    COMPOSE_CMD="docker compose"
    GPU_FILE="docker-compose.gpu.docker.yml"
else
    echo "Error: Neither docker-compose, docker, nor podman-compose found in PATH"
    exit 1
fi

echo -e "${GREEN}Using container runtime: $RUNTIME${NC}"

# Check for GPU flag
USE_GPU=false
VERBOSE=false

# Parse arguments
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--gpu" ]; then
        USE_GPU=true
    elif [ "$arg" = "--verbose" ]; then
        VERBOSE=true
    else
        ARGS+=("$arg")
    fi
done

# Build compose command
if [ "$USE_GPU" = true ]; then
    echo -e "${YELLOW}Enabling GPU support...${NC}"
    
    # Check if GPU devices are available
    if [ ! -e /dev/nvidia0 ]; then
        echo "Warning: No NVIDIA GPU devices found (/dev/nvidia0)"
    fi
    
    COMPOSE_FILES="-f docker-compose.yml -f $GPU_FILE"
else
    COMPOSE_FILES="-f docker-compose.yml"
fi

# Execute compose command
if [ "$VERBOSE" = true ]; then
    echo "Command: $COMPOSE_CMD $COMPOSE_FILES ${ARGS[@]}"
fi

$COMPOSE_CMD $COMPOSE_FILES "${ARGS[@]}"
