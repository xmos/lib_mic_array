cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(tests-signal-basicmicarray)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../../../examples/deps.cmake)

set(APP_HW_TARGET       XVF3610_Q60A.xn)

foreach(N_MICS  1 2 4 8)
    foreach(USE_ISR   1 0)
        foreach(FRAME_SIZE   1 16)
            set(CONFIG "${N_MICS}ch_${FRAME_SIZE}smp_${USE_ISR}isr")
            message(${CONFIG})
            set(APP_COMPILER_FLAGS_${CONFIG}    -O2
                                                -g
                                                -report
                                                -mcmodel=large
                                                -Wno-xcore-fptrgroup
                                                -Wno-unknown-pragmas
                                                -Wno-format
                                                -DCHAN_COUNT=${N_MICS}
                                                -DSAMPLES_PER_FRAME=${FRAME_SIZE}
                                                -DUSE_ISR=${USE_ISR}
                                                )
        endforeach()
    endforeach()
endforeach()

XMOS_REGISTER_APP()

