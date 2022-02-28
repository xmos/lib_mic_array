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


void app_init(
    port_t p_pdm_mics,
    streaming_channel_t c_pdm_blocks);

void app_pdm_rx_task();
    
void app_decimator_task(chanend_t c_audio_frame);

void app_i2s_task( audio_ring_buffer_t* audio_buff );

#if defined(__XC__) || defined(__cplusplus)
}
#endif