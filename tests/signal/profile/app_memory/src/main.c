// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "app_config.h"
#include "mic_array.h"

#if !USE_DEFAULT_API
#include "app.h"
#endif

static inline void mic_array_init_1_mic(void)
{
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(
          PORT_MCLK_IN, PORT_PDM_CLK, PORT_PDM_DATA,
          APP_MCLK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY, XS1_CLKBLK_1);
      mic_array_init(&pdm_res, NULL, APP_SAMP_FREQ);
}

static inline void mic_array_init_2_mics(void)
{
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(
          PORT_MCLK_IN, PORT_PDM_CLK, PORT_PDM_DATA,
          APP_MCLK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY, XS1_CLKBLK_1, XS1_CLKBLK_2);
      mic_array_init(&pdm_res, NULL, APP_SAMP_FREQ);
}

static inline void mic_array_init_start_default(chanend_t c_audio_frames)
{
#if (MIC_ARRAY_CONFIG_MIC_COUNT == 2)
      mic_array_init_2_mics();
#elif (MIC_ARRAY_CONFIG_MIC_COUNT == 1)
      mic_array_init_1_mic();
#else
#error "Unsupported mic count configuration"
#endif
      mic_array_start(c_audio_frames);
}

static inline void mic_array_init_start_custom(chanend_t c_audio_frames)
{
      app_mic_array_init();
      app_mic_array_task(c_audio_frames);
}

static void mic_array_init_start(chanend_t c_audio_frames)
{
#if USE_DEFAULT_API
      mic_array_init_start_default(c_audio_frames);
#else
      mic_array_init_start_custom(c_audio_frames);
#endif
}

int main_tile_0(chanend_t c_audio_frames)
{
      (void)c_audio_frames;
      return 0;
}

int main_tile_1(chanend_t c_audio_frames)
{
      mic_array_init_start(c_audio_frames);
      return 0; // should never reach here
}
