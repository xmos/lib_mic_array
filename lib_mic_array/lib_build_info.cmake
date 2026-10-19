set(LIB_NAME lib_mic_array)
set(LIB_VERSION 7.1.0)
set(LIB_DEPENDENT_MODULES "lib_xcore_math(3.0.0)")
set(LIB_INCLUDES
    api
    api/mic_array
    api/mic_array/cpp
    api/mic_array/etc
    api/mic_array/impl
    src
    src/etc
)
set(LIB_COMPILER_FLAGS -g -Os)

set(LIB_OPTIONAL_HEADERS    mic_array_conf.h)

XMOS_REGISTER_MODULE()

# Apply consistently to both the transitional and new VX4 toolchains.
if(APP_BUILD_ARCH STREQUAL "vx4b")
    foreach(target ${APP_BUILD_TARGETS})
        target_compile_options(${target} PRIVATE
            -D__VX4B__
            -fno-function-sections
            -fno-data-sections
        )
        target_link_options(${target} INTERFACE -Wl,--no-gc-sections)
    endforeach()
endif()
