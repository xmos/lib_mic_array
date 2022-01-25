
#include <platform.h>

#include "app_i2s.h"
#include "i2s.h"

#include "app_config.h"
// #include "dac3101/dac3101.h"

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

typedef struct {
  uint32_t t;
  uint32_t u;
  int32_t last_pcm_frame[N_MICS];
} app_i2s_data_t;


static app_i2s_data_t app_i2s_data;




void proc_pcm_user(int32_t pcm_frame[])
{
  for(int k = 0; k < N_MICS; k++){
    app_i2s_data.last_pcm_frame[k] = pcm_frame[k] << 8;

    // int tmp = (pcm_frame[k] >= 0)? 0x10000000 : -0x10000000;
    // app_i2s_data.last_pcm_frame[k] = tmp;
  }

  app_i2s_data.t++;
}



I2S_CALLBACK_ATTR
static 
void app_i2s_init(app_i2s_data_t* app_data, 
                  i2s_config_t* config)
{
  printf("[I2S Init]\n");
  config->mode = I2S_MODE_I2S;
  config->mclk_bclk_ratio =  i2s_mclk_bclk_ratio(APP_AUDIO_CLOCK_FREQUENCY, APP_I2S_AUDIO_SAMPLE_RATE);

  app_data->t = 0;
  app_data->u = 0;
  memset(&app_data->last_pcm_frame[0], 0, sizeof(app_data->last_pcm_frame));
}

I2S_CALLBACK_ATTR
static 
i2s_restart_t app_i2s_restart(app_i2s_data_t* app_data)
{
  static unsigned do_restart = 0;
  i2s_restart_t res = do_restart? I2S_RESTART : I2S_NO_RESTART;
  do_restart = 0;
  return res;
}

I2S_CALLBACK_ATTR
static
void app_i2s_receive(app_i2s_data_t* app_data, 
                     size_t num_in, 
                     const int32_t* samples)
{
  // printf("[I2S Receive]\n");

}

I2S_CALLBACK_ATTR
static
void app_i2s_send(app_i2s_data_t* app_data,
                  size_t num_out, 
                  int32_t* samples)
{
  if(app_data->t == 0){
    for(int c = 0; c < num_out; c++){
      samples[c] = 0;
    }
  } else {
    assert(app_data->t == app_data->u+1);
    for(int c = 0; c < num_out; c++){
      int32_t samp = app_data->last_pcm_frame[(N_MICS==1)?0:c];
      samples[c] = samp;
    }
    app_data->u++;
  }
}


i2s_callback_group_t i2s_context = {
  .init = (i2s_init_t) app_i2s_init,
  .restart_check = (i2s_restart_check_t) app_i2s_restart,
  .receive = (i2s_receive_t) app_i2s_receive,
  .send = (i2s_send_t) app_i2s_send,
  .app_data = &app_i2s_data,
};


void app_i2s_task()
{

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
