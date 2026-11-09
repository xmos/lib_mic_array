cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)

project(tests-unit)
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_INCLUDES src)
set(APP_DEPENDENT_MODULES "lib_mic_array" "lib_unity(develop)")

set(APP_COMPILER_FLAGS -g -DUNITY_INCLUDE_CONFIG_H=1)

# Target specific compiler flags
if(XMOS_IS_RV OR APP_HW_TARGET STREQUAL "XK-EVK-XU416")
    list(APPEND APP_COMPILER_FLAGS  -O2)
elseif(NOT DEFINED APP_HW_TARGET OR APP_HW_TARGET STREQUAL "XK-EVK-XU316")
    set(APP_HW_TARGET XK-EVK-XU316)
    list(APPEND APP_COMPILER_FLAGS  -O2
                                    -report
                                    -mcmodel=large
                                    -fcmdline-buffer-bytes=1024
                                    -Wno-xcore-fptrgroup
                                    -Wno-unknown-pragmas
                                    -Wno-format
                                    -fxscope)
else()
    message(FATAL_ERROR "Unsupported target ${APP_HW_TARGET}.")
endif()

XMOS_REGISTER_APP()
