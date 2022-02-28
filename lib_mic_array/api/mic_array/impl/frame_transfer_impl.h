#pragma once

#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif //__XC__


static inline
void ma_sample_tx_s32(
    const chanend_t c_sample_out,
    const int32_t sample[],
    const unsigned channel_count)
{
  const ma_frame_format_t fmt = 
          ma_frame_format(channel_count, 1, MA_LYT_SAMPLE_CHANNEL);
  ma_frame_tx_s32(c_sample_out, sample, &fmt);
}


static inline
void ma_sample_tx_s16(
    const chanend_t c_sample_out,
    const int16_t sample[],
    const unsigned channel_count)
{
  const ma_frame_format_t fmt = 
          ma_frame_format(channel_count, 1, MA_LYT_SAMPLE_CHANNEL);
  ma_frame_tx_s16(c_sample_out, sample, &fmt);
}


static inline
void ma_sample_rx_s32(
    int32_t sample[],
    const chanend_t c_sample_in,
    const unsigned channel_count)
{
  const ma_frame_format_t fmt = 
          ma_frame_format(channel_count, 1, MA_LYT_SAMPLE_CHANNEL);
  ma_frame_rx_s32(sample, c_sample_in, &fmt);
}


static inline
void ma_sample_rx_s16(
    int16_t sample[],
    const chanend_t c_sample_in,
    const unsigned channel_count,
    const right_shift_t sample_shr)
{
  const ma_frame_format_t fmt = 
          ma_frame_format(channel_count, 1, MA_LYT_SAMPLE_CHANNEL);
  ma_frame_rx_s16(sample, c_sample_in, &fmt, sample_shr);
}


#if defined(__XC__) || defined(__cplusplus)
}
#endif //__XC__