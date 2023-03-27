cmake_minimum_required(VERSION 3.14)


# Disable in-source build.
if("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
    message(FATAL_ERROR "In-source build is not allowed! Please specify a build folder.\n\tex:cmake -B build")
endif()

include(cmake/CPM.cmake)

# if( PROJECT_IS_TOP_LEVEL )
#   message(STATUS "Configuring as top-level project")
#   set( DEV_LIB_MIC_ARRAY 1 )
# endif()

# If DEV_LIB_MIC_ARRAY is not defined, set it to true iff the root 
# build dir (CMAKE_BINARY_DIR) is a child of the current source dir.
# This will tell us whether to include the demos and tests.
if(NOT DEFINED DEV_LIB_MIC_ARRAY)
  set(DEV_LIB_MIC_ARRAY 0)
  get_filename_component(BIN_PARENT ${CMAKE_BINARY_DIR} DIRECTORY)
  if("${CMAKE_CURRENT_SOURCE_DIR}" STREQUAL "${BIN_PARENT}")
      set(DEV_LIB_MIC_ARRAY 1)
  endif()
endif()

project(lib_mic_array 
    VERSION 5.0.1
    LANGUAGES CXX C ASM)

if( PROJECT_IS_TOP_LEVEL OR ${DEV_LIB_MIC_ARRAY} )
  # Fixes issue where .xc files always recompile on Windows
  string(REPLACE "-MD" "-MMD" CMAKE_DEPFILE_FLAGS_C ${CMAKE_DEPFILE_FLAGS_C})
endif()

# Add lib_mic_array
add_subdirectory(lib_mic_array)

if( PROJECT_IS_TOP_LEVEL )
  set(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR})
endif()

# Make vanilla API macro available
include( etc/vanilla/vanilla.cmake )

#**********************
# Demos/Tests
#**********************

if(${DEV_LIB_MIC_ARRAY})
  CPMAddPackage(
    NAME lib_xcore_math
    GIT_REPOSITORY https://github.com/xmos/lib_xcore_math
    GIT_TAG        v2.1.0
  )
  add_subdirectory( demos )
  add_subdirectory( tests )
endif()
