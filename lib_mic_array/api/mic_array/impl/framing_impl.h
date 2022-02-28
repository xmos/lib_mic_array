#pragma once

#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif //__XC__


static inline
ma_frame_format_t ma_frame_format(
    const unsigned channel_count,
    const unsigned sample_count,
    const ma_frame_layout_e layout)
{
  ma_frame_format_t format;
  format.channel_count = channel_count;
  format.sample_count = sample_count;
  format.layout = layout;
  return format;
}

static inline
int32_t* ma_framing_add_and_signal(
    ma_framing_context_t* ctx,
    ma_proc_sample_ctx_t c_context,
    int32_t sample[])
{
  int32_t* frame = ma_framing_add_sample(ctx, sample);

  if(frame){
    ma_proc_frame(c_context, frame, &ctx->config.format);
  }

  return frame;
}



#if defined(__XC__) || defined(__cplusplus)
}
#endif //__XC__