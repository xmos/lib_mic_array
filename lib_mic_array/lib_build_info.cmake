set(LIB_NAME lib_mic_array)
set(LIB_VERSION 5.2.0)
set(LIB_DEPENDENT_MODULES "lib_xcore_math")
set(LIB_INCLUDES api src src/etc)
set(LIB_COMPILER_FLAGS -g -Os)

XMOS_REGISTER_MODULE()
