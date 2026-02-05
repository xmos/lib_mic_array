// Copyright 2022-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <platform.h>

#include "app.h"
#include "i2s.h"

#include "app_config.h"

#include <xcore/channel_streaming.h>
#include <stdint.h>
#include <stdio.h>
#include <xcore/assert.h>
#include <stdlib.h>
#include <string.h>
#include <platform.h>

#include <math.h>

#define I2S_CLKBLK    XS1_CLKBLK_3

typedef struct {
  chanend_t c_from_mic_array;
}ma_interface_t;

ma_interface_t ma_interface;

static int i2s_mclk_bclk_ratio(
        const unsigned audio_clock_frequency,
        const unsigned sample_rate)
{
    return audio_clock_frequency / (sample_rate * (8 * sizeof(int32_t)) * I2S_CHANS_PER_FRAME);
}



I2S_CALLBACK_ATTR
void app_i2s_send(ma_interface_t* app_data,
                  size_t num_out,
                  int32_t* samples)
{
  int32_t frame[MIC_ARRAY_CONFIG_MIC_COUNT];
  ma_frame_rx(frame, app_data->c_from_mic_array, MIC_ARRAY_CONFIG_MIC_COUNT, 1);

  for(int c = 0; c < num_out; c++){
    int32_t samp = frame[(MIC_ARRAY_CONFIG_MIC_COUNT==1)?0:c] << 6;
    samples[c] = samp;
  }
}



I2S_CALLBACK_ATTR
static
void app_i2s_init(void* app_data,
                  i2s_config_t* config)
{
  config->mode = I2S_MODE_I2S;
  config->mclk_bclk_ratio =  i2s_mclk_bclk_ratio(MCLK_48,
                                                 APP_I2S_AUDIO_SAMPLE_RATE);
}




I2S_CALLBACK_ATTR
static
i2s_restart_t app_i2s_restart(void* app_data)
{
  static unsigned do_restart = 0;
  i2s_restart_t res = do_restart? I2S_RESTART : I2S_NO_RESTART;
  do_restart = 0;
  return res;
}





I2S_CALLBACK_ATTR
static
void app_i2s_receive(void* app_data,
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



void app_i2s_task( chanend_t c_from_mic_array )
{
  ma_interface.c_from_mic_array = c_from_mic_array;
  i2s_context.app_data = &ma_interface;

  port_t p_i2s_dout[] = { PORT_I2S_DAC0 };
  port_t p_i2s_din[0];

  i2s_master(&i2s_context,
             p_i2s_dout, 1,
             p_i2s_din,  0,
             PORT_I2S_BCLK,
             PORT_I2S_LRCLK,
             PORT_MCLK_IN,
             I2S_CLKBLK);
}
