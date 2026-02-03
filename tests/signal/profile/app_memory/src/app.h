// Copyright 2023-2026 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <stdint.h>

#include "app_config.h"
#include "mic_array.h"

#if !USE_DEFAULT_API

C_API_START

MA_C_API
void app_mic_array_init( void );

MA_C_API
void app_mic_array_task( chanend_t c_frames_out );

MA_C_API
void app_i2s_task( chanend_t c_audio_frames );

C_API_END

#endif
