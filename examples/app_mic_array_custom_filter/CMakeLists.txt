cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_mic_array_custom_filter)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../deps.cmake)
set(APP_HW_TARGET XK-VOICE-L71.xn)

set(NAME_MAP thread;isr)
foreach(N_MICS  1 2)
    foreach(USE_ISR   1 0)
        list(GET NAME_MAP ${USE_ISR} tmp)
        set(CONFIG "${N_MICS}mic_${tmp}")

        set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                            -g
                                            -report
                                            -mcmodel=large
                                            -DBOARD_SUPPORT_BOARD=XK_VOICE_L71
                                            -DAPP_NAME="MIC_ARRAY_${CONFIG}"
                                            -DMIC_ARRAY_CONFIG_USE_PDM_ISR=${USE_ISR}
                                            -DAPP_MIC_COUNT=${N_MICS})
    endforeach()
endforeach()

set(APP_INCLUDES    src)

XMOS_REGISTER_APP()
