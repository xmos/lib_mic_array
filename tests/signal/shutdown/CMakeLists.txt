cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(tests_signal_shutdown)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../../../examples/deps.cmake)

set(APP_HW_TARGET       XK-EVK-XU316)

set(COMPILER_FLAGS_COMMON   -O3
                            -g
                            -report
                            -mcmodel=large
                            -fxscope
                            )

set(APP_COMPILER_FLAGS_pdmrx_isr  ${COMPILER_FLAGS_COMMON}
                                   -DMIC_ARRAY_CONFIG_USE_PDM_ISR=1
                                )

set(APP_COMPILER_FLAGS_pdmrx_thread  ${COMPILER_FLAGS_COMMON}
                                      -DMIC_ARRAY_CONFIG_USE_PDM_ISR=0
                                )

XMOS_REGISTER_APP()
