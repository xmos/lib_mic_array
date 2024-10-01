#Fetch I2S and I2C from fwk_io
set(XMOS_DEP_DIR_i2s ${XMOS_SANDBOX_DIR}/fwk_io/modules)
set(XMOS_DEP_DIR_i2c ${XMOS_SANDBOX_DIR}/fwk_io/modules)
if(NOT EXISTS ${XMOS_SANDBOX_DIR}/fwk_io)
    include(FetchContent)
    message(STATUS "Fetching fwk_io")
    FetchContent_Declare(
        fwk_io
        GIT_REPOSITORY git@github.com:xmos/fwk_io
        GIT_TAG feature/xcommon_cmake
        SOURCE_DIR ${XMOS_SANDBOX_DIR}/fwk_io
    )
    FetchContent_Populate(fwk_io)
endif()

set(APP_DEPENDENT_MODULES   "lib_mic_array"
                            "i2s"
                            "i2c")