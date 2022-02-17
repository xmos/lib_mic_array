#pragma once


#include "mic_array/types.h"

#include <stdint.h>



//in words
#define MA_FRAMING_BUFFER_SIZE(CHAN_COUNT, FRAME_SIZE, FRAME_COUNT)     \
              (3 + sizeof(ma_frame_format_t)                            \
                 + ((CHAN_COUNT)*(FRAME_SIZE)*(FRAME_COUNT)))


#ifdef __XC__
extern "C" {
#endif

// @todo: rename these to MA_LYT_*
typedef enum {
  MA_FMT_CHANNEL_SAMPLE,
  MA_FMT_SAMPLE_CHANNEL
} ma_frame_layout_e;

typedef struct {
  unsigned channel_count;
  unsigned sample_count;
  // unsigned sample_depth; // in bytes
  ma_frame_layout_e layout;
} ma_frame_format_t;

typedef struct {

  struct {
    unsigned frame;
    unsigned sample;
  } current;

  struct {
    ma_frame_format_t format;
    unsigned frame_count;
  } config;

  int32_t frames[0];
} ma_framing_context_t;



void ma_framing_init(
  ma_framing_context_t* ctx,
  const unsigned channel_count,
  const unsigned sample_count,
  const unsigned frame_count);


unsigned ma_framing_add_sample(
  ma_framing_context_t* ctx,
  ma_dec_output_t c_decimator_out,
  int32_t sample[]);


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

  
#ifdef __XC__
}
#endif