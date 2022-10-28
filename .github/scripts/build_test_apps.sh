#!/bin/bash
set -e

pwd

wget https://raw.githubusercontent.com/xmos/xmos_cmake_toolchain/main/xs3a.cmake
wget https://raw.githubusercontent.com/xmos/xmos_cmake_toolchain/main/xc_override.cmake
cmake -B build.xcore -DDEV_LIB_MIC_ARRAY=1 -DCMAKE_TOOLCHAIN_FILE=./xs3a.cmake
cmake --build build.xcore
