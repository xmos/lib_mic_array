// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include "unity.h"
#include "math.h"
#include "string.h"
#include "stdlib.h"
#include "mic_array.h"
#include "frontend_debug.h"

#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>


void test_frame_size() {
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

            int fd = open("unit_test.expect", O_RDONLY);

            mic_array_frame_time_domain *current;
            // Global sample index
            unsigned g_idx = 0;
            while(1) {
                current = mic_array_get_next_time_domain_frame(
                    c_ds_output, MIC_DECIMATORS, mic_buffer_index,
                    audio_frame, decimator_config);
                for (int i=0; i<MIC_ARRAY_FRAME_SIZE; i++) {
                    if (g_idx >= 1000) {
                        for (int m=0; m<MIC_ARRAY_NUM_MICS; m++) {
                            int expected_val;
                            unsafe {
                                read(fd, &expected_val, 4);
                            }
                            TEST_ASSERT_EQUAL_INT32(expected_val, current->data[m][i]);
                        }
                    }
                    g_idx++;
                    if (g_idx == 2000) {
                        // Exit successfully
                        close(fd);
                        UnityConcludeTest();
                        _Exit(0);
                    }
                }
            }
        }
    }
}
