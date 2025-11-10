cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(demo_par_decimator)
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../deps.cmake)
set(APP_HW_TARGET           XK-EVK-XU316)

foreach( N_MICS  8 16 )
    set(CONFIG ${N_MICS}_MIC)
    set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                        -g
                                        -report
                                        -mcmodel=large
                                        -DBOARD_SUPPORT_BOARD=XK_EVK_XU316
                                        -DAPP_PORT_MCLK=XS1_PORT_1D
                                        -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                        -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=16
                                        -DMIC_ARRAY_CONFIG_USE_DDR=1
                                        -DAPP_NAME="MIC_ARRAY_PAR_DECIMATOR_${CONFIG}")
endforeach()

# Manually set sources as we take from the common directory too
file(GLOB_RECURSE APP_C_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.c" "../common/src/mips/*.c")
file(GLOB_RECURSE APP_XC_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.xc")
file(GLOB_RECURSE APP_CXX_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.cpp")
file(GLOB_RECURSE APP_ASM_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR} "../common/src/mips/*.S")

set(APP_INCLUDES    src src/audio_buffer ../common/src/mips)

XMOS_REGISTER_APP()
