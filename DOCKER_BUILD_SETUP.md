# 4DGS-SLAM Docker Build and Setup Guide

## Overview

This document covers building and testing the 4DGS-SLAM Docker image with all required components:
- Core SLAM framework (Gaussian Splatting)
- CUDA extensions: `simple-knn` and `diff-gaussian-rasterization`
- Performance optimization: `torch-batch-svd`
- GPU support: NVIDIA CUDA with Podman and Docker compatibility

## Prerequisites

### System Requirements
- Docker or Podman (3.0+)
- NVIDIA GPU (optional but recommended)
- NVIDIA drivers installed on host
- 8GB+ RAM
- 50GB+ disk space for models and datasets

### Supported Platforms
- **Recommended**: Podman on NixOS with NVIDIA drivers
- **Alternative**: Docker with NVIDIA runtime
- **Linux Distributions**: Ubuntu 22.04, Fedora, CentOS, NixOS

## Building the Image

### Option 1: Using the Build and Test Script (Recommended)

```bash
# Build without GPU
./scripts/build_and_test.sh

# Build with GPU support
./scripts/build_and_test.sh --gpu

# Verbose output for debugging
./scripts/build_and_test.sh --gpu --verbose

# Skip build, run tests only
./scripts/build_and_test.sh --skip-build --gpu
```

### Option 2: Manual Build with Podman

```bash
# Without GPU
podman-compose -f docker-compose.yml build

# With GPU (NixOS optimized)
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml build
```

### Option 3: Manual Build with Docker

```bash
# Without GPU
docker-compose -f docker-compose.yml build

# With GPU
docker-compose -f docker-compose.yml -f docker-compose.gpu.docker.yml build
```

### Build Arguments

Customize the build with environment variables:

```bash
# Custom CUDA version
CUDA_BASE=12.1.1 podman-compose build

# Custom PyTorch version
TORCH_VERSION=2.0.0 TORCH_CUDA=cu118 podman-compose build

# All together
CUDA_BASE=12.1.1 TORCH_VERSION=2.0.0 TORCH_CUDA=cu118 podman-compose build
```

## Included Components

### 1. Base Environment
- **CUDA 11.7.1** (customizable)
- **PyTorch 1.13.1** with CUDA support
- **Python 3.10**
- **cuDNN 8** for deep learning operations

### 2. CUDA Extensions (Compiled from Source)

#### simple-knn
- Fast K-nearest neighbor search on GPU
- Location: `submodules/simple-knn/`
- Used by: Gaussian splatting for point cloud operations
- Test: `from simple_knn._C import distCUDA2`

#### diff-gaussian-rasterization
- Differentiable Gaussian rasterizer for rendering
- Location: `submodules/diff-gaussian-rasterization/`
- Used by: Gaussian splatting rendering pipeline
- Test: `import diff_gaussian_rasterization`

### 3. Performance Optimization

#### torch-batch-svd
- Batched SVD operations for acceleration
- Automatically cloned and built from: `https://github.com/KinglittleQ/torch-batch-svd`
- Optional but recommended for faster execution
- Test: `import torch_batch_svd`

### 4. Core Dependencies
- **OpenCV** 4.8.1 - Image processing
- **Open3D** 0.17.0 - 3D geometry processing
- **PyTorch3D** - 3D vision operations
- **NumPy/SciPy** - Scientific computing
- **LPIPS** - Perceptual loss metrics
- **Ultralytics** - YOLOv8 for segmentation
- **Weights & Biases** - Experiment tracking

## Verification and Testing

### Automated Testing

Run the comprehensive test suite:

```bash
# Quick test without GPU
./scripts/build_and_test.sh --skip-build

# Full test with GPU
./scripts/build_and_test.sh --gpu --skip-build
```

### Manual Testing

Test individual components inside the container:

```bash
# PyTorch
podman-compose run --rm 4dgs-slam-dev python3 -c "import torch; print(torch.__version__)"

# simple-knn
podman-compose run --rm 4dgs-slam-dev python3 -c "from simple_knn._C import distCUDA2; print('OK')"

# diff-gaussian-rasterization
podman-compose run --rm 4dgs-slam-dev python3 -c "import diff_gaussian_rasterization; print('OK')"

# torch-batch-svd
podman-compose run --rm 4dgs-slam-dev python3 -c "import torch_batch_svd; print('OK')"

# SLAM module
podman-compose run --rm 4dgs-slam-dev python3 -c "from gaussian_splatting.scene.gaussian_model import GaussianModel; print('OK')"

# CUDA availability (with GPU)
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml run --rm 4dgs-slam-dev python3 -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
```

## Running SLAM

### Prerequisites
1. Download TUM dataset (or use other supported datasets)
2. Download RAFT model (`raft-things.pth`):
   - Source: https://drive.google.com/drive/folders/1sWDsfuZ3Up38EUQt7-JDTT1HcGHuJgvT
   - Place in: `pretrained/` directory

### Basic Usage

```bash
# Without GPU
podman-compose run -it 4dgs-slam-dev python3 slam.py --config configs/rgbd/tum/fr3_sitting_static.yaml --eval

# With GPU
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml run -it 4dgs-slam-dev python3 slam.py --config configs/rgbd/tum/fr3_sitting_static.yaml --eval
```

### Testing Dynamic Rendering

```bash
# Basic dynamic rendering test
podman-compose run -it 4dgs-slam-dev \
  python3 slam.py \
  --config configs/rgbd/tum/fr3_sitting_static.yaml \
  --eval \
  --dynamic

# With custom image save interval (every 50 frames)
podman-compose run -it 4dgs-slam-dev \
  python3 slam.py \
  --config configs/rgbd/tum/fr3_sitting_static.yaml \
  --eval \
  --dynamic \
  --interval 50
```

### Using the Compose Helper Script

```bash
# Basic SLAM run with GPU
./compose.sh run --gpu 4dgs-slam-dev python3 slam.py --config configs/rgbd/tum/fr3_sitting_static.yaml --eval

# Dynamic rendering with GPU
./compose.sh run --gpu 4dgs-slam-dev \
  python3 slam.py \
  --config configs/rgbd/tum/fr3_sitting_static.yaml \
  --eval \
  --dynamic \
  --interval 50

# Interactive session with GPU
./compose.sh run --gpu 4dgs-slam-dev bash
```

## Dockerfile Architecture

### Multi-stage Build

The Dockerfile uses a two-stage approach for efficiency:

**Stage 1: Builder**
- Full CUDA development toolkit
- Build tools (cmake, ninja, gcc/g++)
- Compiles all CUDA extensions and torch-batch-svd
- 3-4GB image size

**Stage 2: Runtime**
- Minimal CUDA runtime (no development tools)
- Only necessary libraries for execution
- Final image size: ~1.5-2GB

### Key Build Steps
1. Install CUDA development tools and dependencies
2. Install PyTorch with CUDA support
3. Install Python package dependencies from `requirements.txt`
4. Build `simple-knn` CUDA extension
5. Build `diff-gaussian-rasterization` CUDA extension
6. Build `torch-batch-svd` from source
7. Copy compiled packages to runtime stage

## Troubleshooting

### Build Issues

**CUDA Out of Memory during build**
```bash
# Reduce parallel compilation
podman-compose build --build-arg NINJA_JOBS=1
```

**Missing CUDA libraries**
```bash
# Verify CUDA is available
podman-compose run --rm 4dgs-slam-dev nvcc --version

# Check CUDA paths
podman-compose run --rm 4dgs-slam-dev bash -c "echo $CUDA_HOME && ls $CUDA_HOME/lib64"
```

### Module Import Issues

**simple-knn not found**
```bash
# Check if compiled
podman-compose run --rm 4dgs-slam-dev python3 -m pip show simple-knn

# Verify CUDA capability
podman-compose run --rm 4dgs-slam-dev python3 -c "from simple_knn._C import distCUDA2; print('OK')"
```

**CUDA Capability Mismatch (on older GPUs)**
If you see warnings about `sm_60` compatibility with PyTorch compiled for `sm_70+`:
- This is expected on older GPUs like Tesla P100
- CUDA support is still available, but not fully optimized
- To fix: Use an older PyTorch version matching your GPU

### Runtime Issues

**GPU not detected in container**
- Verify: `podman-compose run 4dgs-slam-dev nvidia-smi`
- Check host: `nvidia-smi`
- See: `COMPOSE_GPU_SETUP.md` for GPU troubleshooting

**Out of memory errors during SLAM**
```bash
# Reduce batch size or resolution
python3 slam.py --config ... --downscale 2
```

## Performance Tuning

### GPU Acceleration
- Ensure `--gpu` flag is used with compose
- Check CUDA availability: `torch.cuda.is_available()`
- Monitor GPU usage: `nvidia-smi -l 1` in separate terminal

### CPU Optimization
- `torch-batch-svd` improves SVD performance
- Verify installation: `import torch_batch_svd`

### Memory Optimization
```bash
# Lower resolution input
python3 slam.py --config ... --downscale 2

# Reduce Gaussian count
python3 slam.py --config ... --max_gaussians 100000

# Smaller batch size
python3 slam.py --config ... --batch_size 4096
```

## Environment Variables

Set these when running containers:

```bash
# NVIDIA GPU settings
export NVIDIA_VISIBLE_DEVICES=all
export NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

# PyTorch settings
export CUDA_VISIBLE_DEVICES=0  # Use specific GPU

# SLAM settings
export PYTHONUNBUFFERED=1  # Immediate output
export WANDB_MODE=offline  # Disable Weights & Biases online
```

## References

- **4DGS-SLAM**: Repository of this project
- **Gaussian Splatting**: 3D Gaussian Splatting for Real-Time Radiance Field Rendering
- **simple-knn**: MonoGS fork for fast KNN operations
- **diff-gaussian-rasterization**: Differentiable Gaussian rasterizer
- **torch-batch-svd**: Batched SVD for PyTorch speedup
- **RAFT**: Recurrent All-Pairs Field Transforms
- **TUM Dataset**: RGB-D dataset for SLAM evaluation

## Support and Issues

For issues:
1. Check the troubleshooting section above
2. Verify all tests pass: `./scripts/build_and_test.sh`
3. Check Docker/Podman logs: `podman-compose logs 4dgs-slam-dev`
4. Verify GPU setup: See `COMPOSE_GPU_SETUP.md`
