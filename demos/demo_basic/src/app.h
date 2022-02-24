#pragma once

#include "app_config.h"
#include "app_common.h"
#include "util/audio_buffer.h"
#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

#include <stdint.h>

#ifdef __XC__
extern "C" {
#endif

typedef int32_t audio_frame_t[MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME][MIC_ARRAY_CONFIG_MIC_COUNT];

void app_i2s_task( void* app_context );

#ifdef __XC__
}
#endif