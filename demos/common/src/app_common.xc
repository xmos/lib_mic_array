// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "app_common.h"

#ifndef MIC_ARRAY_CONFIG_MIC_COUNT
#define MIC_ARRAY_CONFIG_MIC_COUNT N_MICS
#endif

void eat_audio_frames_task(
    chanend_t c_from_decimator,
    static const unsigned frame_words)
{
  int32_t audio_frame[frame_words];

  while(1){
    ma_frame_rx(audio_frame, c_from_decimator, frame_words, 1);
  }
}

void receive_and_buffer_audio_task(
    chanend_t c_from_decimator,
    audio_ring_buffer_t* output_buffer,
    const unsigned mic_count,
    const unsigned samples_per_frame,
    static const unsigned frame_words)
{
  int32_t audio_frame[frame_words];
  int32_t smp_buff[MIC_ARRAY_CONFIG_MIC_COUNT];

  while(1){

    ma_frame_rx(audio_frame, c_from_decimator, frame_words, 1);

    for(int k = 0; k < frame_words; k++)
      audio_frame[k] <<= 6;

    for(int k = 0; k < samples_per_frame; k++){
      for(int j = 0; j < mic_count; j++)
        smp_buff[j] = audio_frame[k + samples_per_frame * j];
      abuff_frame_add( output_buffer, &smp_buff[0] );
    }
  }
}
