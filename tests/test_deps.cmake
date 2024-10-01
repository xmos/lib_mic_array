# Common dependencies for test

if(NOT EXISTS ${XMOS_SANDBOX_DIR}/Unity)
    include(FetchContent)
    message(STATUS "Fetching Unity")
    FetchContent_Declare(
        Unity
        GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
        GIT_TAG        v2.5.2
        GIT_SHALLOW    TRUE
        DOWNLOAD_ONLY  TRUE
        SOURCE_DIR ${XMOS_SANDBOX_DIR}/Unity
    )
    FetchContent_Populate(Unity)
endif()

set(UNITY_C_SRCS    ${XMOS_SANDBOX_DIR}/Unity/src/unity.c
                    ${XMOS_SANDBOX_DIR}/Unity/extras/fixture/src/unity_fixture.c
                    ${XMOS_SANDBOX_DIR}/Unity/extras/memory/src/unity_memory.c
)

set(UNITY_INCLUDES  ${XMOS_SANDBOX_DIR}/Unity/src
                    ${XMOS_SANDBOX_DIR}/Unity/extras/fixture/src/
                    ${XMOS_SANDBOX_DIR}/Unity/extras/memory/src/
)

set(UNITY_FLAGS     -DUNITY_INCLUDE_CONFIG_H=1
                    -Wno-xcore-fptrgroup
)

set(APP_DEPENDENT_MODULES   "lib_mic_array")