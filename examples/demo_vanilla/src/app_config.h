// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#define AUDIO_BUFFER_SAMPLES  ((unsigned)(MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME * 1.2))
#define APP_AUDIO_PIPELINE_SAMPLE_RATE   16000
#define APP_I2S_AUDIO_SAMPLE_RATE   APP_AUDIO_PIPELINE_SAMPLE_RATE
#define MIC_ARRAY_CLK1  XS1_CLKBLK_1
#define MIC_ARRAY_CLK2  XS1_CLKBLK_2
