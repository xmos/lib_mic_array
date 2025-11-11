// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <print.h>
#include <platform.h>
#include <xcore/channel_streaming.h>
#include <xcore/select.h>

#include "app.h"
#include "i2s.h"
#include "app_config.h"
#include "xk_voice_l71/board.h"

#define I2S_CLKBLK    XS1_CLKBLK_3

typedef struct {
  chanend_t c_from_mic_array;
  chanend_t c_button_sync;
  chanend_t c_i2c;
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
void app_i2s_init(ma_interface_t* app_data,
                  i2s_config_t* config)
{
  static unsigned available_sample_rates[2] = {16000, 48000}; // dac3101_configure() in lib_board_support, xk_voice_l71.xc only allows these 2
  static unsigned counter = 0;
  printf("Starting at sample rate %u\n", available_sample_rates[counter]);
  static const xk_voice_l71_config_t hw_config = {
                                                CLK_FIXED,
                                                ENABLE_MCLK | ENABLE_I2S,
                                                DAC_DIN_SEC,
                                                MCLK_48
                                               };
  // Initialise dac for the required sampling freq
  xk_voice_l71_AudioHwChanInit(app_data->c_i2c);
  xk_voice_l71_AudioHwInit(&hw_config);
  xk_voice_l71_AudioHwConfig(&hw_config, available_sample_rates[counter], MCLK_48);

  chan_out_word(app_data->c_from_mic_array, available_sample_rates[counter]); // convey samp freq to app_mic()

  config->mode = I2S_MODE_I2S;
  config->mclk_bclk_ratio =  i2s_mclk_bclk_ratio(MCLK_48,
                                                 available_sample_rates[counter]);
  counter = (counter + 1) % 2;
}




I2S_CALLBACK_ATTR
static
i2s_restart_t app_i2s_restart(ma_interface_t* app_data)
{
  unsigned temp;
  SELECT_RES(CASE_THEN(app_data->c_button_sync, fs_change),
            DEFAULT_THEN(empty))
  {
      fs_change:
          temp = chan_in_word(app_data->c_button_sync);
          (void)temp;
          ma_shutdown(app_data->c_from_mic_array);
          return 1;
          break;
      empty:
          break;
  }
  return 0;
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



void app_i2s_task( chanend_t c_from_mic_array, chanend_t c_button_sync, chanend_t c_i2c)
{
  ma_interface.c_from_mic_array = c_from_mic_array;
  ma_interface.c_button_sync = c_button_sync;
  ma_interface.c_i2c = c_i2c;
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
