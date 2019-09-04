#include "unity.h"
#include "math.h"
#include "string.h"
#include "stdlib.h"
#ifdef __XC__
#include "mic_array.h"
#include "frontend_debug.h"
#endif

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

            // Build frame_diff
            mic_array_frame_time_domain frame_diff;
            mic_array_frame_time_domain frame_zero;
            // Check that for indices 0 <= i < frame_size
            // That all values are different between frames
            for (int m=0; m<MIC_ARRAY_NUM_MICS; m++) {
                for (int i=0; i<MIC_ARRAY_FRAME_SIZE; i++) {
                    frame_diff.data[m][i] = (frame_0.data[m][i] == frame_1.data[m][i]);
                    frame_zero.data[m][i] = 0;
                }
            }

            unsafe {
                TEST_ASSERT_EQUAL_INT32_ARRAY_MESSAGE(frame_zero.data[0], frame_diff.data[0], MIC_ARRAY_FRAME_SIZE, "Mic 0");
                TEST_ASSERT_EQUAL_INT32_ARRAY_MESSAGE(frame_zero.data[1], frame_diff.data[1], MIC_ARRAY_FRAME_SIZE, "Mic 1");
                TEST_ASSERT_EQUAL_INT32_ARRAY_MESSAGE(frame_zero.data[2], frame_diff.data[2], MIC_ARRAY_FRAME_SIZE, "Mic 2");
                TEST_ASSERT_EQUAL_INT32_ARRAY_MESSAGE(frame_zero.data[3], frame_diff.data[3], MIC_ARRAY_FRAME_SIZE, "Mic 3");
            }

            UnityConcludeTest();
            _Exit(0);

        }
    }
}
