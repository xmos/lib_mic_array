// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include <platform.h>

#include "app.h"
#include "i2s.h"
#include "util/audio_buffer.h"

#include "app_config.h"

#if USE_BUTTONS
#include <xcore/hwtimer.h>
#endif
#include <xcore/channel_streaming.h>
#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <math.h>

#define I2S_CLKBLK    XS1_CLKBLK_3

#if !defined(MIC_ARRAY_CONFIG_USE_DDR)
  #error "MIC_ARRAY_CONFIG_USE_DDR must be defined"
#endif

// Every two values in this LUT relates to DDR samples on a given MIC dataline (lut_index = 2 * mic_dataline).
#if MIC_ARRAY_CONFIG_MIC_COUNT == 16 && MIC_ARRAY_CONFIG_USE_DDR == 1
static const int lut_index[] = {0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15};
#elif MIC_ARRAY_CONFIG_MIC_COUNT == 8 && MIC_ARRAY_CONFIG_USE_DDR == 1
static  const int lut_index[] = {0, 4, 1, 5, 2, 6, 3, 7};
#elif MIC_ARRAY_CONFIG_MIC_COUNT == 2
static  const int lut_index[] = {0, 1};
#elif MIC_ARRAY_CONFIG_MIC_COUNT == 1
static  const int lut_index[] = {0};
#else
    #error "MIC_ARRAY_CONFIG_MIC_COUNT: Unsupported value"
#endif

static int i2s_mclk_bclk_ratio(
        const unsigned audio_clock_frequency,
        const unsigned sample_rate)
{
    return audio_clock_frequency / (sample_rate * (8 * sizeof(int32_t)) * I2S_CHANS_PER_FRAME);
}

#if (MIC_ARRAY_TILE == 0)

// When MICS are on Tile 0,
// Tile 0, send a subset of the MIC data to Tile 1.
// The selected data to be sent is optionally provided via pushbutton control.

void app_i2s_task0(void *app_context)
{
  app_context_t *ctx = (app_context_t *)app_context;

  printf("0: audio_buff=%p\n", &ctx->rb);

  while (1) {
    int32_t frame[MIC_ARRAY_CONFIG_MIC_COUNT];
    abuff_frame_get(&ctx->rb, frame);

    size_t num_out;
    num_out = chanend_in_word(ctx->c_intertile);

    // Transfer frame data to other tile
    int start_index = app_get_selected_mic_dataline() << 1;
    for (int c = start_index; c < start_index + num_out; c++) {
      int index = (MIC_ARRAY_CONFIG_MIC_COUNT == 1) ? lut_index[0] :lut_index[c];
      int32_t samp = frame[index];
      chanend_out_word(ctx->c_intertile, samp);
    }
  }
}

I2S_CALLBACK_ATTR
void app_i2s_send(void *app_context,
                  size_t num_out,
                  int32_t *samples)
{
  app_context_t *ctx = (app_context_t *)app_context;
  chanend_out_word(ctx->c_intertile, num_out);

  // Receive frame data from other tile
  for(int c = 0; c < num_out; c++){
    samples[c] = chanend_in_word(ctx->c_intertile);
  }
}

#else // (MIC_ARRAY_TILE == 0)

// When MICS are on Tile 1,
// Tile 0 optionally provides the selected MIC data line pair to listen to on the DAC.

I2S_CALLBACK_ATTR
void app_i2s_send(void *app_context,
                  size_t num_out,
                  int32_t *samples)
{
  app_context_t *ctx = (app_context_t *)app_context;
  int32_t frame[MIC_ARRAY_CONFIG_MIC_COUNT];

  // Read from ring buffer the full frame and the copy only the samples needed to drive the I2S DAC.
  abuff_frame_get(&ctx->rb, frame);

#if USE_BUTTONS
   app_set_selected_mic_dataline(chanend_in_word(ctx->c_intertile));
   static int last_selected_mic_dataline = 255;
   if (last_selected_mic_dataline != app_get_selected_mic_dataline()) {
      last_selected_mic_dataline = app_get_selected_mic_dataline();
      printf("TILE1 DATALINE: %lu\n", app_get_selected_mic_dataline());
   }
#endif

  int start_index = app_get_selected_mic_dataline() << 1;
  for (int c = start_index; c < start_index + num_out; c++) {
    int index = (MIC_ARRAY_CONFIG_MIC_COUNT == 1) ? lut_index[0] :lut_index[c];
    int32_t samp = frame[index];
    samples[c] = samp;
  }
}

#endif // (MIC_ARRAY_TILE == 0)


I2S_CALLBACK_ATTR
static
void app_i2s_init(void* app_context,
                  i2s_config_t* config)
{
  config->mode = I2S_MODE_I2S;
  config->mclk_bclk_ratio =  i2s_mclk_bclk_ratio(MIC_ARRAY_CONFIG_MCLK_FREQ,
                                                 APP_I2S_AUDIO_SAMPLE_RATE);
}

I2S_CALLBACK_ATTR
static
i2s_restart_t app_i2s_restart(void* app_context)
{
  return I2S_NO_RESTART;
}

I2S_CALLBACK_ATTR
static
void app_i2s_receive(void *app_context,
                     size_t num_in,
                     const int32_t *samples)
{
    // Do nothing because this is not ever called (output only)
}

i2s_callback_group_t i2s_context = {
  .init = (i2s_init_t) app_i2s_init,
  .restart_check = (i2s_restart_check_t) app_i2s_restart,
  .receive = (i2s_receive_t) app_i2s_receive,
  .send = (i2s_send_t) app_i2s_send,
  .app_data = NULL
};

void app_i2s_task(void *app_context)
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
