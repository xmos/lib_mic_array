// Copyright 2022-2025 XMOS LIMITED.
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
#else
// mic array resources
on tile[PORT_PDM_CLK_TILE_NUM]: in port p_mclk =    PORT_MCLK_IN;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk =   PORT_PDM_CLK;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data =  PORT_PDM_DATA;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a =      XS1_CLKBLK_1;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b =      XS1_CLKBLK_2;
#endif

unsafe{

int main() {

  chan c_audio_frames;

  par {

    on tile[1]: {
#if USE_DEFAULT_API
#if (MIC_ARRAY_CONFIG_MIC_COUNT == 2)
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(p_mclk, p_pdm_clk, p_pdm_data, APP_MCLK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY, clk_a, clk_b);
#else
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(p_mclk, p_pdm_clk, p_pdm_data, APP_MCLK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY, clk_a);
#endif

      mic_array_init(&pdm_res, null, APP_SAMP_FREQ);
      mic_array_start((chanend_t) c_audio_frames);

#else
      app_mic_array_init();
      app_mic_array_task((chanend_t) c_audio_frames);
#endif

    }
  }

  return 0;
}

}
