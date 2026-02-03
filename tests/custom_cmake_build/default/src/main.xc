// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include "mic_array.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#define MIC_COUNT   MIC_ARRAY_CONFIG_MIC_COUNT
#define FRAME_SIZE  MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME

on tile[PORT_PDM_CLK_TILE_NUM] : port p_mclk = PORT_MCLK_IN;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk = PORT_PDM_CLK;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data = PORT_PDM_DATA;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a = XS1_CLKBLK_1;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b = XS1_CLKBLK_2;

unsafe {

// Consumes audio to prevent mic array from backing up.
void eat_frames(chanend c_frames_in)
{
  int32_t frame_buff[MIC_COUNT][FRAME_SIZE];
  unsigned frame_count = 0;

  while(1){
    ma_frame_rx(&frame_buff[0][0], (chanend_t)c_frames_in,
                MIC_COUNT, FRAME_SIZE);
    if(frame_count % 1 == 0)
      printf("Frame count: %u\n", frame_count);
    frame_count++;
  }
}


#define DEVICE_PLL_CTL_VAL   0x0A019803 // Valid for all
                                        // fractional values
#define DEVICE_PLL_FRAC_NOM  0x800095F9 // 24.576000 MHz

void device_pll_init()
{
    unsigned tileid = get_local_tile_id();

    const unsigned DEVICE_PLL_DISABLE = 0x0201FF04;
    const unsigned DEVICE_PLL_DIV_0   = 0x80000004;

    write_sswitch_reg(tileid, XS1_SSWITCH_SS_APP_PLL_CTL_NUM,
                              DEVICE_PLL_DISABLE);

    delay_milliseconds(1);

    write_sswitch_reg(tileid,
                      XS1_SSWITCH_SS_APP_PLL_CTL_NUM,
                      DEVICE_PLL_CTL_VAL);
    write_sswitch_reg(tileid,
                      XS1_SSWITCH_SS_APP_PLL_CTL_NUM,
                      DEVICE_PLL_CTL_VAL);
    write_sswitch_reg(tileid,
                      XS1_SSWITCH_SS_APP_PLL_FRAC_N_DIVIDER_NUM,
                      DEVICE_PLL_FRAC_NOM);
    write_sswitch_reg(tileid,
                      XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM,
                      DEVICE_PLL_DIV_0);
}




int main() {
  par {
    on tile[1]: {
      chan c_audio_frames;

      xscope_config_io(XSCOPE_IO_BASIC);

      // Set up the media clock to 24.576 MHz
      device_pll_init();

      // Initialize mic array
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(p_mclk, p_pdm_clk, p_pdm_data, 24576000, 3072000, clk_a, clk_b);
      mic_array_init(&pdm_res, null, 16000);

      par {
        // Launch mic array thread
        mic_array_start((chanend_t) c_audio_frames);

        // Consume frames
        eat_frames(c_audio_frames);
      }
    }
  }

  return 0;
}

}
