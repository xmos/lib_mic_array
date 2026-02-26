cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_mic_array)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_HW_TARGET src/XK-EVK-XU316-AIV.xn)
set(APP_DEPENDENT_MODULES "lib_mic_array")
set(APP_INCLUDES    src)

set(APP_COMPILER_FLAGS
    -Os
    -g
    -report
    -Wall
    -fxscope
    -Wno-xcore-fptrgroup
    # Mic array config
    -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=320
    -DMIC_ARRAY_CONFIG_MIC_COUNT=1
    -DMIC_ARRAY_CONFIG_USE_PDM_ISR=0
)

XMOS_REGISTER_APP()
