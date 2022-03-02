#pragma once

#include "app_config.h"
#include "app_common.h"
#include "util/audio_buffer.h"
#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

#include <stdint.h>

#if defined(__XC__) || defined(__cplusplus)
extern "C" {
#endif

typedef int32_t audio_frame_t[MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME][MIC_ARRAY_CONFIG_MIC_COUNT];

void app_i2s_task( void* app_context );

#if defined(__XC__) || defined(__cplusplus)
}
#endif