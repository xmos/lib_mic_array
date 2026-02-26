// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

// #define DEVICE_PLL_CTL_VAL   0x0A019803 // Valid for all fractional values
#define DEVICE_PLL_FRAC_NOM  0x800095F9 // 24.576000 MHz

void device_pll_init(void);
