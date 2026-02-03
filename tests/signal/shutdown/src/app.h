// Copyright 2025-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include "mic_array.h"

C_API_START

// Thread that runs the decimator
MA_C_API
void app_mic(chanend_t c_pdm_in, chanend_t c_frames_out);

MA_C_API
void app_controller(chanend_t c_pdm_in, chanend_t c_sync);

MA_C_API
void app_mic_interface(chanend_t c_sync, chanend_t c_frames_out);

MA_C_API
void assert_when_timeout();

C_API_END
