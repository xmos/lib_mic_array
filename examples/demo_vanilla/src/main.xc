// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "app_config.h"
#include "util/mips.h"
#include "device_pll_ctrl.h"

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

      ma_vanilla_init();

      // XC complains about parallel usage rules if we pass the 
      // object's address directly
      void * unsafe app_ctx = &app_context;

      par {
        ma_vanilla_task((chanend_t) c_audio_frames);

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
