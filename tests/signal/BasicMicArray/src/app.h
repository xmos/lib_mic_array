// Copyright 2022-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"

C_API_START

// Thread that runs the decimator
MA_C_API
void app_mic(chanend_t c_pdm_in, chanend_t c_frames_out);

// Thread that receives samples and pushes them into a FIFO
MA_C_API
void app_output_task(chanend_t c_frames_in, chanend_t c_fifo);

// Thread that sends FIFO results back to host
MA_C_API
void app_fifo_to_xscope_task(chanend_t c_fifo);

// Print filters (for debug purposes)
MA_C_API
void app_print_filters();

C_API_END
