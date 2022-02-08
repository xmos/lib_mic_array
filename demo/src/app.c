

#include <platform.h>

#include "app_config.h"
#include "app.h"
#include "i2s.h"
#include "util/audio_buffer.h"
#include "mic_array_framing.h"
#include "etc/mic_array_filters_default.h"

#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <math.h>


static int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][N_MICS];
// static ma_dc_elim_chan_state_t dc_elim_state[N_MICS];

app_context_t app_context;


app_mic_array_data_t ma_data;
ma_pdm_filter_context_t pdm_filter_context;

// This has to be in C because mic_array_context_init() is a macro rather than a function,
//  and it does stuff with pointers that XC wouldn't like.
void app_pdm_filter_context_init( 
  chanend_t c_pdm_data )
{

  mic_array_context_init( &pdm_filter_context, &ma_data, N_MICS,
                          stage1_coef, c_pdm_data, STAGE2_DEC_FACTOR,
                          STAGE2_TAP_COUNT, stage2_coef, stage2_shr, 
                          SAMPLES_PER_FRAME, FRAME_BUFFERS, MA_FMT_SAMPLE_CHANNEL, 1);

}

// This is initializing the audio buffer that connects the mic array 
// with I2S
void app_context_init()
{
  app_context.audio_buffer_ctx = abuff_init(N_MICS, AUDIO_BUFFER_SAMPLES, &audio_buffer[0][0]);
}




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





