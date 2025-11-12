// Copyright 2023-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#pragma once

#define APP_AUDIO_SAMPLE_RATE       48000   // Run at 48KHz since xk_evk_xu316_AudioHwConfig complains for anything below 22.05KHz
#define MIC_ARRAY_CLK1                  XS1_CLKBLK_1
#define MIC_ARRAY_CLK2                  XS1_CLKBLK_2
#define MCLK_FREQ                       (24576000)
#define PDM_FREQ                        (3072000)
#define MCLK_48                         (MCLK_FREQ)

// Indicates the number of subtasks to perform the decimation process on.
#define NUM_DECIMATOR_SUBTASKS          2
