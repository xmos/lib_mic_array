cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(tests-signal-decimator)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../../../examples/deps.cmake)

set(APP_HW_TARGET       XVF3610_Q60A.xn)

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON CONFIG_LIST GET ${JSON_CONTENT} CONFIG)
# Convert JSON lists to CMake lists
string(JSON NUM_CONFIG LENGTH ${CONFIG_LIST})
# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_CONFIG "${NUM_CONFIG} - 1")

foreach(i RANGE 0 ${NUM_CONFIG})
    string(JSON CONFIG GET ${CONFIG_LIST} ${i})
    string(JSON N_MICS GET ${CONFIG} N_MICS)
    string(JSON S2DECFACTOR GET ${CONFIG} S2DECFACTOR)
    string(JSON S2TAPCOUNT GET ${CONFIG} S2TAPCOUNT)

    set(CONFIG "${N_MICS}ch_${S2DECFACTOR}s2dec_${S2TAPCOUNT}s2taps")
    message(${CONFIG})
    set(APP_COMPILER_FLAGS_${CONFIG}    -O2
                                        -g
                                        -report
                                        -mcmodel=large
                                        -Wno-xcore-fptrgroup
                                        -Wno-unknown-pragmas
                                        -Wno-format
                                        -DCHAN_COUNT=${N_MICS}
                                        -DS2_DEC_FACT=${S2DECFACTOR}
                                        -DS2_TAPS=${S2TAPCOUNT}
                                        )
endforeach()

XMOS_REGISTER_APP()
