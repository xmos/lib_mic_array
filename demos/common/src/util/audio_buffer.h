// Copyright 2021-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <stdint.h>

#include "mic_array/api.h"
#include "util/audio_buffer.h"

C_API_START

MA_C_API
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





static inline 
audio_ring_buffer_t abuff_init(
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

MA_C_API
void abuff_frame_get(
  audio_ring_buffer_t* rb,
  int32_t frame[]);

MA_C_API
void abuff_frame_add(
  audio_ring_buffer_t* rb,
  int32_t frame[]);

C_API_END