# Quick Start Guide - 4DGS-SLAM Docker

## 🚀 Quick Commands

### Build the Image

```bash
# Automatic detection of Docker/Podman with tests
./scripts/build_and_test.sh --gpu

# Manual build (Podman recommended)
podman-compose -f docker-compose.yml -f docker-compose.gpu.podman.yml build
```

### Run SLAM

```bash
# Interactive session
./compose.sh run --gpu 4dgs-slam-dev bash

# Execute SLAM with GPU
./compose.sh run --gpu 4dgs-slam-dev \
  python3 slam.py \
  --config configs/rgbd/tum/fr3_sitting_static.yaml \
  --eval --dynamic

# Save images every 50 frames
./compose.sh run --gpu 4dgs-slam-dev \
  python3 slam.py \
  --config configs/rgbd/tum/fr3_sitting_static.yaml \
  --eval --dynamic --interval 50
```

## ✅ Verify Installation

```bash
# Quick test all components
./scripts/build_and_test.sh --skip-build --gpu

# Test individual modules
./compose.sh run --rm --gpu 4dgs-slam-dev \
  python3 -c "from simple_knn._C import distCUDA2; print('simple-knn: OK')"

./compose.sh run --rm --gpu 4dgs-slam-dev \
  python3 -c "import diff_gaussian_rasterization; print('diff-gaussian-rasterization: OK')"

./compose.sh run --rm --gpu 4dgs-slam-dev \
  python3 -c "import torch_batch_svd; print('torch-batch-svd: OK')"

./compose.sh run --rm --gpu 4dgs-slam-dev \
  python3 -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
```

## 📥 Download Requirements

### 1. RAFT Model
```bash
# Download from Google Drive
# https://drive.google.com/drive/folders/1sWDsfuZ3Up38EUQt7-JDTT1HcGHuJgvT
# Place raft-things.pth in ./pretrained/
mkdir -p pretrained
# Download and copy raft-things.pth here
```

### 2. TUM Dataset
```bash
# Download script already exists
./scripts/download_tum_dynamic.sh
```

## 📊 Included Components

| Component | Version | Type | Status |
|-----------|---------|------|--------|
| CUDA | 11.7.1 | Base | ✅ Compiled |
| PyTorch | 1.13.1 | Framework | ✅ Installed |
| simple-knn | - | Extension | ✅ Compiled |
| diff-gaussian-rasterization | - | Extension | ✅ Compiled |
| torch-batch-svd | Latest | Optimization | ✅ Compiled |
| OpenCV | 4.8.1 | Library | ✅ Installed |
| Open3D | 0.17.0 | Library | ✅ Installed |
| YOLO v8 | Latest | Model | ✅ Installed |

## 🐛 Troubleshooting

### GPU Not Working
```bash
# Check host GPU
nvidia-smi

# Check container GPU access
./compose.sh run --gpu 4dgs-slam-dev nvidia-smi

# Verify CUDA
./compose.sh run --gpu 4dgs-slam-dev python3 -c "import torch; print(torch.cuda.is_available())"
```

### Build Failed
```bash
# Clean and rebuild
podman-compose down
podman-compose build --no-cache

# With verbose output
podman-compose build --verbose
```

### Module Import Error
```bash
# Check installed packages
./compose.sh run --rm 4dgs-slam-dev python3 -m pip list

# Reinstall a specific module
./compose.sh run --rm 4dgs-slam-dev \
  python3 -m pip install --no-cache-dir simple-knn --no-build-isolation
```

## 📚 Documentation

- **Docker Setup**: See `DOCKER_BUILD_SETUP.md` for detailed build information
- **GPU Setup**: See `COMPOSE_GPU_SETUP.md` for GPU configuration
- **SLAM Config**: Check `configs/rgbd/tum/` for available configurations

## 🔧 Configuration Variables

```bash
# Custom CUDA version
CUDA_BASE=12.1.1 podman-compose build

# Custom PyTorch
TORCH_VERSION=2.0.0 TORCH_CUDA=cu118 podman-compose build

# Custom dataset location
DATASETS_DIR=/path/to/datasets ./compose.sh run 4dgs-slam-dev bash

# Disable GPU
./compose.sh run 4dgs-slam-dev bash  # (no --gpu flag)
```

## 📈 Performance Tips

1. **Enable torch-batch-svd** - Automatically compiled, improves SVD performance
2. **Use GPU** - Always use `--gpu` flag for significant speedup
3. **Lower resolution** - Add `--downscale 2` for faster iteration
4. **Monitor GPU** - Run `nvidia-smi -l 1` in separate terminal

## 🎯 Next Steps

1. ✅ Build image: `./scripts/build_and_test.sh --gpu`
2. ✅ Verify tests: Tests run automatically
3. 📥 Download RAFT: Place `raft-things.pth` in `pretrained/`
4. 📥 Download TUM data: `./scripts/download_tum_dynamic.sh`
5. 🚀 Run SLAM: `./compose.sh run --gpu 4dgs-slam-dev python3 slam.py ...`
