

#include <platform.h>

#include "app_config.h"
#include "app.h"
#include "i2s.h"
#include "util/audio_buffer.h"
#include "mic_array_framing.h"
#include "etc/mic_array_filters_default.h"

#include <xcore/interrupt.h>

#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <math.h>


static int32_t audio_buffer[AUDIO_BUFFER_SAMPLES][N_MICS];

app_context_t app_context;

static app_mic_array_data_t ma_data;
static ma_decimator_context_t decimator_context;

#if !(APP_USE_PDM_RX_ISR)
static ma_pdm_rx_context_t pdm_rx_context;
#endif


// For some reason XC files don't like it when streaming_channel.h is included.
streaming_channel_t app_s_chan_alloc()
{
  return s_chan_alloc();
}


void app_context_init(
    port_t p_pdm_mics,
    chanend_t c_pdm_data)
{
  // Initialize the audio buffer that connects the mic array with I2S
  app_context.audio_buffer_ctx = abuff_init(N_MICS, AUDIO_BUFFER_SAMPLES, &audio_buffer[0][0]);


// This has to be in C because mic_array_context_init() is a macro rather than a function,
//  and it does stuff with pointers that XC wouldn't like.
#if APP_USE_BASIC_CONFIG
  mic_array_context_init_basic( &decimator_context, &ma_data, N_MICS, 
                                SAMPLES_PER_FRAME );
#else
  mic_array_context_init( &decimator_context, &ma_data, N_MICS,
                          stage1_coef, STAGE2_DEC_FACTOR,
                          STAGE2_TAP_COUNT, stage2_coef, stage2_shr, 
                          SAMPLES_PER_FRAME, MA_FMT_SAMPLE_CHANNEL, 1);
#endif //APP_USE_BASIC_CONFIG



#if !(APP_USE_PDM_RX_ISR)
  pdm_rx_context = ma_pdm_rx_context_create((uint32_t*) &ma_data.stage1.pdm_buffers[0],
                                            (uint32_t*) &ma_data.stage1.pdm_buffers[1],
                                            N_MICS * STAGE2_DEC_FACTOR);
#endif

}


void ma_proc_frame(
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

#if !(APP_USE_PDM_RX_ISR)
void app_pdm_rx_task(
    port_t p_pdm_mics,
    chanend_t c_pdm_data)
{
  ma_pdm_rx_task(p_pdm_mics, pdm_rx_context, c_pdm_data);
}
#endif

void app_decimator_task(
    port_t p_pdm_mics,
    streaming_channel_t c_pdm_data)
{
#if APP_USE_PDM_RX_ISR
  ma_pdm_rx_isr_enable((port_t) p_pdm_mics, 
                       (uint32_t*) &ma_data.stage1.pdm_buffers[0],
                       (uint32_t*) &ma_data.stage1.pdm_buffers[1],
                       N_MICS * STAGE2_DEC_FACTOR,
                       c_pdm_data.end_a);

  // Once we unmask interrupts, the ISR will begin triggering and collecting PDM samples. At
  // that point we need to be ready to pull PDM samples from the ISR via the c_pdm_data chanend.
  interrupt_unmask_all();
#endif

  ma_decimator_task( &decimator_context, c_pdm_data.end_b, &app_context );
}


