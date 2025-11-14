cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(test_ma)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../../../examples/deps.cmake)

set(APP_HW_TARGET       XK-EVK-XU316)

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON N_MICS_LIST GET ${JSON_CONTENT} N_MICS)
string(JSON FRAME_SIZE_LIST GET ${JSON_CONTENT} FRAME_SIZE)
string(JSON USE_ISR_LIST GET ${JSON_CONTENT} USE_ISR)
string(JSON SAMP_FREQ_LIST GET ${JSON_CONTENT} SAMP_FREQ)

# Convert JSON lists to CMake lists
string(JSON NUM_N_MICS LENGTH ${N_MICS_LIST})
string(JSON NUM_FRAME_SIZE LENGTH ${FRAME_SIZE_LIST})
string(JSON NUM_USE_ISR LENGTH ${USE_ISR_LIST})
string(JSON NUM_SAMP_FREQ LENGTH ${SAMP_FREQ_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_N_MICS "${NUM_N_MICS} - 1")
math(EXPR NUM_FRAME_SIZE "${NUM_FRAME_SIZE} - 1")
math(EXPR NUM_USE_ISR "${NUM_USE_ISR} - 1")
math(EXPR NUM_SAMP_FREQ "${NUM_SAMP_FREQ} - 1")

foreach(i RANGE 0 ${NUM_N_MICS})
    string(JSON N_MICS GET ${N_MICS_LIST} ${i})
    foreach(j RANGE 0 ${NUM_FRAME_SIZE})
        string(JSON FRAME_SIZE GET ${FRAME_SIZE_LIST} ${j})
        foreach(k RANGE 0 ${NUM_USE_ISR})
            string(JSON USE_ISR GET ${USE_ISR_LIST} ${k})
            foreach(l RANGE 0 ${NUM_SAMP_FREQ})
                string(JSON SAMP_FREQ GET ${SAMP_FREQ_LIST} ${l})
                set(CONFIG "${N_MICS}ch_${FRAME_SIZE}smp_${USE_ISR}isr_${SAMP_FREQ}fs")
                message(${CONFIG})
                set(APP_COMPILER_FLAGS_${CONFIG}    -O2
                                                    -g
                                                    -report
                                                    -mcmodel=large
                                                    -Wno-xcore-fptrgroup
                                                    -Wno-unknown-pragmas
                                                    -Wno-format
                                                    -DMIC_ARRAY_CONFIG_USE_PDM_ISR=${USE_ISR}
                                                    -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=${FRAME_SIZE}
                                                    -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                                    -DMIC_ARRAY_CONFIG_MIC_IN_COUNT=${N_MICS}
                                                    -DMIC_ARRAY_CONFIG_USE_DC_ELIMINATION=0
                                                    -DAPP_SAMP_FREQ=${SAMP_FREQ}
                                                    )
            endforeach()
        endforeach()
    endforeach()
endforeach()

XMOS_REGISTER_APP()

