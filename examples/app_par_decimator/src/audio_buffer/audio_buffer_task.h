// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "app_config.h"

#include "mic_array.h"
#include "audio_buffer.h"

#include <stdint.h>

#if defined(__XC__)
#  define static_const  static const
#else
#  define static_const const
#endif

void receive_and_buffer_audio_task(
    chanend_t c_from_decimator,
    audio_ring_buffer_t* output_buffer,
    const unsigned mic_count,
    const unsigned samples_per_frame,
    static_const unsigned frame_words);

