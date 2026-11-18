set(LIB_NAME lib_mic_array)
set(LIB_VERSION 7.2.0)
set(LIB_DEPENDENT_MODULES "lib_xcore_math(3.0.1)")
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

if(XMOS_IS_RV)
    list(APPEND LIB_COMPILER_FLAGS -D__VX4B__)
endif()

set(LIB_OPTIONAL_HEADERS    mic_array_conf.h)

XMOS_REGISTER_MODULE()

# Custom compile and link options
if(APP_BUILD_ARCH STREQUAL "vx4b")
    foreach(target ${APP_BUILD_TARGETS})
        target_compile_options(${target} PRIVATE -ffunction-sections -fdata-sections)
        target_link_options(${target} PRIVATE -Wl,--gc-sections)
    endforeach()
endif()
