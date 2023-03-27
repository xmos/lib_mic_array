// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <platform.h>

#include "app.h"
#include "i2s.h"
#include "util/audio_buffer.h"

#include "app_config.h"

#include <xcore/channel_streaming.h>
#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <math.h>

#define I2S_CLKBLK    XS1_CLKBLK_3


static int i2s_mclk_bclk_ratio(
        const unsigned audio_clock_frequency,
        const unsigned sample_rate)
{
    return audio_clock_frequency / (sample_rate * (8 * sizeof(int32_t)) * I2S_CHANS_PER_FRAME);
}



I2S_CALLBACK_ATTR
void app_i2s_send(audio_ring_buffer_t* app_data,
                  size_t num_out, 
                  int32_t* samples)
{
  int32_t frame[MIC_ARRAY_CONFIG_MIC_COUNT];
  abuff_frame_get(app_data, frame);
  
  for(int c = 0; c < num_out; c++){
    int32_t samp = frame[(MIC_ARRAY_CONFIG_MIC_COUNT==1)?0:c];
    samples[c] = samp;
  }
}



I2S_CALLBACK_ATTR
static 
void app_i2s_init(audio_ring_buffer_t* app_data, 
                  i2s_config_t* config)
{
  config->mode = I2S_MODE_I2S;
  config->mclk_bclk_ratio =  i2s_mclk_bclk_ratio(MIC_ARRAY_CONFIG_MCLK_FREQ, 
                                                 APP_I2S_AUDIO_SAMPLE_RATE);
}




I2S_CALLBACK_ATTR
static 
i2s_restart_t app_i2s_restart(audio_ring_buffer_t* app_data)
{
  static unsigned do_restart = 0;
  i2s_restart_t res = do_restart? I2S_RESTART : I2S_NO_RESTART;
  do_restart = 0;
  return res;
}





I2S_CALLBACK_ATTR
static
void app_i2s_receive(audio_ring_buffer_t* app_data, 
                     size_t num_in, 
                     const int32_t* samples)
{
  
}



i2s_callback_group_t i2s_context = {
  .init = (i2s_init_t) app_i2s_init,
  .restart_check = (i2s_restart_check_t) app_i2s_restart,
  .receive = (i2s_receive_t) app_i2s_receive,
  .send = (i2s_send_t) app_i2s_send,
  .app_data = NULL,
};



void app_i2s_task( void* app_context )
{
  i2s_context.app_data = app_context;

  port_t p_i2s_dout[] = { I2S_DATA_IN };
  // port_t p_i2s_din[]  = { I2S_DATA_IN };
  port_t p_i2s_din[0];

  i2s_master(&i2s_context, 
             p_i2s_dout, 1,
             p_i2s_din,  0,
             PORT_I2S_BCLK, 
             PORT_I2S_LRCLK, 
             PORT_MCLK_IN_OUT,
             I2S_CLKBLK);
}
