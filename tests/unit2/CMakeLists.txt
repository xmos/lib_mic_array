cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)

project(tests-unit)
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

set(APP_HW_TARGET           XK-EVK-XU416)
set(APP_INCLUDES src)
set(APP_DEPENDENT_MODULES "lib_mic_array" "lib_unity(2.5.2)")
set(APP_COMPILER_FLAGS              -Os
                                    -g
                                    -fxscope)

set(APP_BUILD_ARCH xs3a)
XMOS_REGISTER_APP()
