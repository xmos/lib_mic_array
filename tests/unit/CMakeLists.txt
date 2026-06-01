cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)

project(tests-unit)
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_INCLUDES src)
set(APP_DEPENDENT_MODULES "lib_mic_array" "lib_unity(v2.7.0)")

# Target specific compiler flags
if(NOT DEFINED APP_HW_TARGET OR APP_HW_TARGET STREQUAL "XK-EVK-XU316") 
    set(APP_HW_TARGET XK-EVK-XU316)
    set(APP_COMPILER_FLAGS          -O2
                                    -g
                                    -report
                                    -mcmodel=large
                                    -fcmdline-buffer-bytes=1024
                                    -Wno-xcore-fptrgroup
                                    -Wno-unknown-pragmas
                                    -Wno-format
                                    -fxscope
                                    -DUNITY_INCLUDE_CONFIG_H=1)
else() # vx4
    if(APP_HW_TARGET STREQUAL "XK-EVK-XU416")
    set(APP_COMPILER_FLAGS  
                                    -Os 
                                    -g
                                    -Wno-fptrgroup
                                    -DUNITY_INCLUDE_CONFIG_H=1)
    else()
        message(FATAL_ERROR "Unsupported target ${APP_HW_TARGET}.")
    endif()
endif()

XMOS_REGISTER_APP()
