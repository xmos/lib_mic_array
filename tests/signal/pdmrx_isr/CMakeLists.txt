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

# Default target
if(NOT DEFINED APP_HW_TARGET)
    set(APP_HW_TARGET XK-EVK-XU316)
endif()

# Supported targets
set(SUPPORTED_TARGETS "XK-EVK-XU316;XK-EVK-XU416")
if(NOT APP_HW_TARGET IN_LIST SUPPORTED_TARGETS)
  message(FATAL_ERROR "Unsupported target ${APP_HW_TARGET}. Supported: ${SUPPORTED_TARGETS}")
endif()

XMOS_REGISTER_APP()
