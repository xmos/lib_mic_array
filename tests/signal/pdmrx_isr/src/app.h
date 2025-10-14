// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"

C_API_START

MA_C_API
void app_pdm_rx_isr_setup(chanend_t c_from_host);

MA_C_API
void test();

MA_C_API
void assert_when_timeout();

C_API_END


