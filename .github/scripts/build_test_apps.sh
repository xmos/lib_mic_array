#!/bin/bash

pwd

wget https://raw.githubusercontent.com/xmos/xmos_cmake_toolchain/main/xs3a.cmake
wget https://raw.githubusercontent.com/xmos/xmos_cmake_toolchain/main/xc_override.cmake
cmake -B build.xcore -DDEV_LIB_MIC_ARRAY=1 -DCMAKE_TOOLCHAIN_FILE=./xs3a.cmake
pushd build.xcore
make all -j 4 # Jenkins and github don't like large numbers here and will crash

# I can't get the following two (custom) targets to build with 'all'.
# Currently an issue with java prevents these from working in CI.
# make tests-legacy_build
# make tests-legacy_build_vanilla
