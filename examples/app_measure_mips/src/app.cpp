// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <iostream>
#include <cstdio>
#include <xcore/channel_streaming.h>

#include "app.h"
#include <platform.h>

#include "mic_array.h"

#define DCOE_ENABLED    true


#if (MIC_ARRAY_CONFIG_MIC_IN_COUNT != 2)
pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(
                                PORT_MCLK_IN_OUT,
                                PORT_PDM_CLK,
                                PORT_PDM_DATA,
                                APP_AUDIO_CLOCK_FREQUENCY,
                                APP_PDM_CLOCK_FREQUENCY,
                                MIC_ARRAY_CLK1);
#else
pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
                                PORT_MCLK_IN_OUT,
                                PORT_PDM_CLK,
                                PORT_PDM_DATA,
                                APP_AUDIO_CLOCK_FREQUENCY,
                                APP_PDM_CLOCK_FREQUENCY,
                                MIC_ARRAY_CLK1,
                                MIC_ARRAY_CLK2);
#endif

MA_C_API
void app_init()
{
  mic_array_init(&pdm_res, NULL, APP_I2S_AUDIO_SAMPLE_RATE);
}

MA_C_API
void app_start(chanend_t c_frames_out) {
  mic_array_start(c_frames_out);
}


