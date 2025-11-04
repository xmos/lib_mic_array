cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_prefab)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../deps.cmake)
set(APP_HW_TARGET           XVF3610_Q60A.xn)

set(NAME_MAP thread;isr)
foreach(N_MICS  1 2)
    foreach(USE_ISR   1 0)
        list(GET NAME_MAP ${USE_ISR} tmp)
        set(CONFIG "${N_MICS}mic_${tmp}")

        set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                            -g
                                            -report
                                            -mcmodel=large
                                            -DAPP_NAME="DEMO_${CONFIG}"
                                            -DAPP_USE_PDM_RX_ISR=${USE_ISR}
                                            -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                            -DN_MICS=${N_MICS})
    endforeach()
endforeach()

# Manually set sources as we take from the common directory too
file(GLOB_RECURSE APP_C_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.c" "../common/src/*.c")
file(GLOB_RECURSE APP_XC_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.xc" "../common/src/*.xc")
file(GLOB_RECURSE APP_CXX_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.cpp")
file(GLOB_RECURSE APP_ASM_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "../common/src/*.S")

set(APP_INCLUDES    src ../common/src ../common/util)

XMOS_REGISTER_APP()
