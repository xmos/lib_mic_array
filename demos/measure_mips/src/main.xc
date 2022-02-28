
#include "app_config.h"
#include "util/mips.h"
#include "app_pll_ctrl.h"
#include "mic_array/frame_transfer.h"

#include "app.h"
#include "app_common.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>



unsafe{


// MCLK connected to pin 14 --> X1D11 --> port 1D
// MIC_CLK connected to pin 39 --> X1D22 --> port 1G
// MIC_DATA connected to pin 32 --> X1D13 --> port 1F
on tile[1]: in port p_mclk                     = XS1_PORT_1D;
on tile[1]: out port p_pdm_clk                 = XS1_PORT_1G;
on tile[1]: in buffered port:32 p_pdm_mics     = XS1_PORT_1F;



int main() {

  // This is how c_audio_frames.end_b is communicated to tile[0].
  // chan c_intertile;
  chan c_audio_intertile;
  
  par {

    on tile[0]: {
      xscope_config_io(XSCOPE_IO_BASIC);
      printf("Running " APP_NAME "..\n");

      // chanend_t c_audio_in;
      // c_intertile :> c_audio_in;
      // printf("c_audio_in: 0x%08X\n", c_audio_in);

      eat_audio_frames_task((chanend_t) c_audio_intertile, 
                            N_MICS*SAMPLES_PER_FRAME);
    }


    on tile[1]: {

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);
      
      pdm_rx_resources_t pdm_res = 
#if (APP_USE_DDR)
          // @todo: Should I rename these to be lower-case?
          pdm_rx_resources_ddr((port_t) p_mclk, 
                               (port_t) p_pdm_clk, 
                               (port_t) p_pdm_mics, 
                               (clock_t) MIC_ARRAY_CLK1, 
                               (clock_t) MIC_ARRAY_CLK2);
#else
          pdm_rx_resources_sdr((port_t) p_mclk, 
                               (port_t) p_pdm_clk, 
                               (port_t) p_pdm_mics, 
                               (clock_t) MIC_ARRAY_CLK1);
#endif
      
      // Channel for communicating between pdm_rx and decimator
      streaming_channel_t c_pdm_data = app_s_chan_alloc();
      assert(c_pdm_data.end_a != 0 && c_pdm_data.end_b != 0);

      // Channel for sending audio frames to tile 0
      // channel_t c_audio_frames = app_chan_alloc();
      // assert(c_audio_frames.end_a != 0 && c_audio_frames.end_b != 0);

      // printf("end_a: 0x%08X\n", c_audio_frames.end_a);
      // printf("end_b: 0x%08X\n", c_audio_frames.end_b);

      // c_intertile <: c_audio_frames.end_b;

      // Set up the media clocks
      app_pll_init();
         
      // Set up our clocks and ports
      const unsigned mclk_div = mic_array_mclk_divider(
          APP_AUDIO_CLOCK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY);
      mic_array_setup(&pdm_res, mclk_div);
      
      // Initialize the mic array
      app_init((port_t) p_pdm_mics, c_pdm_data);


      // Start the PDM clock
      mic_array_start(&pdm_res);

      par {
#if (!APP_USE_PDM_RX_ISR)
        app_pdm_rx_task();
#endif

        app_decimator_task((chanend_t) c_audio_intertile);

        // The burn_mips() and the count_mips() should all consume as many MIPS as they're offered. And
        // they should all get the SAME number of MIPS.
        // print_mips() uses almost no MIPS -- we can assume it's zero.
        // So, with 600 MIPS total, 6 cores using X MIPS, 1 core using none and the mic array using Y MIPS...
        //  600 = 6*X + Y  -->  Y = 600 - 6*X

// If we're using the ISR we'll use 5 burn_mips(). Otherwise just 4. Either way the printed MIPS will
// be all the mic array work.
#if APP_USE_PDM_RX_ISR
        burn_mips();
#endif

        burn_mips();
        burn_mips();
        burn_mips();
        burn_mips();
        count_mips();
        print_mips(APP_USE_PDM_RX_ISR);
      }
    }
  }

  return 0;
}

}
