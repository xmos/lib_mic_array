cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(demo_vanilla)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../deps.cmake)
set(APP_HW_TARGET           XVF3610_Q60A.xn)

foreach( N_MICS  1 2 )
    set(CONFIG ${N_MICS}_MIC)
    set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                        -g
                                        -report
                                        -mcmodel=large
                                        -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                        -DMIC_ARRAY_CONFIG_MCLK_FREQ=24576000
                                        -DMIC_ARRAY_CONFIG_PDM_FREQ=3072000
                                        -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=16
                                        -DMIC_ARRAY_CONFIG_USE_DDR=1
                                        -DAPP_NAME="VANILLA_${CONFIG}")
endforeach()

# Manually set sources as we take from the common directory too
file(GLOB_RECURSE APP_C_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.c" "../common/src/*.c")
file(GLOB_RECURSE APP_XC_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.xc" "../common/src/*.xc")
file(GLOB_RECURSE APP_ASM_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR} "../common/src/*.S")

set(APP_INCLUDES    src ../common/src ../common/util)

XMOS_REGISTER_APP()
