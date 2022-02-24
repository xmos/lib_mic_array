
#include "app_config.h"
#include "util/mips.h"
#include "app_pll_ctrl.h"

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

  chan c_tile_sync;
  chan c_audio_frames;
  
  par {

    on tile[0]: {
      xscope_config_io(XSCOPE_IO_BASIC);
      app_dac3101_init();
      c_tile_sync <: 1;
      printf("Running " APP_NAME "..\n");
    }


    on tile[1]: {
      
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
      

      streaming_channel_t c_pdm_data = app_s_chan_alloc();
      assert(c_pdm_data.end_a != 0 && c_pdm_data.end_b != 0);

      // Force it to use xscope, never mind and config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);

      // This will buffer output audio for when I2S needs it.
      int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][N_MICS];
      audio_ring_buffer_t output_audio_buffer = 
            abuff_init(N_MICS, AUDIO_BUFFER_SAMPLES, &audio_buffer[0][0]);
      
      // Initialize the decimator context
      app_context_init((port_t) p_pdm_mics, c_pdm_data.end_b);

      // Set up the media clock
      app_pll_init();
      
      // Set up our clocks and ports
      const unsigned mclk_div = mic_array_mclk_divider(
          APP_AUDIO_CLOCK_FREQUENCY, APP_PDM_CLOCK_FREQUENCY);
      mic_array_setup(&pdm_res, mclk_div);
      
      // Wait until tile[0] is done initializing the DAC via I2C
      unsigned ready;
      c_tile_sync :> ready;

      // Start the PDM clock
      mic_array_start(&pdm_res);

      // XC complains about parallel usage rules if we pass the 
      // buffer's address directly
      void * unsafe oab = &output_audio_buffer;

      par {
        app_decimator_task((port_t) p_pdm_mics, 
                           c_pdm_data, 
                           (chanend_t) c_audio_frames);

#if (!APP_USE_PDM_RX_ISR)
        app_pdm_rx_task((port_t) p_pdm_mics, 
                        c_pdm_data.end_a);
#endif
        app_i2s_task( (void*) oab );

        receive_and_buffer_audio_task( (chanend_t) c_audio_frames,
                                       &output_audio_buffer,
                                       N_MICS, SAMPLES_PER_FRAME,
                                       N_MICS * SAMPLES_PER_FRAME );
      }
    }
  }

  return 0;
}

}
