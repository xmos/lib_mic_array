// Copyright 2021-2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "audio_buffer.h"

#include <string.h>



void abuff_frame_get(
  audio_ring_buffer_t* rb,
  int32_t frame[])
{
  const unsigned chan_count = rb->config.channel_count;

  if(!rb->ready) {
    memset(frame, 0, chan_count * sizeof(int32_t));
  } else {
    memcpy(frame, &rb->audio[chan_count * rb->next_get], chan_count * sizeof(int32_t));
    
    rb->next_get++;
    if(rb->next_get >= rb->config.max_frames)
      rb->next_get = 0;
  }
}


void abuff_frame_add(
  audio_ring_buffer_t* rb,
  int32_t frame[])
{
  const unsigned chan_count = rb->config.channel_count;
  memcpy(&rb->audio[chan_count * rb->next_add], frame, chan_count * sizeof(int32_t));

  rb->next_add++;
  if(rb->next_add >= rb->config.max_frames)
    rb->next_add = 0;

  if(!rb->ready && (rb->next_add == (rb->config.max_frames>>1)))
    rb->ready = 1;
}
