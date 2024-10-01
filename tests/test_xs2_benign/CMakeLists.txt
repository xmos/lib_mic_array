cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(xs2)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_DEPENDENT_MODULES   "lib_mic_array")
set(APP_HW_TARGET           XCORE-200-EXPLORER)
set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                    -g
                                    -report
                                    -mcmodel=large)

XMOS_REGISTER_APP()
