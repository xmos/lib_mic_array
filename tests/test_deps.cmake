# Common dependencies for test

if(NOT EXISTS ${XMOS_SANDBOX_DIR}/Unity)
    include(FetchContent)
    message(STATUS "Fetching Unity")
    FetchContent_Declare(
        Unity
        GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
        # GIT_TAG feature/xcommon_cmake
        SOURCE_DIR ${XMOS_SANDBOX_DIR}/Unity
    )
    FetchContent_Populate(Unity)
endif()

CPMAddPackage(
  NAME unity
  GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
  GIT_TAG        v2.5.2
  GIT_SHALLOW    TRUE
  DOWNLOAD_ONLY  TRUE
)