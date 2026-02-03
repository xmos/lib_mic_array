// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once


#define AUDIO_BUFFER_SAMPLES       ((unsigned) (MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME))
#define APP_AUDIO_SAMPLE_RATE   16000
#define APP_I2S_AUDIO_SAMPLE_RATE   APP_AUDIO_SAMPLE_RATE
#define MCLK_48                             (512 * 48000)    /* 48kHz family master clock frequency */

#define MASTER_CLOCK_FREQUENCY  MCLK_48
#define PDM_FREQ                (3072000)
#define DATA_BITS               32
#define CHANS_PER_FRAME         I2S_CHANS_PER_FRAME
#define NUM_I2S_LINES           1
