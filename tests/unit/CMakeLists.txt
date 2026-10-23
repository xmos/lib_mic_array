cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)

project(tests-unit)
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_INCLUDES src)
set(APP_DEPENDENT_MODULES "lib_mic_array" "lib_unity(v2.7.0)")

if(NOT DEFINED APP_HW_TARGET_VX)
    set(APP_HW_TARGET_VX ${CMAKE_CURRENT_LIST_DIR}/../../XK-EVK-XU416.xml)
endif()

# Target specific compiler flags
if(XMOS_IS_RV)
    set(APP_COMPILER_FLAGS          -O2
                                    -g
                                    -Wno-unknown-pragmas
                                    -Wno-format
                                    -DUNITY_INCLUDE_CONFIG_H=1)
elseif(NOT DEFINED APP_HW_TARGET OR APP_HW_TARGET STREQUAL "src/XK-VOICE-L71.xn")
    set(APP_HW_TARGET src/XK-VOICE-L71.xn)
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
elseif(APP_HW_TARGET STREQUAL "XK-EVK-XU416")
    set(APP_COMPILER_FLAGS  
                                    -Os 
                                    -g
                                    -Wno-fptrgroup
                                    -DUNITY_INCLUDE_CONFIG_H=1)
else()
    message(FATAL_ERROR "Unsupported target ${APP_HW_TARGET}.")
endif()

XMOS_REGISTER_APP()

if(XMOS_IS_RV)
    set_property(
        SOURCE ${XMOS_SANDBOX_DIR}/lib_unity/lib_unity/unity_helper.c
        APPEND PROPERTY COMPILE_OPTIONS -U__VX4B__
    )
endif()
