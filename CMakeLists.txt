cmake_minimum_required(VERSION 3.14)

#**********************
# Project
#**********************

# Disable in-source build.
if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
    message(FATAL_ERROR "In-source build is not allowed! Please specify a build folder.\n\tex:cmake -B build")
endif()

project(lib_mic_array 
    VERSION 5.0.0
    LANGUAGES CXX C ASM)

# Fixes issue where .xc files always recompile on Windows
string(REPLACE "-MD" "-MMD" CMAKE_DEPFILE_FLAGS_C ${CMAKE_DEPFILE_FLAGS_C})

# Add SDK
add_subdirectory(xcore_sdk EXCLUDE_FROM_ALL EXCLUDE_FROM_DEFAULT_BUILD)

# Add lib_mic_array
add_subdirectory(lib_mic_array)
set(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR})

# Make vanilla API macro available
include( etc/vanilla/vanilla.cmake )

#**********************
# Apps
#**********************

if(PROJECT_IS_TOP_LEVEL)
  add_subdirectory( demos )
  add_subdirectory( tests )
endif()
