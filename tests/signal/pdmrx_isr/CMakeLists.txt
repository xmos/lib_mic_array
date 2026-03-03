cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(tests_signal_pdmrx_isr)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../..)

set(APP_DEPENDENT_MODULES   "lib_mic_array")
set(APP_COMPILER_FLAGS  -Os
                        -g
                        -report
                        -DLIBXCORE_XASSERT_IS_ASSERT
                        -DMIC_ARRAY_CONFIG_USE_PDM_ISR=1
                        )

if(CMAKE_C_COMPILER_VERSION VERSION_EQUAL "3.6.0") # XS3 (XTC 15.3.1)
set(APP_HW_TARGET       XK-EVK-XU316)
else() # VX4
set(APP_HW_TARGET       XK-EVK-XU416)
endif()

XMOS_REGISTER_APP()
