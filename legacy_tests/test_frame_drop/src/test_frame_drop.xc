// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <string.h>
#include "mic_array.h"

#define DF 2    //Decimation Factor

int data[8][4*THIRD_STAGE_COEFS_PER_STAGE*DF];

void test_output(streaming chanend c_ds_output[2]){

    memset(data, 0, sizeof(data));
    mic_array_frame_time_domain audio[2];

    unsafe{
        unsigned buffer;     //buffer index
        memset(audio, sizeof(mic_array_frame_time_domain), 0);

        mic_array_decimator_conf_common_t dcc = {MIC_ARRAY_MAX_FRAME_SIZE_LOG2, 1, 0, 0, DF,
                g_third_stage_div_2_fir, 0, FIR_COMPENSATOR_DIV_2,
                DECIMATOR_NO_FRAME_OVERLAP, 2};
        mic_array_decimator_config_t dc[2] = {
                    {&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0},
                    {&dcc, data[4], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0}
            };
        mic_array_decimator_configure(c_ds_output, 2, dc);

        mic_array_init_time_domain_frame(c_ds_output, 2, buffer, audio, dc);

        //This test that if ready there is no exception
        for(unsigned i=0;i<64;i++)
            mic_array_get_next_time_domain_frame(c_ds_output, 2, buffer, audio, dc);
        printstrln("Normal case: Pass");


        //This test that if not ready there is an exception
        for(unsigned i=0;i<4;i++){
            mic_array_frame_time_domain *  current = mic_array_get_next_time_domain_frame(c_ds_output, 2, buffer, audio, dc);
            delay_milliseconds(1);
        }
        printstrln("Fail case: Fail");
    }
}

int main(){

    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output[2];
    par{
        while(1){
            c_4x_pdm_mic_0 <: 0x55555555;
            c_4x_pdm_mic_1 <: 0x55555555;
        }
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1], MIC_ARRAY_NO_INTERNAL_CHANS);
        test_output(c_ds_output);
        par(int i=0;i<4;i++)while(1);
    }
    return 0;
}
