# This file provides overrides to the Doxyfile configuration

PROJECT_NAME           = lib_mic_array
PROJECT_BRIEF          = "PDM microphone array library"

INPUT                  = ../lib_mic_array/api ../lib_mic_array/src ../doc/rst/src

PREDEFINED             = MA_C_API= C_API_START= C_API_END= __DOXYGEN__=1
