# Docker/Podman Compose GPU Setup Guide

This guide explains how to use the compose files with both Docker and Podman, with NVIDIA GPU support.

## Files

- `docker-compose.yml` - Base compose file (CPU-only)
- `docker-compose.gpu.docker.yml` - GPU support for Docker (device passthrough)
- `docker-compose.gpu.podman.yml` - GPU support for Podman (environment variables)
- `compose.sh` - Helper script to automatically detect runtime and manage GPU support

## Quick Start

### Using the Helper Script

The easiest way to run containers with automatic GPU detection:

```bash
# Without GPU
./compose.sh up -d

# With GPU
./compose.sh up -d --gpu

# Interactive bash session with GPU
./compose.sh run 4dgs-slam-dev --gpu bash
```

### Using Docker Compose

**Without GPU:**
```bash
docker-compose -f docker-compose.yml up -d
```

**With GPU:**
```bash
docker-compose -f docker-compose.yml -f docker-compose.gpu.docker.yml up -d
```

### Using Podman Compose

**Without GPU:**
```bash
podman-compose -f docker-compose.yml up -d
```

**With GPU (automatic device mounting):**
```bash
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml up -d
```

## GPU Support Details

### Docker
Docker uses direct device passthrough (`/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-uvm`) to give containers access to NVIDIA GPUs. The `docker-compose.gpu.docker.yml` override file handles this automatically.

**Prerequisites:**
- NVIDIA GPU
- NVIDIA drivers installed
- Docker runtime with GPU support enabled (usually available by default on systems with NVIDIA drivers)

### Podman
Podman supports GPU access through:

1. **CDI (Container Device Interface)** - Modern approach, requires Podman 4.0+
2. **Device mounting** - Fallback for older Podman versions
3. **Environment variables** - For runtime detection

The `docker-compose.gpu.podman.yml` file sets appropriate environment variables. For device access, the helper script creates a temporary override file.

**Prerequisites:**
- NVIDIA GPU
- NVIDIA drivers installed
- Podman 3.0+ (4.0+ recommended for CDI)
- `podman-compose` package

### Environment Variables

Both setups set these environment variables for CUDA support:

- `NVIDIA_VISIBLE_DEVICES=all` - Makes all GPUs visible
- `NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics` - Enables compute, utilities, and graphics

## Troubleshooting

### GPU Not Detected in Container

**Docker:**
```bash
# Check if nvidia-docker is available
which nvidia-docker

# Verify GPU visibility from host
nvidia-smi

# Verify GPU visibility inside container
docker-compose -f docker-compose.yml -f docker-compose.gpu.docker.yml exec 4dgs-slam-dev nvidia-smi
```

**Podman:**
```bash
# Check NVIDIA devices on host
ls -la /dev/nvidia*

# Verify inside container
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml exec 4dgs-slam-dev nvidia-smi
```

### Podman Device Permission Issues

If you get permission errors accessing NVIDIA devices:

```bash
# Run with elevated privileges (use with caution)
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml up

# Or use rootless with proper device setup
# See Podman documentation for rootless GPU setup
```

### CUDA/cuDNN Not Available

The Dockerfile is built with CUDA support. Verify:

```bash
# Inside container, check CUDA availability
python -c "import torch; print(torch.cuda.is_available())"
```

## Configuration Variables

You can customize the setup with environment variables:

```bash
# Custom CUDA base image version
CUDA_BASE=12.1.1 docker-compose up

# Custom PyTorch versions
TORCH_VERSION=2.0.0 TORCH_CUDA=cu118 docker-compose up

# Custom dataset/results directories
DATASETS_DIR=/path/to/datasets RESULTS_DIR=/path/to/results docker-compose up
```

## Notes

- The helper script `compose.sh` requires execution permissions: `chmod +x compose.sh`
- GPU device names may vary (`/dev/nvidia1`, etc.) on systems with multiple GPUs
- Podman rootless mode has additional complexity for GPU access; see [Podman documentation](https://docs.podman.io/en/latest/) for details
- The compose files maintain compatibility with both Docker and Podman
