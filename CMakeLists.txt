cmake_minimum_required(VERSION 3.14)

#**********************
# Setup XMOS toolchain
#**********************

set(XCORE_SDK_PATH "$ENV{XCORE_SDK_PATH}" CACHE FILEPATH "Absolute path to xCore SDK")

if ( XCORE_SDK_PATH STREQUAL "")
  message(FATAL_ERROR "xCore SDK path not found. User must either create an environment variable XCORE_SDK_PATH with " 
                      "the fully qualified path to the xCore SDK, or manually specify the path when configuring the "
                      "CMake build via -DXCORE_SDK_PATH=/path/to/sdk")
endif()

set(ENV{XCORE_SDK_PATH} ${XCORE_SDK_PATH})

include("${XCORE_SDK_PATH}/tools/cmake_utils/xmos_toolchain.cmake")

#**********************
# Project
#**********************

# Disable in-source build.
if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
    message(FATAL_ERROR "In-source build is not allowed! Please specify a build folder.\n\tex:cmake -B build")
endif()

project(lib_mic_array VERSION 5.0.0)

enable_language(CXX C ASM)


#**********************
# Options
#**********************
set(USE_LIB_DSP FALSE)
set(USE_LIB_LOGGING FALSE)
set(USE_LIB_RANDOM FALSE) 
set(USE_LEGACY_COMPAT FALSE)
set(USE_LIB_XS3_MATH TRUE)
set(USE_I2S_HIL TRUE)
set(USE_I2C_HIL TRUE)


include("$ENV{XCORE_SDK_PATH}/modules/modules.cmake")
include("$ENV{XCORE_SDK_PATH}/modules/hil/hil.cmake")
#**********************
# Apps
#**********************

add_subdirectory( demo )

#**********************
# Helper Targets
#**********************

