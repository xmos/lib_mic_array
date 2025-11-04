// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "app_config.h"
#include "util/mips.h"
#include "device_pll_ctrl.h"

#include "app.h"
#include "util/audio_buffer.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

on tile[PORT_PDM_CLK_TILE_NUM] : port p_mclk = PORT_MCLK_IN_OUT;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk = PORT_PDM_CLK;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data = PORT_PDM_DATA;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a = XS1_CLKBLK_1;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b = XS1_CLKBLK_2;

unsafe{

int main() {

  chan c_tile_sync;
  chan c_audio_frames;

  par {

    on tile[0]: {
      board_dac3101_init();
      c_tile_sync <: 1;
      printf("Running " APP_NAME "..\n");
    }


    on tile[1]: {
      // Set up the media clock
      device_pll_init();

      // This ring buffer will serve as the app context.
      int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][MIC_ARRAY_CONFIG_MIC_COUNT];
      audio_ring_buffer_t app_context = abuff_init(MIC_ARRAY_CONFIG_MIC_COUNT,
                                                   AUDIO_BUFFER_SAMPLES,
                                                   &audio_buffer[0][0]);


      // Wait until tile[0] is done initializing the DAC via I2C
      unsigned ready;
      c_tile_sync :> ready;


#if (!(MIC_ARRAY_CONFIG_USE_DDR))
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(p_mclk, p_pdm_clk, p_pdm_data, 24576000, 3072000, clk_a);
#else
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(p_mclk, p_pdm_clk, p_pdm_data, 24576000, 3072000, clk_a, clk_b);
#endif

      mic_array_init(&pdm_res, null, 16000);

      // XC complains about parallel usage rules if we pass the
      // object's address directly
      void * unsafe app_ctx = &app_context;

      par {
        mic_array_start((chanend_t) c_audio_frames);

        receive_and_buffer_audio_task((chanend_t) c_audio_frames,
                                      &app_context, MIC_ARRAY_CONFIG_MIC_COUNT,
                                      MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                      MIC_ARRAY_CONFIG_MIC_COUNT * MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME);

        app_i2s_task( (void*) app_ctx );
      }
    }
  }

  return 0;
}

}
