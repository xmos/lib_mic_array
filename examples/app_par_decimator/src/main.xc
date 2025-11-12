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

#include "app.h"
#include "xk_voice_l71/board.h"

static const xk_voice_l71_config_t hw_config = {
                                                CLK_FIXED,
                                                ENABLE_MCLK | ENABLE_I2S,
                                                DAC_DIN_SEC,
                                                MCLK_48
                                               };

unsafe{ // We are sharing memory so use unsafe globally to remove XC compiler checks

void AudioHwInit()
{
    xk_voice_l71_AudioHwInit(hw_config);
    xk_voice_l71_AudioHwConfig(hw_config, APP_AUDIO_SAMPLE_RATE, MCLK_48);
    return;
}

int main() {

  chan c_i2c;
  chan c_audio_frames;

  par {

    on tile[0]: {
      xk_voice_l71_AudioHwRemote(c_i2c); // Startup remote I2C master server task
    }

    on tile[1]: {
      printf("Running " APP_NAME "..\n");
      xk_voice_l71_AudioHwChanInit(c_i2c);
      AudioHwInit();

      app_mic_array_init();

      par {
        app_mic_array_task((chanend_t) c_audio_frames);

        app_i2s_task((chanend_t) c_audio_frames);
      }
    }
  }
  return 0;
}

}
