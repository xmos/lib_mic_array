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


#if defined(__XC__) || defined(__cplusplus)
}
#endif //__XC__