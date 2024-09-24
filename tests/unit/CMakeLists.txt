cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(tests-unit )
set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../test_deps.cmake)
set(APP_HW_TARGET           XVF3610_Q60A.xn)


set(APP_COMPILER_FLAGS_${CONFIG}    -O2
                                    -g
                                    -report
                                    -mcmodel=large
                                    -fcmdline-buffer-bytes=1024
                                    -Wno-xcore-fptrgroup
                                    -Wno-unknown-pragmas
                                    -Wno-format)

XMOS_REGISTER_APP()



# target_link_libraries( ${APP_NAME}
#   lib_xcore_math
#   lib_mic_array
#   unity )

