cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_mic_array)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

# Slipgate target
if(NOT DEFINED APP_HW_TARGET AND NOT XMOS_IS_RV)
    set(APP_HW_TARGET XK-EVK-XU416)
endif()

if(NOT XMOS_IS_RV AND NOT APP_HW_TARGET STREQUAL "XK-EVK-XU416")
    message(FATAL_ERROR "This application is only supported for XK-EVK-XU416.")
endif()

# New VX4 toolchain target
if(NOT DEFINED APP_HW_TARGET_VX)
    set(APP_HW_TARGET_VX ${CMAKE_CURRENT_LIST_DIR}/../../XK-EVK-XU416.xml)
endif()

if(XMOS_IS_RV)
    set(APP_C_SRCS
        src/app.c
        src/device_pll_ctrl.c
    )
endif()

set(APP_DEPENDENT_MODULES "lib_mic_array")

set(APP_COMPILER_FLAGS
    -Os
    -g
    -Wall
    # Mic array config
    -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=320
    -DMIC_ARRAY_CONFIG_MIC_COUNT=1
    -DMIC_ARRAY_CONFIG_USE_PDM_ISR=0
)

if(NOT XMOS_IS_RV)
    list(APPEND APP_COMPILER_FLAGS -report -fxscope)
endif()

XMOS_REGISTER_APP()
