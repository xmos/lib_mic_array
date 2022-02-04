

#include <platform.h>

#include "app.h"
#include "i2s.h"
#include "util/audio_buffer.h"
#include "mic_array_framing.h"

#include "app_config.h"

#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <math.h>



app_context_t app_context;
app_mic_array_data_t ma_data;
ma_pdm_filter_context_t pdm_filter_context;



void ma_proc_frame_user(
  void* app_context,
  int32_t pcm_frame[])
{
  int32_t (*frame)[N_MICS] = (int32_t (*)[N_MICS]) &pcm_frame[0];

  app_context_t* app = (app_context_t*) app_context;

  for(int k = 0; k < SAMPLES_PER_FRAME; k++){

    for(int j = 0; j < N_MICS; j++)
      frame[k][j] <<= 8;
      
    abuff_frame_add(&app->audio_buffer_ctx, &frame[k][0]);
  }
}




I2S_CALLBACK_ATTR
void app_i2s_send(app_context_t* app_data,
                  size_t num_out, 
                  int32_t* samples)
{
  int32_t frame[N_MICS];
  abuff_frame_get(&app_data->audio_buffer_ctx, frame);
  
  for(int c = 0; c < num_out; c++){
    int32_t samp = frame[(N_MICS==1)?0:c];
    samples[c] = samp;
  }
}
