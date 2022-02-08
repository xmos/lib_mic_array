#pragma once

#include "app_config.h"

#include "etc/mic_array_filters_default.h"
#include "util/audio_buffer.h"
#include "mic_array.h"

#include <stdint.h>


#define I2S_CLKBLK XS1_CLKBLK_3

#define FRAME_BUFFERS 2


#ifdef __XC__
extern "C" {
#endif

typedef struct {
  audio_ring_buffer_t audio_buffer_ctx;
} app_context_t;


extern app_context_t app_context;

typedef MIC_ARRAY_DATA(N_MICS, STAGE2_DEC_FACTOR, STAGE2_TAP_COUNT, 
                       SAMPLES_PER_FRAME, FRAME_BUFFERS, 
                       APP_USE_DC_OFFSET_ELIMINATION) app_mic_array_data_t;

extern app_mic_array_data_t ma_data;

extern ma_pdm_filter_context_t pdm_filter_context;

void app_pdm_filter_context_init( chanend_t c_pdm_data );

void app_context_init();

void app_i2c_init();

void app_i2s_task( app_context_t* app_context );

#ifdef __XC__
}
#endif