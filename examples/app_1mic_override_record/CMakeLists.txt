cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_mic_array)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

# targets (IF NOT DEFINED OR NOT SUPPORTED)
if(NOT DEFINED APP_HW_TARGET OR NOT APP_HW_TARGET STREQUAL "XK-EVK-XU416")
    message(FATAL_ERROR "This application is only supported for XK-EVK-XU416. Please re-run cmake with -DAPP_HW_TARGET=XK-EVK-XU416.")
endif()

set(APP_DEPENDENT_MODULES "lib_mic_array" "lib_sw_pll")

set(APP_COMPILER_FLAGS
    -Os
    -g
    -report
    -Wall
    -fxscope
    # Mic array config
    -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=1
    -DMIC_ARRAY_CONFIG_MIC_COUNT=2
    -DMIC_ARRAY_CONFIG_USE_PDM_ISR=0
)

XMOS_REGISTER_APP()
