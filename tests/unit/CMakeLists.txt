cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)

project(tests-unit)
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_INCLUDES src)
set(APP_DEPENDENT_MODULES "lib_mic_array" "lib_unity(main)") #TODO release lib_unity

# conditional depending on target
if(CMAKE_C_COMPILER_VERSION VERSION_EQUAL "3.6.0")
    set(__XS3__ ON) # XS3 (XTC 15.3.1)
else()
    set(__XS3__ OFF) # VX4
endif()

# Target specific compiler flags
if(__XS3__)  # xs3
    set(APP_HW_TARGET               XK-EVK-XU316)
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
    set(APP_HW_TARGET               XK-EVK-XU416)
    set(APP_COMPILER_FLAGS  
                                    -Os 
                                    -g
                                    -DUNITY_INCLUDE_CONFIG_H=1)
endif()

XMOS_REGISTER_APP()
