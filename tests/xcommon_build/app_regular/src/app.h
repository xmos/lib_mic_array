// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"

#define SAMPLES_PER_FRAME         16
#define AUDIO_BUFFER_SAMPLES       ((unsigned) (SAMPLES_PER_FRAME * 1.2f + 4))
#define APP_AUDIO_CLOCK_FREQUENCY        24576000
#define APP_PDM_CLOCK_FREQUENCY          3072000
#define APP_AUDIO_PIPELINE_SAMPLE_RATE   16000
#define MIC_ARRAY_CLK1      XS1_CLKBLK_1
#define MIC_ARRAY_CLK2      XS1_CLKBLK_2
#define DCOE_ENABLED        true


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


C_API_END