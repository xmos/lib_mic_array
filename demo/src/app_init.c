

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


static int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][N_MICS];

void app_context_init()
{
  app_context.audio_buffer_ctx = abuff_init(N_MICS, AUDIO_BUFFER_SAMPLES, &audio_buffer[0][0]);
}


void app_pdm_filter_context_init( 
  chanend_t c_pdm_data )
{
  pdm_filter_context.mic_count = N_MICS;
  
  pdm_filter_context.stage1.filter_coef = (uint32_t*) stage1_coef;
  pdm_filter_context.stage1.c_pdm_data = (unsigned) c_pdm_data;
  pdm_filter_context.stage1.pdm_history = &ma_data.stage1.pdm_history[0];

  pdm_filter_context.stage2.decimation_factor = STAGE2_DEC_FACTOR;
  pdm_filter_context.stage2.filters = &ma_data.stage2.filters[0];

  pdm_filter_context.framing = (ma_framing_context_t*) &ma_data.framing;


  ma_framing_init(pdm_filter_context.framing,
                  pdm_filter_context.mic_count,
                  SAMPLES_PER_FRAME,
                  FRAME_BUFFERS,
                  MA_FMT_SAMPLE_CHANNEL);
                  
  // Initialize the second stage filters
  ma_stage2_filters_init(&ma_data.stage2.filters[0], 
                         &ma_data.stage2.state_buffer[0][0],
                         N_MICS,
                         STAGE2_TAP_COUNT,
                         stage2_coef,
                         STAGE2_SHR);
}

