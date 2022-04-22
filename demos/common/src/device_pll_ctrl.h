// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array/api.h"

C_API_START


#define DEVICE_PLL_CTL_VAL   0x0A019803 // Valid for all fractional values
#define DEVICE_PLL_FRAC_NOM  0x800095F9 // 24.576000 MHz

MA_C_API
void device_pll_init(void);

C_API_END