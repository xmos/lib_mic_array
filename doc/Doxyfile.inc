# This file provides overrides to the Doxyfile configuration

PROJECT_NAME           = lib_mic_array
PROJECT_BRIEF          = "PDM Mic Array library for the XMOS XS3 architecture"

INPUT                  = ../lib_mic_array/api ../etc/vanilla  ../doc/programming_guide/src

PREDEFINED             = MA_C_API= C_API_START= C_API_END= __DOXYGEN__=1
