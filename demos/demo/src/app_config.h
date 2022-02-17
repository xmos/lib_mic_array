#pragma once


#ifndef N_MICS
#  error "N_MICS not defined."
#endif

#ifndef APP_USE_PDM_RX_ISR
#  error "APP_USE_PDM_RX_ISR not defined."
#endif


#define SAMPLES_PER_FRAME         16

#define AUDIO_BUFFER_SAMPLES       17

#define APP_AUDIO_CLOCK_FREQUENCY        24576000
#define APP_PDM_CLOCK_FREQUENCY          3072000
#define APP_AUDIO_PIPELINE_SAMPLE_RATE   16000


#define APP_I2S_AUDIO_SAMPLE_RATE   APP_AUDIO_PIPELINE_SAMPLE_RATE

#define APP_USE_DC_OFFSET_ELIMINATION   1

#define MIC_ARRAY_CLK1  XS1_CLKBLK_1
#define MIC_ARRAY_CLK2  XS1_CLKBLK_2


////////////////////////
// Below are macros values derived from the above
////////////////////////

#define APP_USE_DDR                     ((N_MICS)>1)