#pragma once

#include <stdint.h>


#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif

typedef struct {

  int32_t* audio;
  int next_add;
  int next_get;
  unsigned ready;

  struct {
    unsigned max_frames;
    unsigned channel_count;
  } config;
} audio_ring_buffer_t;





static inline audio_ring_buffer_t abuff_init(
  const unsigned channel_count,
  const unsigned max_frames,
  int32_t* mem_buffer)
{
  audio_ring_buffer_t ctx;
  ctx.audio = mem_buffer;
  ctx.next_add = 0;
  ctx.next_get = 0;
  ctx.ready = 0;
  ctx.config.max_frames = max_frames;
  ctx.config.channel_count = channel_count;
  return ctx;
}


void abuff_frame_get(
  audio_ring_buffer_t* rb,
  int32_t frame[]);


void abuff_frame_add(
  audio_ring_buffer_t* rb,
  int32_t frame[]);

  
#if defined(__XC__) || defined(__cplusplus)
}
#endif