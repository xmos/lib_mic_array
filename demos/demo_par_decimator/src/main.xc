// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "app_config.h"
#include "util/mips.h"
#include "device_pll_ctrl.h"

#include "app.h"
#include "util/audio_buffer.h"

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

unsafe{ // We are sharing memory so use unsafe globally to remove XC compiler checks

int main() {

  chan c_tile_sync;
  chan c_audio_frames;

  par {

    on tile[0]: {
      xscope_config_io(XSCOPE_IO_BASIC);

#if (MIC_ARRAY_TILE == 0 || USE_BUTTONS)
      app_context_t app_context;
      app_context.c_intertile = (chanend_t)c_tile_sync;
#endif
#if (MIC_ARRAY_TILE == 0)
      int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][MIC_ARRAY_CONFIG_MIC_COUNT];
      app_context.rb = abuff_init(MIC_ARRAY_CONFIG_MIC_COUNT,
                                  AUDIO_BUFFER_SAMPLES,
                                  &audio_buffer[0][0]);
#endif

      // Wait for DAC CODEC to be pulled out of reset and
      // PLL to initialize on Tile[1]
      unsigned ready;
      c_tile_sync :> ready;

      aic3204_board_init();

      // Signal that the DAC has been initialized.
      c_tile_sync <: 1;

#if (MIC_ARRAY_TILE == 0)
      app_mic_array_init();
#endif

#if (MIC_ARRAY_TILE == 0 || USE_BUTTONS)
      // XC complains about parallel usage rules if we pass the
      // object's address directly
      void * unsafe app_ctx = &app_context;
#endif

      printf("Running " APP_NAME "..\n");

      par {
#if (MIC_ARRAY_TILE == 0)
        app_mic_array_task((chanend_t) c_audio_frames);

        receive_and_buffer_audio_task((chanend_t) c_audio_frames,
                                      &app_context.rb, MIC_ARRAY_CONFIG_MIC_COUNT,
                                      MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                      MIC_ARRAY_CONFIG_MIC_COUNT * MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME);

        app_i2s_task0((void*) app_ctx);
#if (USE_BUTTONS)
        app_buttons_task();
#endif

#else // (MIC_ARRAY_TILE == 0)
#if (USE_BUTTONS)
      app_buttons_task((void*) app_ctx);
#endif
#endif // (MIC_ARRAY_TILE == 0)

#if ENABLE_BURN_MIPS
#if (MIC_ARRAY_TILE == 0)
      burn_mips();
#if NUM_DECIMATOR_SUBTASKS <= 3
      burn_mips();
#endif
#if NUM_DECIMATOR_SUBTASKS <= 2
      // Enabling this == "loud noises" when NUM_DECIMATOR_SUBTASKS == 2
      // burn_mips();
#endif
#if NUM_DECIMATOR_SUBTASKS <= 1
      burn_mips();
#endif
#else // (MIC_ARRAY_TILE == 0)
      burn_mips();
      burn_mips();
      burn_mips();
      burn_mips();
      burn_mips();
      burn_mips();
      burn_mips();
#endif // (MIC_ARRAY_TILE == 0)
#endif // ENABLE_BURN_MIPS
      }
    }

    on tile[1]: {
      // Force it to use xscope, never mind any config.xscope files
      xscope_config_io(XSCOPE_IO_BASIC);

      // Pull DAC CODEC out of reset
      aic3204_codec_reset();

      // Set up the media clock
      device_pll_init();

      // Signal that DAC has been released from reset and PLL initialization is done.
      c_tile_sync <: 1;

      app_context_t app_context;

#if (MIC_ARRAY_TILE == 1)
      // This ring buffer will serve as the app context.
      int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][MIC_ARRAY_CONFIG_MIC_COUNT];
      app_context.rb = abuff_init(MIC_ARRAY_CONFIG_MIC_COUNT,
                                  AUDIO_BUFFER_SAMPLES,
                                  &audio_buffer[0][0]);

      // Wait until tile[0] is done initializing the DAC via I2C
      unsigned ready;
      c_tile_sync :> ready;

      app_mic_array_init();
#else
      unsigned ready;
      c_tile_sync :> ready;
#endif
#if (MIC_ARRAY_TILE == 0 || USE_BUTTONS)
      app_context.c_intertile = (chanend_t)c_tile_sync;
#endif

      // XC complains about parallel usage rules if we pass the
      // object's address directly
      void * unsafe app_ctx = &app_context;

      par {
#if (MIC_ARRAY_TILE == 1)
        app_mic_array_task((chanend_t) c_audio_frames);

        receive_and_buffer_audio_task((chanend_t) c_audio_frames,
                                      &app_context.rb, MIC_ARRAY_CONFIG_MIC_COUNT,
                                      MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME,
                                      MIC_ARRAY_CONFIG_MIC_COUNT * MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME);
#endif
        app_i2s_task((void*) app_ctx);

#if ENABLE_BURN_MIPS
#if (MIC_ARRAY_TILE == 1)
      burn_mips();
      burn_mips();
#if NUM_DECIMATOR_SUBTASKS <= 3
      burn_mips();
#endif
#if NUM_DECIMATOR_SUBTASKS <= 2
      burn_mips();
#endif
#if NUM_DECIMATOR_SUBTASKS <= 1
      burn_mips();
#endif
#else // (MIC_ARRAY_TILE == 1)
      burn_mips();
      burn_mips();
      burn_mips();
      burn_mips();
      burn_mips();
      burn_mips();
      burn_mips();
#endif // (MIC_ARRAY_TILE == 1)
#endif // ENABLE_BURN_MIPS
      }
    }
  }

  return 0;
}

}
