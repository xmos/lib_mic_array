cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(demo_par_decimator)
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../deps.cmake)
set(APP_HW_TARGET           XCORE-AI-EXPLORER)

foreach( N_MICS  8 16 )
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
                                        -DMIC_ARRAY_CONFIG_PORT_MCLK=XS1_PORT_1D
                                        -DMIC_ARRAY_CONFIG_PORT_PDM_CLK=XS1_PORT_1A
                                        -DMIC_ARRAY_CONFIG_PORT_PDM_DATA=XS1_PORT_4D
                                        -DPORT_I2C_SCL=XS1_PORT_1N
                                        -DPORT_I2C_SDA=XS1_PORT_1O
                                        -DAPP_NAME="PAR_DECIMATOR_${CONFIG}")
endforeach()

# Manually set sources as we take from the common directory too
file(GLOB_RECURSE APP_C_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.c" "../common/src/*.c")
file(GLOB_RECURSE APP_XC_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.xc" "../common/src/*.xc")
file(GLOB_RECURSE APP_CXX_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR}  "src/*.cpp")
file(GLOB_RECURSE APP_ASM_SRCS RELATIVE ${CMAKE_CURRENT_LIST_DIR} "../common/src/*.S")

set(APP_INCLUDES    src ../common/src ../common/util)

XMOS_REGISTER_APP()
