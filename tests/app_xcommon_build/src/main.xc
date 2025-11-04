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
#include "mic_array.h"

/////////////////////////////////////////////////////////////////////////////
//  WARNING: This is just a test app to make sure the library's
//           module_build_info is correct. This app doesn't actually do
//           anything at the moment.
/////////////////////////////////////////////////////////////////////////////
on tile[PORT_PDM_CLK_TILE_NUM] : port p_mclk = PORT_MCLK_IN_OUT;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk = PORT_PDM_CLK;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data = PORT_PDM_DATA;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a = XS1_CLKBLK_1;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b = XS1_CLKBLK_2;

unsafe{

int main() {
  chan c_audio_frames;
  par {
    on tile[0]: {
      xscope_config_io(XSCOPE_IO_BASIC);
    }
    on tile[1]: {
      xscope_config_io(XSCOPE_IO_BASIC);
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(p_mclk, p_pdm_clk, p_pdm_data, 24576000, 3072000, clk_a, clk_b);
      mic_array_init(&pdm_res, null, 16000);
      par {  mic_array_start((chanend_t) c_audio_frames);   }
    }
  }

  return 0;
}

}
