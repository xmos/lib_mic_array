
#include "mic_array/framing.h"

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
  const unsigned frame_size,
  const unsigned frame_count,
  const ma_frame_format_e format)
{
  ctx->config.channel_count = channel_count;
  ctx->config.frame_size = frame_size;
  ctx->config.frame_count = frame_count;
  ctx->config.format = format;

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
  void* app_context,
  int32_t pcm_frame[])
{

}

#endif


unsigned ma_framing_add_sample(
  ma_framing_context_t* ctx,
  void* app_context,
  int32_t sample[])
{
  int32_t* curr_frame = &ctx->frames[ctx->current.frame * (ctx->config.channel_count * ctx->config.frame_size)];

  if(ctx->config.format == MA_FMT_SAMPLE_CHANNEL){
    memcpy(&curr_frame[ctx->config.channel_count * ctx->current.sample], sample, sizeof(int32_t) * ctx->config.channel_count);
  } else {
    int32_t* curr_samp = &curr_frame[ctx->current.sample];
    unsigned stride = ctx->config.frame_size;

    for(int k = 0; k < ctx->config.channel_count; k++){
      curr_samp[k*stride] = sample[k];
    }
  }

  if( ++ctx->current.sample != ctx->config.frame_size )
    return 0;

  // Frame is done
  ctx->current.sample = 0;
  
  if( ++ctx->current.frame == ctx->config.frame_count )
    ctx->current.frame = 0; // Cycle back to first frame

  ma_proc_frame(app_context, curr_frame);
  return 1;
}