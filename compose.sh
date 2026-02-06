#!/bin/bash
# Helper script to run docker-compose or podman-compose with proper GPU support

set -e

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

echo "Using container runtime: $RUNTIME"

# Check for GPU flag
USE_GPU=false
if [[ " $@ " =~ " --gpu " ]]; then
    USE_GPU=true
    # Remove --gpu from arguments
    set -- "${@//--gpu/}"
fi

# Build compose command
if [ "$USE_GPU" = true ]; then
    echo "Enabling GPU support..."
    COMPOSE_FILES="-f docker-compose.yml -f $GPU_FILE"
else
    COMPOSE_FILES="-f docker-compose.yml"
fi

# Special handling for Podman GPU without CDI (fallback to device mounting)
if [ "$RUNTIME" = "podman" ] && [ "$USE_GPU" = true ]; then
    # Try to detect NVIDIA devices
    if [ -e /dev/nvidia0 ]; then
        echo "Mounting NVIDIA devices directly for Podman..."
        # This requires a workaround since podman-compose doesn't fully support device mapping like docker-compose
        # We'll create a temporary override file
        PODMAN_OVERRIDE="docker-compose.gpu.podman.override.yml"
        cat > "$PODMAN_OVERRIDE" <<'EOF'
services:
  4dgs-slam-dev:
    devices:
      - /dev/nvidia0:/dev/nvidia0
      - /dev/nvidiactl:/dev/nvidiactl
      - /dev/nvidia-uvm:/dev/nvidia-uvm
EOF
        COMPOSE_FILES="$COMPOSE_FILES -f $PODMAN_OVERRIDE"
        trap "rm -f $PODMAN_OVERRIDE" EXIT
    fi
fi

# Execute compose command
echo "Running: $COMPOSE_CMD $COMPOSE_FILES $@"
$COMPOSE_CMD $COMPOSE_FILES "$@"
