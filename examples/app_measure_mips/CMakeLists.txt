cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(measure_mips)

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
                                            -DAPP_NAME="MIC_ARRAY_MEASURE_MIPS_${CONFIG}"
                                            -DMIC_ARRAY_CONFIG_USE_PDM_ISR=${USE_ISR}
                                            -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                            -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=16)
    endforeach()
endforeach()

# Manually set sources as we take from the common directory too
file(GLOB_RECURSE APP_C_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.c" "../common/src/mips/*.c")
file(GLOB_RECURSE APP_XC_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.xc")
file(GLOB_RECURSE APP_CXX_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.cpp")
file(GLOB_RECURSE APP_ASM_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "../common/src/mips/*.S")

set(APP_INCLUDES    src ../common/src/mips/)

XMOS_REGISTER_APP()
