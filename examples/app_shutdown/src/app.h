// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"

/**
 * @brief
 */
C_API_START

MA_C_API
void app_i2s_task( chanend_t c_from_mic_array, chanend_t c_sync, chanend_t c_i2c );

MA_C_API
void app_mic(chanend_t c_frames_out);

MA_C_API
void button_task(chanend_t c_sync);

C_API_END
