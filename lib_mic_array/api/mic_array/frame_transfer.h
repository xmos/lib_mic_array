#pragma once

#include "xcore_compat.h"
#include "mic_array/framing.h"
#include "bfp_math.h"

#include <stdint.h>

#ifdef __XC__
extern "C" {
#endif



void ma_frame_tx_s32(
    const chanend_t c_frame_out,
    const int32_t frame[],
    const ma_frame_format_t* format);

void ma_frame_tx_s16(
    const chanend_t c_frame_out,
    const int16_t frame[],
    const ma_frame_format_t* format);

void ma_frame_rx_s32(
    int32_t frame[],
    const chanend_t c_frame_in,
    const ma_frame_format_t* format);

void ma_frame_rx_s16(
    int16_t frame[],
    const chanend_t c_frame_in,
    const ma_frame_format_t* format,
    const right_shift_t sample_shr);

int32_t* ma_frame_rx_ptr(
    const chanend_t c_frame_in);


static inline
void ma_sample_tx_s32(
    const chanend_t c_sample_out,
    const int32_t sample[],
    const unsigned channel_count)
{
  const ma_frame_format_t fmt = 
          ma_frame_format(channel_count, 1, MA_FMT_SAMPLE_CHANNEL);
  ma_frame_tx_s32(c_sample_out, sample, &fmt);
}

static inline
void ma_sample_tx_s16(
    const chanend_t c_sample_out,
    const int16_t sample[],
    const unsigned channel_count)
{
  const ma_frame_format_t fmt = 
          ma_frame_format(channel_count, 1, MA_FMT_SAMPLE_CHANNEL);
  ma_frame_tx_s16(c_sample_out, sample, &fmt);
}

static inline
void ma_sample_rx_s32(
    int32_t sample[],
    const chanend_t c_sample_in,
    const unsigned channel_count)
{
  const ma_frame_format_t fmt = 
          ma_frame_format(channel_count, 1, MA_FMT_SAMPLE_CHANNEL);
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
          ma_frame_format(channel_count, 1, MA_FMT_SAMPLE_CHANNEL);
  ma_frame_rx_s16(sample, c_sample_in, &fmt, sample_shr);
}

#ifdef __XC__
}
#endif