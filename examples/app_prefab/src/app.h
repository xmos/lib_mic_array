// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"

C_API_START

/**
 * @brief Application-specific intitialization
 */
MA_C_API
void app_init();

/**
 * @brief C-compatible wrapper for PDM rx thread entry point
 */
MA_C_API
void app_pdm_rx_task();

/**
 * @brief
 */
MA_C_API
void app_decimator_task(chanend_t c_audio_frames);

MA_C_API
void app_i2s_task( chanend_t c_from_mic_array );

C_API_END
