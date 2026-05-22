cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(test_memory)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../../..)

set(APP_DEPENDENT_MODULES   "lib_mic_array")

if(APP_HW_TARGET STREQUAL "XK-EVK-XU416")
message(FATAL_ERROR "Unsupported target ${APP_HW_TARGET}. This test is only supported on XK-VOICE-L71.xn.")
endif()

set(APP_HW_TARGET XK-VOICE-L71.xn)

set(NAME_MAP custom;default)
foreach(N_MICS  1 2)
    foreach(USE_DEFAULT  1 0)
        list(GET NAME_MAP ${USE_DEFAULT} tmp)
        set(CONFIG ${N_MICS}mic_${tmp})
        set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                            -g
                                            -report
                                            -mcmodel=large
                                            -DAPP_NAME="MIC_ARRAY_MEASURE_MIPS_${CONFIG}"
                                            -DAPP_SAMP_FREQ=16000
                                            -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                            -DUSE_DEFAULT_API=${USE_DEFAULT})
endforeach()
endforeach()

set(APP_INCLUDES    src)

XMOS_REGISTER_APP()
