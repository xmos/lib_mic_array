// Copyright (c) 2017-2019, XMOS Ltd, All rights reserved


#ifdef __XC__
#include "mic_array.h"

void push_random_data(streaming chanend c_pdm_mics);
void audio_frontend_debug_1_dc_no_ref(streaming chanend c_not_a_port,
                                      streaming chanend c_ds_output[]);
void receive_from_mics_init(streaming chanend c_mics[]);
mic_array_frame_time_domain * unsafe get_next_frame(streaming chanend c_mics[]);
void setup_mic_array_decimator(mic_array_decimator_conf_common_t &decimator_common_config,
                               mic_array_decimator_config_t decimator_config[MIC_DECIMATORS],
                               int mic_array_data[MIC_DECIMATORS*MIC_CHANNELS][THIRD_STAGE_COEFS_PER_STAGE*MIC_DECIMATION_FACTOR]);

#endif
