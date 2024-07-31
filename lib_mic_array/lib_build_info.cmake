set(LIB_NAME lib_mic_array)
set(LIB_VERSION 5.3.0)
set(LIB_DEPENDENT_MODULES "lib_xcore_math(2.2.0)")
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

XMOS_REGISTER_MODULE()
