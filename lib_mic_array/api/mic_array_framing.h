#pragma once

#include <stdint.h>


//in words
#define MA_FRAMING_BUFFER_SIZE(CHAN_COUNT, FRAME_SIZE, FRAME_COUNT)    (6 + ((CHAN_COUNT)*(FRAME_SIZE)*(FRAME_COUNT)))


#ifdef __XC__
extern "C" {
#endif

typedef enum {
  MA_FMT_CHANNEL_SAMPLE,
  MA_FMT_SAMPLE_CHANNEL
} ma_frame_format_e;

typedef struct {

  struct {
    unsigned frame;
    unsigned sample;
  } current;

  struct {
  unsigned channel_count;
  unsigned frame_size;
  unsigned frame_count;
  ma_frame_format_e format;
  } config;

  int32_t frames[0];
} ma_framing_context_t;



void ma_framing_init(
  ma_framing_context_t* ctx,
  const unsigned channel_count,
  const unsigned frame_size,
  const unsigned frame_count,
  const ma_frame_format_e format);

unsigned ma_framing_add_sample(
  ma_framing_context_t* ctx,
  void* app_context,
  int32_t sample[]);

  
#ifdef __XC__
}
#endif