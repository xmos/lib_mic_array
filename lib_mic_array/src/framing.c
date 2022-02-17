
#include "mic_array/framing.h"
#include "mic_array/frame_transfer.h"

#include <string.h>


/*
  Example:

    int32_t ma_framing_buff[MA_FRAMING_BUFFER_SIZE(N_MICS, 12, 2)];
    ma_framing_context_t* ma_framing_ctx = (ma_framing_context_t*) &ma_framing_buff[0];
    ma_framing_init(ma_framing_ctx, N_MICS, 12, 2);


  Should probably be static inline
*/
void ma_framing_init(
  ma_framing_context_t* ctx,
  const unsigned channel_count,
  const unsigned sample_count,
  const unsigned frame_count)
{
  ctx->config.format = ma_frame_format(channel_count, sample_count, 
                                       MA_FMT_CHANNEL_SAMPLE);
  ctx->config.frame_count = frame_count;

  ctx->current.frame = 0;
  ctx->current.sample = 0;
}

/**
 * If for whatever reason using a strong symbol isn't overriding ma_proc_frame(), 
 * this can be set to 1 to suppress the library definition.
 */
#ifndef MA_CONFIG_SUPPRESS_PROC_FRAME
#define MA_CONFIG_SUPPRESS_PROC_FRAME 0
#endif

#if !(MA_CONFIG_SUPPRESS_PROC_FRAME)

__attribute__((weak))
void ma_proc_frame(
  ma_dec_output_t c_decimator_out,
  int32_t pcm_frame[],
  const ma_frame_format_t* frame_format)
{
  ma_frame_tx_s32(c_decimator_out, 
                  pcm_frame, 
                  frame_format);
}

#endif


unsigned ma_framing_add_sample(
    ma_framing_context_t* ctx,
    ma_dec_output_t c_decimator_out,
    int32_t sample[])
{
  const unsigned channel_count = ctx->config.format.channel_count;
  const unsigned sample_count = ctx->config.format.sample_count;
  const unsigned frame_words = (channel_count * sample_count);

  int32_t* curr_frame = &ctx->frames[ctx->current.frame * frame_words];

  if(ctx->config.format.layout == MA_FMT_SAMPLE_CHANNEL){
    memcpy(&curr_frame[channel_count * ctx->current.sample], 
           sample, 
           sizeof(int32_t) * channel_count);
  } else {
    int32_t* curr_samp = &curr_frame[ctx->current.sample];

    for(int k = 0; k < channel_count; k++){
      curr_samp[k * sample_count] = sample[k];
    }
  }

  if( ++ctx->current.sample != sample_count )
    return 0;

  // Frame is done
  ctx->current.sample = 0;
  
  if( ++ctx->current.frame == ctx->config.frame_count )
    ctx->current.frame = 0; // Cycle back to first frame

  ma_proc_frame(c_decimator_out, 
                curr_frame, 
                &ctx->config.format);
  return 1;
}