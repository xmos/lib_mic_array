cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(test_mips)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../../../../examples/deps.cmake)

set(APP_HW_TARGET XK-VOICE-L71.xn)

set(NAME_MAP thread;isr)
foreach(N_MICS  1 2)
    foreach(USE_ISR   1 0)
        list(GET NAME_MAP ${USE_ISR} tmp)
        foreach(SAMP_FREQ   16000 32000 48000)
        set(CONFIG "${N_MICS}mic_${tmp}_${SAMP_FREQ}fs")
            set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                                -g
                                                -report
                                                -mcmodel=large
                                                -DAPP_NAME="MIC_ARRAY_MEASURE_MIPS_${CONFIG}"
                                                -DMIC_ARRAY_CONFIG_USE_PDM_ISR=${USE_ISR}
                                                -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                                -DAPP_SAMP_FREQ=${SAMP_FREQ})
        endforeach()
    endforeach()
endforeach()

set(APP_INCLUDES    src src/mips/)

XMOS_REGISTER_APP()
