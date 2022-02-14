#pragma once

#include "app_config.h"

#include "util/audio_buffer.h"
#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

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

#if APP_USE_BASIC_CONFIG
typedef MIC_ARRAY_DATA_BASIC(N_MICS, SAMPLES_PER_FRAME) app_mic_array_data_t;
#else                  
typedef MIC_ARRAY_DATA(N_MICS, STAGE2_DEC_FACTOR, 
                       STAGE2_TAP_COUNT, SAMPLES_PER_FRAME, 
                       APP_USE_DC_OFFSET_ELIMINATION) app_mic_array_data_t;
#endif //APP_USE_BASIC_CONFIG

streaming_channel_t app_s_chan_alloc();

void app_context_init(
    port_t p_pdm_mics,
    chanend_t c_pdm_data);

void app_dac3101_init();

void app_pdm_rx_task(
    port_t p_pdm_mics,
    chanend_t c_pdm_data);

void app_decimator_task(
    port_t p_pdm_mics,
    streaming_channel_t c_pdm_data);

void app_i2s_task( app_context_t* app_context );

#ifdef __XC__
}
#endif