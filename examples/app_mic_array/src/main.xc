// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "xk_voice_l71/board.h"
#include "app_config.h"
#include "mic_array.h"
#include "app.h"

static const xk_voice_l71_config_t hw_config = {
                                                CLK_FIXED,
                                                ENABLE_MCLK | ENABLE_I2S,
                                                DAC_DIN_SEC,
                                                MCLK_48
                                               };

// mic array resources
on tile[PORT_PDM_CLK_TILE_NUM]: in port p_mclk =    PORT_MCLK_IN;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk =   PORT_PDM_CLK;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data =  PORT_PDM_DATA;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a =      XS1_CLKBLK_1;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b =      XS1_CLKBLK_2;

unsafe{

void AudioHwInit()
{
    xk_voice_l71_AudioHwInit(hw_config);
    xk_voice_l71_AudioHwConfig(hw_config, APP_AUDIO_SAMPLE_RATE, MCLK_48);
    return;
}

int main() {
  chan c_audio_frames;
  chan c_i2c;

  par {

    on tile[0]: {
      xk_voice_l71_AudioHwRemote(c_i2c); // Startup remote I2C master server task
    }


    on tile[1]: {
      xk_voice_l71_AudioHwChanInit(c_i2c);
      AudioHwInit();

#if (MIC_ARRAY_CONFIG_MIC_COUNT == 2)
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(p_mclk, p_pdm_clk, p_pdm_data, MCLK_48, PDM_FREQ, clk_a, clk_b);
#else
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(p_mclk, p_pdm_clk, p_pdm_data, MCLK_48, PDM_FREQ, clk_a);
#endif

      mic_array_init(&pdm_res, null, APP_AUDIO_SAMPLE_RATE);

      par {
        mic_array_start((chanend_t) c_audio_frames);

        app_i2s_task( (chanend_t)c_audio_frames );
      }
    }
  }

  return 0;
}
}
