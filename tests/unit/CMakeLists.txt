cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)

project(tests-unit )
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../test_deps.cmake)

set(APP_HW_TARGET           XK-EVK-XU316)

# Manually grab sources since we want to append unity to them
file(GLOB_RECURSE APP_C_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR} "src/*.c")
file(GLOB_RECURSE APP_CXX_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR} "src/*.cpp")

# Modify the included sources so they are relative
set(UNITY_C_SRCS_RELATIVE "")
foreach(ITEM IN LISTS UNITY_C_SRCS)
    string(REPLACE "${CMAKE_CURRENT_LIST_DIR}/" "" RELATIVE_ITEM "${ITEM}")
    list(APPEND UNITY_C_SRCS_RELATIVE ${RELATIVE_ITEM})
endforeach()

list(APPEND APP_C_SRCS ${UNITY_C_SRCS_RELATIVE})

set(APP_COMPILER_FLAGS              -O2
                                    -g
                                    -report
                                    -mcmodel=large
                                    -fcmdline-buffer-bytes=1024
                                    -Wno-xcore-fptrgroup
                                    -Wno-unknown-pragmas
                                    -Wno-format
                                    -fxscope
                                    ${UNITY_FLAGS})

set(APP_INCLUDES                    ${UNITY_INCLUDES}
                                    src)

XMOS_REGISTER_APP()
