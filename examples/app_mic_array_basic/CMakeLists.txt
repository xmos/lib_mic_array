cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_mic_array)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

# conditional depending on target
set(APP_C_SRCS  src/app.c)

if(CMAKE_C_COMPILER_VERSION VERSION_EQUAL "3.6.0")
    set(__XS3__ ON) # XS3 (XTC 15.3.1)
    set(APP_HW_TARGET   xs3/XK-EVK-XU316-AIV.xn)
    set(APP_INCLUDES    src xs3)
    list(APPEND APP_C_SRCS 
        xs3/device_pll_ctrl.c
    )
    list(APPEND APP_XC_SRCS 
        xs3/mapfile.xc
    )
else()
    set(__XS3__ OFF) # VX4
    set(APP_HW_TARGET   vx4/XK-EVK-XU416.xn)
    set(APP_INCLUDES    src vx4)
    list(APPEND APP_C_SRCS 
        vx4/device_pll_ctrl.c
        vx4/mapfile.c
    )
endif()

set(APP_DEPENDENT_MODULES "lib_mic_array")

set(APP_COMPILER_FLAGS
    -Os
    -g
    -report
    -Wall
    -fxscope
    # -Wno-xcore-fptrgroup
    # Mic array config
    -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=320
    -DMIC_ARRAY_CONFIG_MIC_COUNT=1
    -DMIC_ARRAY_CONFIG_USE_PDM_ISR=0
)

XMOS_REGISTER_APP()
