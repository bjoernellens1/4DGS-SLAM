ARG CUDA_BASE=11.7.1
# Stage 1: Build stage with all development tools
FROM nvidia/cuda:${CUDA_BASE}-cudnn8-devel-ubuntu22.04 AS builder

LABEL maintainer="4DGS-SLAM Contributors"
LABEL description="4D Gaussian Splatting SLAM dev environment with CUDA and OpenGL support"

ARG DEBIAN_FRONTEND=noninteractive
ARG TORCH_VERSION=1.13.1
ARG TORCHVISION_VERSION=0.14.1
ARG TORCHAUDIO_VERSION=0.13.1
ARG TORCH_CUDA=cu117

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONUNBUFFERED=1

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-dev \
    python3-pip \
    git \
    wget \
    build-essential \
    cmake \
    ninja-build \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy requirements
COPY requirements.txt /build/requirements.txt

# Install Python packages in build stage
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    python3 -m pip install --no-cache-dir torch==${TORCH_VERSION}+${TORCH_CUDA} torchvision==${TORCHVISION_VERSION}+${TORCH_CUDA} torchaudio==${TORCHAUDIO_VERSION} \
      --extra-index-url https://download.pytorch.org/whl/${TORCH_CUDA} && \
    python3 -m pip install --no-cache-dir -r /build/requirements.txt --no-build-isolation

# Stage 2: Runtime stage with minimal footprint
FROM nvidia/cuda:${CUDA_BASE}-cudnn8-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=slam
ARG USER_ID=1000
ARG GROUP_ID=1000

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONUNBUFFERED=1

# Install only runtime dependencies (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    git \
    libgl1 \
    libglib2.0-0 \
    libglu1 \
    libglfw3 \
    libxinerama1 \
    libxcursor1 \
    libxi6 \
    libxext6 \
    libxrandr2 \
    ffmpeg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Create user
RUN if ! getent group ${GROUP_ID} > /dev/null; then groupadd --gid ${GROUP_ID} ${USERNAME}; fi && \
    if ! getent passwd ${USER_ID} > /dev/null; then useradd --uid ${USER_ID} --gid ${GROUP_ID} -m -s /bin/bash ${USERNAME}; fi

WORKDIR /workspace

USER ${USERNAME}

CMD ["/bin/bash"]
