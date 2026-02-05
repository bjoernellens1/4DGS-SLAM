#
# Copyright (C) 2023, Inria
# GRAPHDECO research group, https://team.inria.fr/graphdeco
# All rights reserved.
#
# This software is free for non-commercial, research and evaluation use 
# under the terms of the LICENSE.md file.
#
# For inquiries contact  george.drettakis@inria.fr
#

from setuptools import setup
from torch.utils.cpp_extension import CUDAExtension, BuildExtension
import os
import glob

cxx_compiler_flags = []

if os.name == 'nt':
    cxx_compiler_flags.append("/wd4624")

# Find libxcrypt include path for NixOS
def get_libxcrypt_include():
    try:
        # Try glob to find libxcrypt in nix store (much faster than find)
        paths = glob.glob('/nix/store/*/include/crypt.h')
        for path in paths:
            if 'libxcrypt' in path:
                return os.path.dirname(path)
    except:
        pass
    return None

libxcrypt_include = get_libxcrypt_include()

# Build compile args
nvcc_flags = [
    "-gencode=arch=compute_60,code=compute_60",
    "-gencode=arch=compute_61,code=compute_61",
    "-gencode=arch=compute_70,code=compute_70",
    "-gencode=arch=compute_75,code=compute_75",
    "-gencode=arch=compute_80,code=compute_80",
    "-gencode=arch=compute_86,code=compute_86",
]
if libxcrypt_include:
    nvcc_flags.append("-I" + libxcrypt_include)

setup(
    name="simple_knn",
    ext_modules=[
        CUDAExtension(
            name="simple_knn._C",
            sources=[
            "spatial.cu", 
            "simple_knn.cu",
            "ext.cpp"],
            extra_compile_args={
                "nvcc": nvcc_flags, 
                "cxx": cxx_compiler_flags
            })
        ],
    cmdclass={
        'build_ext': BuildExtension
    }
)
