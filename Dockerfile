ARG CUDA_BASE=11.7.1
FROM nvidia/cuda:${CUDA_BASE}-cudnn8-devel-ubuntu22.04

LABEL maintainer="4DGS-SLAM Contributors"
LABEL description="4D Gaussian Splatting SLAM dev environment with CUDA and OpenGL support"

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=slam
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG TORCH_VERSION=1.13.1
ARG TORCHVISION_VERSION=0.14.1
ARG TORCHAUDIO_VERSION=0.13.1
ARG TORCH_CUDA=cu117

ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    libgl1 \
    libglib2.0-0 \
    libglu1 \
    libglfw3 \
    libglfw3-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev \
    libxext-dev \
    libxrandr-dev \
    ffmpeg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${GROUP_ID} ${USERNAME} && \
    useradd --uid ${USER_ID} --gid ${GROUP_ID} -m -s /bin/bash ${USERNAME}

WORKDIR /workspace

COPY requirements.txt /tmp/requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --upgrade pip setuptools wheel && \
    python3 -m pip install torch==${TORCH_VERSION}+${TORCH_CUDA} torchvision==${TORCHVISION_VERSION}+${TORCH_CUDA} torchaudio==${TORCHAUDIO_VERSION} \
      --extra-index-url https://download.pytorch.org/whl/${TORCH_CUDA} && \
    python3 -m pip install -r /tmp/requirements.txt

USER ${USERNAME}

CMD ["/bin/bash"]
