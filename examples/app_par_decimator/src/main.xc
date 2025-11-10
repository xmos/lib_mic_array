// Copyright 2023-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <xscope.h>

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include "app_config.h"
#include "mips.h"

#include "app.h"
#include "audio_buffer.h"
#include "xk_evk_xu316/board.h"

unsafe{ // We are sharing memory so use unsafe globally to remove XC compiler checks

void AudioHwInit()
{
    xk_evk_xu316_config_t hw_config = {MCLK_48};
    xk_evk_xu316_AudioHwInit(hw_config);

    const int samFreq = APP_AUDIO_SAMPLE_RATE; /* xk_evk_xu316_AudioHwConfig doesn't like rates below 22kHz so force to 48k which works OK */
    xk_evk_xu316_AudioHwConfig(samFreq, MCLK_48, 0, 32, 32);

    return;
}

int main() {

  chan c_i2c;
  chan c_tile_sync;
  chan c_audio_frames;

  par {

    on tile[0]: {
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

      xk_evk_xu316_AudioHwRemote(c_i2c); // Startup remote I2C master server task

#if (MIC_ARRAY_TILE == 0)
      app_mic_array_init();
      app_mic_array_assertion_disable();
#endif

#if (MIC_ARRAY_TILE == 0 || USE_BUTTONS)
      // Use unsafe pointer type to avoid XC parallal usage error
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
      xk_evk_xu316_AudioHwChanInit(c_i2c);
      AudioHwInit();
      c_i2c <: AUDIOHW_CMD_EXIT; // Kill the remote config task

      app_context_t app_context;

#if (MIC_ARRAY_TILE == 1)
      // This ring buffer will serve as the app context.
      int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][MIC_ARRAY_CONFIG_MIC_COUNT];
      app_context.rb = abuff_init(MIC_ARRAY_CONFIG_MIC_COUNT,
                                  AUDIO_BUFFER_SAMPLES,
                                  &audio_buffer[0][0]);

      // Wait until tile[0] is done initializing the DAC via I2C


      app_mic_array_init();
      app_mic_array_assertion_disable();
#endif
#if (MIC_ARRAY_TILE == 0 || USE_BUTTONS)
      app_context.c_intertile = (chanend_t)c_tile_sync;
#endif

      // Use unsafe pointer type to avoid XC parallal usage error
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
