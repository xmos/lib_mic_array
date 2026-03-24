cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_1mic_override)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../deps.cmake)
set(APP_HW_TARGET XK-VOICE-L71.xn)

set(APP_COMPILER_FLAGS  -Os
                        -g
                        -report
                        -mcmodel=large
                        -DBOARD_SUPPORT_BOARD=XK_VOICE_L71
                        -DMIC_ARRAY_CONFIG_USE_PDM_ISR=0
                        -DMIC_ARRAY_CONFIG_MIC_COUNT=2)

set(APP_INCLUDES    src)

XMOS_REGISTER_APP()
