cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(tests_signal_pdmrx_isr)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../../../examples/deps.cmake)

set(APP_HW_TARGET       XK-EVK-XU316)

set(APP_COMPILER_FLAGS  -O3
                        -g
                        -report
                        -DXASSERT_ENABLE_ASSERTIONS=1
                        -DXASSERT_ENABLE_DEBUG=1
                        -DXASSERT_ENABLE_LINE_NUMBERS=1)

XMOS_REGISTER_APP()

