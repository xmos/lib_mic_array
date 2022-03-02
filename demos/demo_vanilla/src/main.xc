
#include "app_config.h"
#include "util/mips.h"
#include "app_pll_ctrl.h"

#include "app.h"
#include "mic_array_vanilla.h"
#include "util/audio_buffer.h"

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
      xscope_config_io(XSCOPE_IO_BASIC);

      pdm_rx_resources_t pdm_res = pdm_rx_resources_ddr((port_t) p_mclk, 
                                                        (port_t) p_pdm_clk, 
                                                        (port_t) p_pdm_mics, 
                                                        (clock_t) MIC_ARRAY_CLK1, 
                                                        (clock_t) MIC_ARRAY_CLK2);
      
      // This makes it do SDR if we're only doing 1 mic
      if( MIC_ARRAY_CONFIG_MIC_COUNT == 1 )
        pdm_res.clock_b = 0;

      // Set up the media clock
      app_pll_init();

      // This ring buffer will serve as the app context.
      int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][MIC_ARRAY_CONFIG_MIC_COUNT];
      audio_ring_buffer_t app_context = abuff_init(MIC_ARRAY_CONFIG_MIC_COUNT,
                                                   AUDIO_BUFFER_SAMPLES,
                                                   &audio_buffer[0][0]);


      // Wait until tile[0] is done initializing the DAC via I2C
      unsigned ready;
      c_tile_sync :> ready;

      ma_vanilla_init(&pdm_res);

      // XC complains about parallel usage rules if we pass the 
      // object's address directly
      void * unsafe app_ctx = &app_context;

      par {
        ma_vanilla_task(&pdm_res, (chanend_t) c_audio_frames);

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
