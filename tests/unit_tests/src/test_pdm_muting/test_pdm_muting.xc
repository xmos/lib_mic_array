// Copyright (c) 2019, XMOS Ltd, All rights reserved
#include "unity.h"
#include "math.h"
#include "string.h"
#include "stdlib.h"
#include "mic_array.h"
#include "frontend_debug.h"

void test_pdm_muting() {
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

            //first wait until the filter delay has passed
            for(unsigned i=0;i<64;i++) {
                mic_array_get_next_time_domain_frame(
                    c_ds_output, MIC_DECIMATORS, mic_buffer_index,
                    audio_frame, decimator_config);
            }

            unsigned x;
            mic_array_frame_time_domain frame_0;
            mic_array_frame_time_domain frame_1;

            mic_array_frame_time_domain *current;

            // Get frame_0
            current = mic_array_get_next_time_domain_frame(
                    c_ds_output, MIC_DECIMATORS, mic_buffer_index,
                    audio_frame, decimator_config);
            memcpy(&frame_0, current, sizeof(mic_array_frame_time_domain));

            // Get frame_1
            current = mic_array_get_next_time_domain_frame(
                    c_ds_output, MIC_DECIMATORS, mic_buffer_index,
                    audio_frame, decimator_config);
            memcpy(&frame_1, current, sizeof(mic_array_frame_time_domain));

            mic_array_frame_time_domain frame_zero;
            // Check that for indices 0 <= i < frame_size
            // All values of muted mic == 0
            // And at least one value for non-muted mics is non-zero
            int all_zero[4] = {1};
            for (int m=0; m<MIC_ARRAY_NUM_MICS; m++) {
                for (int i=0; i<MIC_ARRAY_FRAME_SIZE; i++) {
                    frame_zero.data[m][i] = 0;
                    all_zero[m] = all_zero[m] && frame_0.data[m][i];
                }
            }

            TEST_ASSERT_EQUAL_INT32_MESSAGE(0, all_zero[1], "Mic 0 not muted");
            unsafe {
                TEST_ASSERT_EACH_EQUAL_INT32_MESSAGE(0, frame_0.data[1], MIC_ARRAY_FRAME_SIZE, "Mic 1 muted");
            }
            TEST_ASSERT_EQUAL_INT32_MESSAGE(0, all_zero[2], "Mic 2 not muted");
            TEST_ASSERT_EQUAL_INT32_MESSAGE(0, all_zero[3], "Mic 3 not muted");

            UnityConcludeTest();
            _Exit(0);

        }
    }
}
