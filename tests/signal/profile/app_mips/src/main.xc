// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "app_config.h"
#include "mips.h"
#include "mic_array.h"
extern "C" {
#include "sw_pll.h"
}

// mic array resources
on tile[PORT_PDM_CLK_TILE_NUM]: in port p_mclk =    PORT_MCLK_IN;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_clk =   PORT_PDM_CLK;
on tile[PORT_PDM_CLK_TILE_NUM] : port p_pdm_data =  PORT_PDM_DATA;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_a =      XS1_CLKBLK_1;
on tile[PORT_PDM_CLK_TILE_NUM] : clock clk_b =      XS1_CLKBLK_2;

unsafe{

static void eat_audio_frames_task(
    chanend c_from_decimator,
    static const unsigned channel_count,
    static const unsigned sample_count
    )
{
  int32_t audio_frame[MIC_ARRAY_CONFIG_MIC_IN_COUNT * MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME];
  timer t;
  unsigned long now;
  t :> now;

  while(1){
    select {
      case t when timerafter(now + (XS1_TIMER_HZ*5)) :> now: // run for 5s
        return;
        break;
      default:
        ma_frame_rx(audio_frame, (chanend_t)c_from_decimator, channel_count, sample_count);
        break;
    }
  }
}


int main() {

  chan c_audio_frames;

  par {

    on tile[0]: {
      printf("Running " APP_NAME "..\n");
      eat_audio_frames_task(c_audio_frames,
                            MIC_ARRAY_CONFIG_MIC_IN_COUNT, MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME);
      exit(0);
    }


    on tile[1]: {
      // Set up the media clocks
      sw_pll_fixed_clock(APP_MCLK_FREQUENCY);

#if (MIC_ARRAY_CONFIG_MIC_COUNT == 2)
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_DDR(p_mclk, p_pdm_clk, p_pdm_data, APP_MCLK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY, clk_a, clk_b);
#else
      pdm_rx_resources_t pdm_res = PDM_RX_RESOURCES_SDR(p_mclk, p_pdm_clk, p_pdm_data, APP_MCLK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY, clk_a);
#endif

      // Initialize the mic array
      mic_array_init(&pdm_res, null, APP_SAMP_FREQ);

      par {
        mic_array_start((chanend_t) c_audio_frames);

        // The burn_mips() and the count_mips() should all consume as many MIPS as they're offered. And
        // they should all get the SAME number of MIPS.
        // print_mips() uses almost no MIPS -- we can assume it's zero.
        // So, with 600 MIPS total, 6 cores using X MIPS, 1 core using none and the mic array using Y MIPS...
        //  600 = 6*X + Y  -->  Y = 600 - 6*X

// If we're using the ISR we'll use 5 burn_mips(). Otherwise just 4. Either way the printed MIPS will
// be all the mic array work.
#if MIC_ARRAY_CONFIG_USE_PDM_ISR
        burn_mips();
#endif

        burn_mips();
        burn_mips();
        burn_mips();
        burn_mips();
        count_mips();
        print_mips(MIC_ARRAY_CONFIG_USE_PDM_ISR);
      }
    }
  }

  return 0;
}

}
