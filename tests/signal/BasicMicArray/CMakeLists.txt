cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(tests-signal-basicmicarray)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../../../examples/deps.cmake)

set(APP_HW_TARGET       XVF3610_Q60A.xn)

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON N_MICS_LIST GET ${JSON_CONTENT} N_MICS)
string(JSON FRAME_SIZE_LIST GET ${JSON_CONTENT} FRAME_SIZE)
string(JSON USE_ISR_LIST GET ${JSON_CONTENT} USE_ISR)

# Convert JSON lists to CMake lists
string(JSON NUM_N_MICS LENGTH ${N_MICS_LIST})
string(JSON NUM_FRAME_SIZE LENGTH ${FRAME_SIZE_LIST})
string(JSON NUM_USE_ISR LENGTH ${USE_ISR_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_N_MICS "${NUM_N_MICS} - 1")
math(EXPR NUM_FRAME_SIZE "${NUM_FRAME_SIZE} - 1")
math(EXPR NUM_USE_ISR "${NUM_USE_ISR} - 1")

foreach(i RANGE 0 ${NUM_N_MICS})
    string(JSON N_MICS GET ${N_MICS_LIST} ${i})
    foreach(j RANGE 0 ${NUM_FRAME_SIZE})
        string(JSON FRAME_SIZE GET ${FRAME_SIZE_LIST} ${j})
        foreach(k RANGE 0 ${NUM_USE_ISR})
            string(JSON USE_ISR GET ${USE_ISR_LIST} ${k})
            
            set(CONFIG "${N_MICS}ch_${FRAME_SIZE}smp_${USE_ISR}isr")
            message(${CONFIG})
            set(APP_COMPILER_FLAGS_${CONFIG}    -O2
                                                -g
                                                -report
                                                -mcmodel=large
                                                -Wno-xcore-fptrgroup
                                                -Wno-unknown-pragmas
                                                -Wno-format
                                                -DCHAN_COUNT=${N_MICS}
                                                -DSAMPLES_PER_FRAME=${FRAME_SIZE}
                                                -DUSE_ISR=${USE_ISR}
                                                )
        endforeach()
    endforeach()
endforeach()

XMOS_REGISTER_APP()

