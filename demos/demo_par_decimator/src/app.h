// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#include <stdint.h>

#include "app_config.h"
#include "app_common.h"
#include "mic_array.h"
#include "util/audio_buffer.h"

typedef struct app_ctx {
  audio_ring_buffer_t rb; // Ring buffer for the mic array audio samples.
#if (MIC_ARRAY_TILE == 0 || USE_BUTTONS)
  chanend_t c_intertile; // Used to transfer mic array samples on one tile to an I2S DAC on the other tile.
#endif
} app_context_t;

C_API_START

MA_C_API
void app_mic_array_init( void );

MA_C_API
void app_mic_array_task( chanend_t c_frames_out );

MA_C_API
void app_mic_array_assertion_enable( void );

MA_C_API
void app_mic_array_assertion_disable( void );

#if (MIC_ARRAY_TILE == 0)

MA_C_API
void app_i2s_task0( void* app_context );

#endif

MA_C_API
void app_i2s_task( void* app_context );

#if USE_BUTTONS

#if (MIC_ARRAY_TILE == 0)

MA_C_API
void app_buttons_task( void );

#else // (MIC_ARRAY_TILE == 0)

MA_C_API
void app_buttons_task( void* app_context );

MA_C_API
void app_set_selected_mic_dataline( uint32_t dataline );

#endif // (MIC_ARRAY_TILE == 0)

#endif // USE_BUTTONS

MA_C_API
uint32_t app_get_selected_mic_dataline( void );

C_API_END
