// Copyright (c) 2019, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <xclib.h>
#include <stdio.h>
#include "mic_array.h"

#define CRC_POLY (0xEB31D82E)

void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

void push_random_data(streaming chanend c_pdm_mics) {
    unsigned x = 1234;
    while (1) {
        crc32(x, -1, CRC_POLY);
        c_pdm_mics <: x;
    }
}

void audio_frontend_debug_1_dc_no_ref(streaming chanend c_not_a_port,
                                      streaming chanend c_ds_output[]) {
    streaming chan c_4x_pdm_mic;

    par {
        pdm_rx_debug(c_not_a_port, c_4x_pdm_mic, NULL);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic, c_ds_output[0], NULL);
    }
}

void setup_mic_array_decimator(mic_array_decimator_conf_common_t &decimator_common_config,
                               mic_array_decimator_config_t decimator_config[MIC_DECIMATORS],
                               int mic_array_data[MIC_DECIMATORS*MIC_CHANNELS][THIRD_STAGE_COEFS_PER_STAGE*MIC_DECIMATION_FACTOR]) {
    unsafe {
#if MIC_ARRAY_FRAME_SIZE < 16
// Comment taken from mic_array.h
/**< If len is less than 16 then this sets the frame size to 2 to the power of len, i.e. A frame will contain 2 to the power of len samples of each channel.
                                   If len is 16 or greater then the frame size is equal to len. */

        decimator_common_config.len = MIC_ARRAY_MAX_FRAME_SIZE_LOG2;
#else
        decimator_common_config.len = MIC_ARRAY_FRAME_SIZE;
#endif
        decimator_common_config.apply_dc_offset_removal = 1;
        decimator_common_config.index_bit_reversal = 0;
        decimator_common_config.windowing_function = null;
        decimator_common_config.output_decimation_factor = MIC_DECIMATION_FACTOR;
        decimator_common_config.coefs = g_third_stage_div_6_fir; // 16kHz
        decimator_common_config.apply_mic_gain_compensation = 0;
        decimator_common_config.fir_gain_compensation = FIR_COMPENSATOR_DIV_6; // 16kHz
        decimator_common_config.buffering_type = DECIMATOR_NO_FRAME_OVERLAP;
        decimator_common_config.number_of_frame_buffers = MIC_FRAME_BUFFERS;

        decimator_config[0].dcc = &decimator_common_config;
        decimator_config[0].data = mic_array_data[0];
        decimator_config[0].mic_gain_compensation[0]=0;
        decimator_config[0].mic_gain_compensation[1]=0;
        decimator_config[0].mic_gain_compensation[2]=0;
        decimator_config[0].mic_gain_compensation[3]=0;
        decimator_config[0].channel_count = MIC_CHANNELS;
        decimator_config[0].async_interface_enabled = 0;
    }
}
