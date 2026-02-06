# Docker/Podman Compose GPU Setup Guide

This guide explains how to use the compose files with both Docker and Podman, with NVIDIA GPU support.

## Files

- `docker-compose.yml` - Base compose file (CPU-only)
- `docker-compose.gpu.docker.yml` - GPU support for Docker (device passthrough)
- `docker-compose.gpu.podman.yml` - GPU support for Podman (device + library mounting for NixOS)
- `compose.sh` - Helper script to automatically detect runtime and manage GPU support

## Quick Start

### Using the Helper Script (Recommended)

The easiest way to run containers with automatic GPU detection:

```bash
# Without GPU
./compose.sh up -d

# With GPU
./compose.sh up -d --gpu

# Interactive bash session with GPU
./compose.sh run 4dgs-slam-dev --gpu bash

# Verbose output to see the exact command being run
./compose.sh up -d --gpu --verbose
```

### Manual: Using Docker Compose

**Without GPU:**
```bash
docker-compose -f docker-compose.yml up -d
```

**With GPU (requires nvidia-docker or Docker with nvidia-runtime):**
```bash
docker-compose -f docker-compose.yml -f docker-compose.gpu.docker.yml up -d
```

### Manual: Using Podman Compose

**Without GPU:**
```bash
podman-compose -f docker-compose.yml up -d
```

**With GPU:**
```bash
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml up -d
```

## GPU Support Details

### Docker
Docker uses direct device passthrough (`/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-uvm`) to give containers access to NVIDIA GPUs. This requires:

- NVIDIA GPU
- NVIDIA drivers installed on host
- Docker daemon with NVIDIA runtime support

The device passthrough is configured in `docker-compose.gpu.docker.yml`.

### Podman with NixOS (Tested)

Podman on NixOS requires special configuration since:
1. NVIDIA drivers are provided by the NixOS system
2. Driver libraries are in `/run/opengl-driver/lib/`
3. Libraries are symlinked through `/nix/store/`

The `docker-compose.gpu.podman.yml` file handles this by:
- Mounting NVIDIA device files (`/dev/nvidia*`)
- Mounting driver libraries from `/run/opengl-driver/lib`
- Mounting `/nix/store` for symlink resolution
- Setting `LD_LIBRARY_PATH` to find the libraries

**Prerequisites:**
- NVIDIA GPU
- NVIDIA drivers installed on NixOS
- Podman 3.0+ (4.0+ recommended)
- `podman-compose` package

### Podman with Other Linux Distributions

For non-NixOS systems, you may need to:

1. **Install NVIDIA Container Toolkit:**
   ```bash
   # Ubuntu/Debian
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
     sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   
   # Fedora/RHEL
   sudo dnf install nvidia-container-toolkit
   ```

2. **Configure Podman to use NVIDIA runtime:**
   ```bash
   # Edit /etc/containers/containers.conf and add:
   runtime_path = [
       "/usr/bin/nvidia-container-runtime",
       "/usr/bin/runc"
   ]
   ```

3. **Or use the standard docker-compose.gpu.docker.yml** (device passthrough) which works on most systems.

## Environment Variables

Configure the setup with environment variables:

```bash
# Custom CUDA base image version (Docker build time)
CUDA_BASE=12.1.1 ./compose.sh up

# Custom PyTorch versions (Docker build time)
TORCH_VERSION=2.0.0 TORCH_CUDA=cu118 ./compose.sh up

# Custom dataset/results directories
DATASETS_DIR=/path/to/datasets RESULTS_DIR=/path/to/results ./compose.sh up

# Custom username/IDs in container
USERNAME=myuser USER_ID=1001 GROUP_ID=1001 ./compose.sh up

# NVIDIA GPU visibility
NVIDIA_VISIBLE_DEVICES=0 ./compose.sh run --gpu 4dgs-slam-dev bash  # Only GPU 0
```

## Verification

Test that GPU access is working:

```bash
# Using helper script
./compose.sh run --rm --gpu 4dgs-slam-dev bash -c \
  "python3 -c \"import torch; print(f'CUDA: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0)}')\""

# Manual podman-compose
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml run --rm 4dgs-slam-dev \
  bash -c "python3 -c \"import torch; print(f'CUDA: {torch.cuda.is_available()}')\""
```

Expected output on Tesla P100:
```
CUDA: True
GPU: Tesla P100-PCIE-16GB
```

Note: Warnings about CUDA capability compatibility are expected if your GPU is older than the PyTorch build target.

## Troubleshooting

### GPU Not Detected in Container

**Check host GPU:**
```bash
# Host-level verification
nvidia-smi           # If using standard NVIDIA drivers
ls -la /dev/nvidia*  # Check device files exist
```

**Debug inside container:**
```bash
# With Docker
docker-compose -f docker-compose.yml -f docker-compose.gpu.docker.yml run --rm 4dgs-slam-dev \
  bash -c "ls -la /dev/nvidia* && echo '---' && python3 -c 'import torch; print(torch.cuda.is_available())'"

# With Podman
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml run --rm 4dgs-slam-dev \
  bash -c "ls -la /dev/nvidia* && echo '---' && python3 -c 'import torch; print(torch.cuda.is_available())'"
```

### Permission Denied Accessing NVIDIA Devices

On Podman (especially rootless), you may need to run with elevated privileges:
```bash
sudo podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml up
```

### "CUDA not found" or Library Errors

Check library paths inside the container:
```bash
./compose.sh run --rm --gpu 4dgs-slam-dev \
  bash -c "echo \$LD_LIBRARY_PATH && ls /usr/lib/nvidia/"
```

On NixOS, verify the opengl-driver is mounted:
```bash
./compose.sh run --rm --gpu 4dgs-slam-dev bash -c "ls -la /run/opengl-driver/"
```

### PyTorch CUDA Capability Warnings

If you see warnings like "cuda capability sm_60 is not compatible", this means:
- Your GPU's architecture (sm_60 = P100) is older than PyTorch was compiled for (minimum sm_70)
- This is a compatibility mismatch, not a configuration error
- To fix, use an older PyTorch version or a GPU with sm_70+
- For now, you can ignore the warnings - CUDA support is still available

## Advanced Usage

### Build and Test in One Command
```bash
./compose.sh build --no-cache && \
  ./compose.sh run --rm --gpu 4dgs-slam-dev \
    bash -c "python3 -c \"import torch; print(torch.cuda.is_available())\""
```

### Run SLAM with GPU
```bash
./compose.sh run --gpu 4dgs-slam-dev slam.py --config configs/rgbd/tum/fr3_walking_static.yaml
```

### Multiple GPU Devices
```bash
# Use specific GPU
NVIDIA_VISIBLE_DEVICES=0 ./compose.sh run --gpu 4dgs-slam-dev bash

# Use multiple GPUs
NVIDIA_VISIBLE_DEVICES=0,1 ./compose.sh run --gpu 4dgs-slam-dev bash
```

## Docker vs Podman Summary

| Feature | Docker | Podman |
|---------|--------|--------|
| GPU Support | Device passthrough | Device + library mounting |
| NVIDIA Runtime | Built-in | Toolkit required (or device mount) |
| NixOS Support | Good | Excellent (with proper mounts) |
| Rootless | Limited GPU support | Possible with config |
| Performance | Mature | Production-ready |

## Notes

- The helper script `compose.sh` requires execution permissions: `chmod +x compose.sh`
- GPU device names vary on multi-GPU systems (`/dev/nvidia0`, `/dev/nvidia1`, etc.)
- On NixOS, the `docker-compose.gpu.podman.yml` file is optimized for the platform
- The Dockerfile is built with CUDA 11.7.1 and PyTorch 1.13.1 by default
- Library mounting on NixOS adds ~500MB overhead per container (one-time at container start)

