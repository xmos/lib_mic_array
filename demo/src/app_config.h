#pragma once


#define N_MICS  2

#define SAMPLES_PER_FRAME         16


#define AUDIO_BUFFER_SAMPLES       17

#define APP_AUDIO_CLOCK_FREQUENCY        24576000
#define APP_AUDIO_PIPELINE_SAMPLE_RATE   16000


#define APP_I2S_AUDIO_SAMPLE_RATE   APP_AUDIO_PIPELINE_SAMPLE_RATE

#define APP_USE_DC_OFFSET_ELIMINATION   1

#define MIC_ARRAY_CLK1  XS1_CLKBLK_1
#define MIC_ARRAY_CLK2  XS1_CLKBLK_2


// Set this to 1 to measure MIPS consumption by the mic array
// (Note: measuring MIPS will disable I2S)
#define MEASURE_MIPS                    0

// Set this to 1 to use the "basic" configuration options
#define APP_USE_BASIC_CONFIG            1

// Set this to 1 to use the ISR version of PDM rx. 0 will use the thread version.
#define APP_USE_PDM_RX_ISR              0