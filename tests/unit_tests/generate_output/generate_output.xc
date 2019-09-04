// Copyright (c) 2019, XMOS Ltd, All rights reserved
#include <stdio.h>
#include "math.h"
#include "string.h"
#include "stdlib.h"
#include "mic_array.h"
#include "frontend_debug.h"

#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>


int main() {
    streaming chan c_pdm_mics;
    streaming chan c_ds_output[1];

    // Mic array state
    int mic_array_data[MIC_DECIMATORS*MIC_CHANNELS][THIRD_STAGE_COEFS_PER_STAGE*MIC_DECIMATION_FACTOR];
    unsigned mic_buffer_index = 0;
    mic_array_frame_time_domain audio_frame[MIC_FRAME_BUFFERS];
    mic_array_decimator_conf_common_t decimator_common_config;
    mic_array_decimator_config_t decimator_config[MIC_DECIMATORS];

    par {
        audio_frontend_debug_1_dc_no_ref(c_pdm_mics, c_ds_output);
        push_random_data(c_pdm_mics);
        {
            setup_mic_array_decimator(decimator_common_config, decimator_config,
                                      mic_array_data);
            mic_array_decimator_configure(c_ds_output,
                                          MIC_DECIMATORS,
                                          decimator_config);
            mic_array_init_time_domain_frame(c_ds_output,
                                             MIC_DECIMATORS,
                                             mic_buffer_index,
                                             audio_frame,
                                             decimator_config);

            // Skip the first 1000 samples
            for(unsigned i=0;i<1000;i++) {
                mic_array_get_next_time_domain_frame(
                    c_ds_output, MIC_DECIMATORS, mic_buffer_index,
                    audio_frame, decimator_config);
            }


            mic_array_frame_time_domain *current;
            int fd = open("unit_test.expect", O_RDWR | O_CREAT, S_IRWXU|S_IRWXG|S_IRWXO);

            // Save the next 1000 samples
            for(unsigned i=0;i<1000;i++) {
                current = mic_array_get_next_time_domain_frame(
                    c_ds_output, MIC_DECIMATORS, mic_buffer_index,
                    audio_frame, decimator_config);
                for (int m=0; m<MIC_CHANNELS; m++) {
                    unsafe {
                        write(fd, &(current->data[m][0]), 4);
                    }
                }
            }

            close(fd);

            _Exit(0);

        }
    }
    return 0;
}
