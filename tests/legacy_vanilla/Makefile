# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling.

TARGET = XVF3610_Q60A.xn

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name

APP_NAME = legacy_build_vanilla

VANILLA_API_ENABLED=1

SOURCE_DIRS = src


# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
#
#    XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
#
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.

XCC_FLAGS = -fxscope -g -mcmodel=large  					\
						-report -Os 													\
						-DMIC_ARRAY_CONFIG_MCLK_FREQ=24576000 \
						-DMIC_ARRAY_CONFIG_PDM_FREQ=3072000 	\
						-DMIC_ARRAY_CONFIG_MIC_COUNT=2				\
						-DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=16 

XCC_CPP_FLAGS = $(XCC_FLAGS) -std=c++11

# The USED_MODULES variable lists other module used by the application.

USED_MODULES = lib_mic_array

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common