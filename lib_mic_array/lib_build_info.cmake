set(LIB_NAME lib_mic_array)
set(LIB_VERSION 4.5.0)
set(LIB_INCLUDES api src/fir)

# Want to exclude src/fir/make_mic_dual_stage_3_coefs.c
# There are no other C source files, so set an empty string.
set(LIB_C_SRCS "")

set(LIB_DEPENDENT_MODULES "lib_xassert"
                          "lib_logging"
                          "lib_dsp")

XMOS_REGISTER_MODULE()
