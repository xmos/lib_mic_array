// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"

C_API_START


MA_C_API
void app_init(
    unsigned mic_count, 
    unsigned frame_size,
    unsigned use_dcoe);

MA_C_API
void app_pdm_rx_task(
    unsigned mic_count, 
    unsigned frame_size,
    unsigned use_dcoe);

MA_C_API
void app_setup_pdm_rx_isr(
    unsigned mic_count, 
    unsigned frame_size,
    unsigned use_dcoe);

MA_C_API
void app_decimator_task(
    unsigned mic_count, 
    unsigned frame_size,
    unsigned use_dcoe,
    chanend_t c_audio_frames);

C_API_END