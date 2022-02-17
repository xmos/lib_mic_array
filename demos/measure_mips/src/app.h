#pragma once

#include "app_config.h"
#include "app_common.h"
#include "util/audio_buffer.h"
#include "mic_array.h"
#include "mic_array/etc/filters_default.h"

#include <stdint.h>

#define FRAME_BUFFERS 2


#ifdef __XC__
extern "C" {
#endif
             
typedef MIC_ARRAY_DATA(N_MICS, STAGE2_DEC_FACTOR, 
                       STAGE2_TAP_COUNT, SAMPLES_PER_FRAME, 
                       APP_USE_DC_OFFSET_ELIMINATION) app_mic_array_data_t;

void app_context_init(
    port_t p_pdm_mics,
    chanend_t c_pdm_data);

void app_pdm_rx_task(
    port_t p_pdm_mics,
    chanend_t c_pdm_data);

void app_decimator_task(
    port_t p_pdm_mics,
    streaming_channel_t c_pdm_data,
    chanend_t c_decimator_out);

#ifdef __XC__
}
#endif