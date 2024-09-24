if("${USING_CUSTOM_CMAKE}" STREQUAL "TRUE")
    # only do this section if using custom CMake
    ## Some of the test applications require the Unity test framework
    CPMAddPackage(
      NAME unity
      GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
      GIT_TAG        v2.5.2
      GIT_SHALLOW    TRUE
      DOWNLOAD_ONLY  TRUE
    )

    add_custom_target( tests )


    # The CMakeLists that comes with the Unity repo isn't suitable for our needs.
    add_subdirectory( ../cmake/unity ${unity_BINARY_DIR} )

    add_subdirectory( custom_cmake_build )
    # add_subdirectory( unit )
else()
    # XCommon CMake only
    cmake_minimum_required(VERSION 3.21)
    include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
    project(mic_array_tests_xccm)
    add_subdirectory(signal)
    add_subdirectory(unit)
endif()