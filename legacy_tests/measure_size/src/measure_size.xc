// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
dcc must match this.
#define DECIMATION_FACTOR 12
#define DECIMATOR_COUNT 4

int data[DECIMATOR_COUNT][4*THIRD_STAGE_COEFS_PER_STAGE*DECIMATION_FACTOR];

void example(streaming chanend c_ds_output[DECIMATOR_COUNT]) {
    unsafe{
        mic_array_frame_time_domain audio[DECIMATOR_COUNT];    //double buffered

        unsigned buffer;

        mic_array_decimator_conf_common_t dcc = {
                    0, // Frame size log 2 is set to 0, i.e. one sample per channel will be present in each frame
                    1, // DC offset elimination is turned on
                    0, // Index bit reversal is off
                    0, // No windowing function is being applied
                    DECIMATION_FACTOR,// The decimation factor is set to 6
                    g_third_stage_div_2_fir, // This corresponds to a 16kHz output hence this coef array is used
                    0, // Gain compensation is turned off
                    FIR_COMPENSATOR_DIV_2, // FIR compensation is set to the corresponding coefficients
                    DECIMATOR_NO_FRAME_OVERLAP, // Frame overlapping is turned off
                    2  // There are 2 buffers in the audio array
            };

        mic_array_decimator_config_t dc[DECIMATOR_COUNT];

        for(unsigned i=0;i<DECIMATOR_COUNT;i++){
            dc[i].async_interface_enabled = 0;
            dc[i].channel_count = 4;
            dc[i].data = data[i];
            dc[i].dcc = &dcc;
        }

        mic_array_decimator_configure(c_ds_output, DECIMATOR_COUNT, dc);

        mic_array_init_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        while(1){
            mic_array_frame_time_domain *  current =
                                mic_array_get_next_time_domain_frame(c_ds_output, DECIMATOR_COUNT, buffer, audio, dc);

        }
    }
}

int main(){
    streaming chan c_pdm_to_dec[4];
    streaming chan c_ds_output[DECIMATOR_COUNT];

    par{
        mic_array_pdm_rx(p_pdm_mics0, c_pdm_to_dec[0], c_pdm_to_dec[1]);
        mic_array_pdm_rx(p_pdm_mics1, c_pdm_to_dec[2], c_pdm_to_dec[3]);
        par(int i=0;i<DECIMATOR_COUNT;i++)
            mic_array_decimate_to_pcm_4ch(c_pdm_to_dec[i], c_ds_output[i], MIC_ARRAY_NO_INTERNAL_CHANS);
        example(c_ds_output);
    }
    return 0;
}
