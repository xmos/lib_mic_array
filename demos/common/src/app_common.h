// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "app_config.h"

#include "mic_array.h"
#include "util/audio_buffer.h"

#include <stdint.h>


#define I2S_CLKBLK XS1_CLKBLK_3

#if defined(__XC__)
#  define static_const  static const
#else
#  define static_const const
#endif

C_API_START

void board_dac3101_init();

void aic3204_board_init();
void aic3204_codec_reset();

C_API_END


void eat_audio_frames_task(
    chanend_t c_from_decimator,
    static_const unsigned frame_words);

void receive_and_buffer_audio_task(
    chanend_t c_from_decimator,
    audio_ring_buffer_t* output_buffer,
    const unsigned mic_count,
    const unsigned samples_per_frame,
    static_const unsigned frame_words);
    
