// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "app_config.h"
#include "util/mips.h"
#include "device_pll_ctrl.h"

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

int main() {

  chan c_tile_sync;
  chan c_audio_frames;
  
  par {

    on tile[0]: {
      xscope_config_io(XSCOPE_IO_BASIC);
      board_dac3101_init();
      c_tile_sync <: 1;
      printf("Running " APP_NAME "..\n");
    }


    on tile[1]: {
      // Force it to use xscope, never mind any config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);

      // This will buffer output audio for when I2S needs it.
      int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][N_MICS];
      audio_ring_buffer_t output_audio_buffer = 
            abuff_init(N_MICS, AUDIO_BUFFER_SAMPLES, &audio_buffer[0][0]);

      // Set up the media clock
      device_pll_init();
      
      // Initialize the mic array
      app_init();
      
      // Wait until tile[0] is done initializing the DAC via I2C
      unsigned ready;
      c_tile_sync :> ready;

      // XC complains about parallel usage rules if we pass the 
      // buffer's address directly
      void * unsafe oab = &output_audio_buffer;

      par {
        app_decimator_task((chanend_t) c_audio_frames);

#if (!APP_USE_PDM_RX_ISR)
        app_pdm_rx_task();
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
