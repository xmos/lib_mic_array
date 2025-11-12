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



// mic array resources
on tile[PORT_PDM_CLK_TILE_NUM]: in port p_mclk =    PORT_MCLK_IN;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk =   PORT_PDM_CLK;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data =  PORT_PDM_DATA;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a =      XS1_CLKBLK_1;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b =      XS1_CLKBLK_2;

unsafe{

int main() {
  chan c_audio_frames;
  chan c_i2c;
  chan c_button_sync;

  par {

    on tile[0]: {
      par {
        xk_voice_l71_AudioHwRemote(c_i2c); // Startup remote I2C master server task
        button_task((chanend_t)c_button_sync);
      }
    }


    on tile[1]: {
      par {
        app_mic((chanend_t) c_audio_frames);

        app_i2s_task( (chanend_t)c_audio_frames, (chanend_t)c_button_sync, (chanend_t)c_i2c );
      }
    }
  }

  return 0;
}
}
