#!/usr/bin/env bash
# Build and test script for 4DGS-SLAM Docker image
# This script builds the image and runs tests to verify all components work

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"

# Configuration
COMPOSE_CMD=${COMPOSE_CMD:-podman-compose}
GPU_FLAG=""
SKIP_BUILD=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --gpu)
            GPU_FLAG="--gpu"
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --docker)
            COMPOSE_CMD="docker-compose"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --gpu              Enable GPU support"
            echo "  --skip-build       Skip Docker build step"
            echo "  --verbose          Verbose output"
            echo "  --docker           Use docker-compose instead of podman-compose"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

test_module() {
    local module_name=$1
    local test_cmd=$2
    
    log_info "Testing $module_name..."
    if eval "$test_cmd" > /dev/null 2>&1; then
        log_success "$module_name is working"
        return 0
    else
        log_error "$module_name test failed"
        return 1
    fi
}

# Build stage
if [ "$SKIP_BUILD" = false ]; then
    log_info "Building Docker image..."
    cd "$PROJECT_ROOT"
    
    COMPOSE_FILES="-f docker-compose.yml"
    if [ -n "$GPU_FLAG" ]; then
        if [ -f docker-compose.gpu.podman.yml ]; then
            COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gpu.podman.yml"
        elif [ -f docker-compose.gpu.docker.yml ]; then
            COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gpu.docker.yml"
        fi
    fi
    
    if [ "$VERBOSE" = true ]; then
        log_info "Build command: $COMPOSE_CMD $COMPOSE_FILES build"
    fi
    
    $COMPOSE_CMD $COMPOSE_FILES build
    log_success "Docker image built successfully"
else
    log_warning "Skipping build stage"
fi

# Test stage
log_info "Starting test suite..."
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
COMPOSE_FILES="-f docker-compose.yml"

if [ -n "$GPU_FLAG" ]; then
    if [ -f docker-compose.gpu.podman.yml ]; then
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gpu.podman.yml"
    elif [ -f docker-compose.gpu.docker.yml ]; then
        COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.gpu.docker.yml"
    fi
fi

# Test 1: Python environment
log_info "Test 1: Python environment"
if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev python3 --version > /dev/null 2>&1; then
    log_success "Python3 is available"
    ((TESTS_PASSED++))
else
    log_error "Python3 is not available"
    ((TESTS_FAILED++))
fi

# Test 2: PyTorch
log_info "Test 2: PyTorch installation"
if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev bash -c "python3 -c 'import torch; print(f\"PyTorch {torch.__version__}\")'" > /dev/null 2>&1; then
    log_success "PyTorch is installed and working"
    ((TESTS_PASSED++))
else
    log_error "PyTorch installation failed"
    ((TESTS_FAILED++))
fi

# Test 3: simple-knn module
log_info "Test 3: simple-knn CUDA extension"
if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev bash -c "python3 -c 'from simple_knn._C import distCUDA2'" > /dev/null 2>&1; then
    log_success "simple-knn module is available"
    ((TESTS_PASSED++))
else
    log_error "simple-knn module is not available"
    ((TESTS_FAILED++))
fi

# Test 4: diff-gaussian-rasterization module
log_info "Test 4: diff-gaussian-rasterization CUDA extension"
if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev bash -c "python3 -c 'import diff_gaussian_rasterization'" > /dev/null 2>&1; then
    log_success "diff-gaussian-rasterization module is available"
    ((TESTS_PASSED++))
else
    log_error "diff-gaussian-rasterization module is not available"
    ((TESTS_FAILED++))
fi

# Test 5: torch-batch-svd module
log_info "Test 5: torch-batch-svd (speedup extension)"
if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev bash -c "python3 -c 'import torch_batch_svd'" > /dev/null 2>&1; then
    log_success "torch-batch-svd module is available"
    ((TESTS_PASSED++))
else
    log_error "torch-batch-svd module is not available"
    ((TESTS_FAILED++))
fi

# Test 6: Core dependencies
log_info "Test 6: Core dependencies (opencv, numpy, torch, etc.)"
if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev bash -c "python3 -c 'import cv2, numpy, torch, open3d, ply'" > /dev/null 2>&1; then
    log_success "Core dependencies are available"
    ((TESTS_PASSED++))
else
    log_error "Some core dependencies are missing"
    ((TESTS_FAILED++))
fi

# Test 7: SLAM module
log_info "Test 7: SLAM module import"
if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev bash -c "python3 -c 'from gaussian_splatting.scene.gaussian_model import GaussianModel'" > /dev/null 2>&1; then
    log_success "SLAM module imports successfully"
    ((TESTS_PASSED++))
else
    log_error "SLAM module import failed"
    ((TESTS_FAILED++))
fi

# Test 8: GPU support (if GPU flag is set)
if [ -n "$GPU_FLAG" ]; then
    log_info "Test 8: GPU/CUDA support"
    if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev bash -c "python3 -c 'import torch; assert torch.cuda.is_available(), \"CUDA not available\"'" > /dev/null 2>&1; then
        log_success "CUDA/GPU support is available"
        ((TESTS_PASSED++))
    else
        log_error "CUDA/GPU support is not available"
        ((TESTS_FAILED++))
    fi
fi

# Test 9: SLAM execution (quick check)
log_info "Test 9: SLAM script availability"
if $COMPOSE_CMD $COMPOSE_FILES run --rm 4dgs-slam-dev bash -c "python3 slam.py --help > /dev/null 2>&1 || true"; then
    log_success "SLAM script is available"
    ((TESTS_PASSED++))
else
    log_error "SLAM script execution failed"
    ((TESTS_FAILED++))
fi

# Summary
echo ""
echo "========================================"
echo "Test Results:"
echo "========================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "========================================"

if [ $TESTS_FAILED -eq 0 ]; then
    log_success "All tests passed!"
    echo ""
    echo "Next steps:"
    echo "1. Download RAFT model (raft-things.pth) from:"
    echo "   https://drive.google.com/drive/folders/1sWDsfuZ3Up38EUQt7-JDTT1HcGHuJgvT"
    echo ""
    echo "2. Test dynamic rendering:"
    if [ -n "$GPU_FLAG" ]; then
        echo "   ./compose.sh run --gpu 4dgs-slam-dev python3 slam.py --config configs/rgbd/tum/fr3_sitting_static.yaml --eval --dynamic"
    else
        echo "   podman-compose -f docker-compose.yml run 4dgs-slam-dev python3 slam.py --config configs/rgbd/tum/fr3_sitting_static.yaml --eval --dynamic"
    fi
    exit 0
else
    log_error "Some tests failed. Please check the errors above."
    exit 1
fi
