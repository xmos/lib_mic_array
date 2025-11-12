cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_par_decimator)
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../deps.cmake)
set(APP_HW_TARGET           XK-VOICE-L71.xn)

set(NAME_MAP pdmrx_thread;pdmrx_isr)
foreach( N_MICS  2 )
    foreach(USE_ISR 1 0)
        list(GET NAME_MAP ${USE_ISR} tmp)
        set(CONFIG "${N_MICS}mic_${tmp}")

        set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                            -g
                                            -report
                                            -mcmodel=large
                                            -DBOARD_SUPPORT_BOARD=XK_VOICE_L71
                                            -DAPP_N_MICS=${N_MICS}
                                            -DAPP_SAMPLES_PER_FRAME=1
                                            -DAPP_USE_DC_ELIMINATION=1
                                            -DAPP_USE_PDMRX_ISR=${USE_ISR}
                                            -DAPP_NAME="MIC_ARRAY_PAR_DECIMATOR_${CONFIG}")
    endforeach()
endforeach()

set(APP_INCLUDES    src)

XMOS_REGISTER_APP()
