# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = XCORE-200-EXPLORER

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME = test_channel_ordering

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_mic_array

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
COMMON_FLAGS = -O2 -g -DTEST_MODE

#Defines to re-order channels. Effectively does a bitrev on 8bits
CHAN_RE_ORDER_TEST_8B = -DMIC_ARRAY_CH0=PIN7 -DMIC_ARRAY_CH1=PIN6 -DMIC_ARRAY_CH2=PIN5 -DMIC_ARRAY_CH3=PIN4 \
						-DMIC_ARRAY_CH4=PIN3 -DMIC_ARRAY_CH5=PIN2 -DMIC_ARRAY_CH6=PIN1 -DMIC_ARRAY_CH7=PIN0

#Defines to re-order channels. Effectively does a bitrev on each 4bit port
CHAN_RE_ORDER_TEST_4B = -DMIC_ARRAY_CH0_4BIT=PIN3_4A -DMIC_ARRAY_CH1_4BIT=PIN2_4A -DMIC_ARRAY_CH2_4BIT=PIN1_4A -DMIC_ARRAY_CH3_4BIT=PIN0_4A \
					    -DMIC_ARRAY_CH4_4BIT=PIN3_4B -DMIC_ARRAY_CH5_4BIT=PIN2_4B -DMIC_ARRAY_CH6_4BIT=PIN1_4B -DMIC_ARRAY_CH7_4BIT=PIN0_4B

XCC_FLAGS_FRONTEND_8BIT_4CH = $(COMMON_FLAGS) -DFRONTEND_8BIT_4CH -DTEST_MODE
XCC_FLAGS_FRONTEND_8BIT_8CH = $(COMMON_FLAGS) -DFRONTEND_8BIT_8CH -DTEST_MODE
XCC_FLAGS_FRONTEND_4BIT_4CH = $(COMMON_FLAGS) -DFRONTEND_4BIT_4CH -DTEST_MODE
XCC_FLAGS_FRONTEND_4BIT_8CH = $(COMMON_FLAGS) -DFRONTEND_4BIT_8CH -DTEST_MODE
XCC_FLAGS_BACKEND = $(COMMON_FLAGS) -DBACKEND
XCC_FLAGS_FRONTEND_8BIT_4CH_CHANREORDER = $(COMMON_FLAGS) -DFRONTEND_8BIT_4CH -DTEST_MODE $(CHAN_RE_ORDER_TEST_8B)
XCC_FLAGS_FRONTEND_8BIT_8CH_CHANREORDER = $(COMMON_FLAGS) -DFRONTEND_8BIT_8CH -DTEST_MODE $(CHAN_RE_ORDER_TEST_8B)
XCC_FLAGS_FRONTEND_4BIT_4CH_CHANREORDER = $(COMMON_FLAGS) -DFRONTEND_4BIT_4CH -DTEST_MODE $(CHAN_RE_ORDER_TEST_4B)
XCC_FLAGS_FRONTEND_4BIT_8CH_CHANREORDER = $(COMMON_FLAGS) -DFRONTEND_4BIT_8CH -DTEST_MODE $(CHAN_RE_ORDER_TEST_4B)

# The XCORE_ARM_PROJECT variable, if set to 1, configures this
# project to create both xCORE and ARM binaries.
XCORE_ARM_PROJECT = 0

# The VERBOSE variable, if set to 1, enables verbose output from the make system.
VERBOSE = 0

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
