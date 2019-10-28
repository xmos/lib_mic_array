// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>


#include "mic_array.h"

int data[4][THIRD_STAGE_COEFS_PER_STAGE*12];


int window_fn(unsigned i, unsigned window_length){
    return((int)((double)INT_MAX*sqrt(0.5*(1.0 - cos(2.0 * 3.14159265359*(double)i / (double)(window_length-2))))));
}

void run_test(streaming chanend c_ds_output[1], unsigned frames,
        mic_array_decimator_buffering_t buffering, int * window, unsigned DC,
        const int * unsafe coefs, unsigned comp){

    int max_overestimation = 0;
    unsafe{
        mic_array_frame_time_domain audio[4];

        unsigned buffer;     //buffer index
        memset(data, 0, sizeof(data));

        //This will only work for a decimation factor of above 2
        mic_array_decimator_conf_common_t dcc = {
                MIC_ARRAY_MAX_FRAME_SIZE_LOG2,
                0,
                0,
                window,
                DC,
                coefs,
                0,
                comp,
                buffering,
                frames};
        mic_array_decimator_config_t dc[1] = {{&dcc, data[0], {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4, 0}};

        mic_array_decimator_configure(c_ds_output, 1, dc);

        mic_array_init_time_domain_frame(c_ds_output, 1, buffer, audio, dc);

        for(unsigned i=0;i<1<<2;i++){

            mic_array_frame_time_domain * c = mic_array_get_next_time_domain_frame(c_ds_output, 1, buffer, audio, dc);

            unsigned mask[4] = {0};

            for(unsigned i=0;i<1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2;i++){
                for(unsigned m=0;m<4;m++){
                    int v = c->data[m][i];
                    if (v<0)v=-v;
                    mask[m] |= v;
                }
            }

            for(unsigned i=0;i<4;i++){
                unsigned actual =  clz(mask[i]);
                unsigned result =  clz(c->metadata[0].sig_bits[i]);
                unsigned over = actual - result;
                if (over > max_overestimation)
                    max_overestimation = over;
            }
        }
    }
    if((max_overestimation) >= 0 && (max_overestimation < 12)){
        printf("Pass\n");
    } else {
        printf("Fail %d\n", max_overestimation);
    }
}


void check_metadata(streaming chanend c_ds_output[1]){
    int window[1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2-1)];
    for(unsigned i=0;i<(1<<(MIC_ARRAY_MAX_FRAME_SIZE_LOG2-1));i++)
         window[i] = window_fn(i, 1<<MIC_ARRAY_MAX_FRAME_SIZE_LOG2);


    run_test(c_ds_output, 2, DECIMATOR_NO_FRAME_OVERLAP, 0, 4, g_third_stage_div_4_fir, FIR_COMPENSATOR_DIV_4);
    run_test(c_ds_output, 3, DECIMATOR_NO_FRAME_OVERLAP, 0, 4, g_third_stage_div_4_fir, FIR_COMPENSATOR_DIV_4);
    run_test(c_ds_output, 2, DECIMATOR_NO_FRAME_OVERLAP, window, 4, g_third_stage_div_4_fir, FIR_COMPENSATOR_DIV_4);
    run_test(c_ds_output, 3, DECIMATOR_NO_FRAME_OVERLAP, window, 4, g_third_stage_div_4_fir, FIR_COMPENSATOR_DIV_4);
    run_test(c_ds_output, 3, DECIMATOR_HALF_FRAME_OVERLAP, 0, 4, g_third_stage_div_4_fir, FIR_COMPENSATOR_DIV_4);
    run_test(c_ds_output, 4, DECIMATOR_HALF_FRAME_OVERLAP, 0, 4, g_third_stage_div_4_fir, FIR_COMPENSATOR_DIV_4);
    run_test(c_ds_output, 3, DECIMATOR_HALF_FRAME_OVERLAP, window, 4, g_third_stage_div_4_fir, FIR_COMPENSATOR_DIV_4);
    run_test(c_ds_output, 4, DECIMATOR_HALF_FRAME_OVERLAP, window, 4, g_third_stage_div_4_fir, FIR_COMPENSATOR_DIV_4);

    run_test(c_ds_output, 2, DECIMATOR_NO_FRAME_OVERLAP, 0, 6, g_third_stage_div_6_fir, FIR_COMPENSATOR_DIV_6);
    run_test(c_ds_output, 3, DECIMATOR_NO_FRAME_OVERLAP, 0, 6, g_third_stage_div_6_fir, FIR_COMPENSATOR_DIV_6);
    run_test(c_ds_output, 2, DECIMATOR_NO_FRAME_OVERLAP, window, 6, g_third_stage_div_6_fir, FIR_COMPENSATOR_DIV_6);
    run_test(c_ds_output, 3, DECIMATOR_NO_FRAME_OVERLAP, window, 6, g_third_stage_div_6_fir, FIR_COMPENSATOR_DIV_6);
    run_test(c_ds_output, 3, DECIMATOR_HALF_FRAME_OVERLAP, 0, 6, g_third_stage_div_6_fir, FIR_COMPENSATOR_DIV_6);
    run_test(c_ds_output, 4, DECIMATOR_HALF_FRAME_OVERLAP, 0, 6, g_third_stage_div_6_fir, FIR_COMPENSATOR_DIV_6);
    run_test(c_ds_output, 3, DECIMATOR_HALF_FRAME_OVERLAP, window, 6, g_third_stage_div_6_fir, FIR_COMPENSATOR_DIV_6);
    run_test(c_ds_output, 4, DECIMATOR_HALF_FRAME_OVERLAP, window, 6, g_third_stage_div_6_fir, FIR_COMPENSATOR_DIV_6);

    run_test(c_ds_output, 2, DECIMATOR_NO_FRAME_OVERLAP, 0, 8, g_third_stage_div_8_fir, FIR_COMPENSATOR_DIV_8);
    run_test(c_ds_output, 3, DECIMATOR_NO_FRAME_OVERLAP, 0, 8, g_third_stage_div_8_fir, FIR_COMPENSATOR_DIV_8);
    run_test(c_ds_output, 2, DECIMATOR_NO_FRAME_OVERLAP, window, 8, g_third_stage_div_8_fir, FIR_COMPENSATOR_DIV_8);
    run_test(c_ds_output, 3, DECIMATOR_NO_FRAME_OVERLAP, window, 8, g_third_stage_div_8_fir, FIR_COMPENSATOR_DIV_8);
    run_test(c_ds_output, 3, DECIMATOR_HALF_FRAME_OVERLAP, 0, 8, g_third_stage_div_8_fir, FIR_COMPENSATOR_DIV_8);
    run_test(c_ds_output, 4, DECIMATOR_HALF_FRAME_OVERLAP, 0, 8, g_third_stage_div_8_fir, FIR_COMPENSATOR_DIV_8);
    run_test(c_ds_output, 3, DECIMATOR_HALF_FRAME_OVERLAP, window, 8, g_third_stage_div_8_fir, FIR_COMPENSATOR_DIV_8);
    run_test(c_ds_output, 4, DECIMATOR_HALF_FRAME_OVERLAP, window, 8, g_third_stage_div_8_fir, FIR_COMPENSATOR_DIV_8);

    run_test(c_ds_output, 2, DECIMATOR_NO_FRAME_OVERLAP, 0, 12, g_third_stage_div_12_fir, FIR_COMPENSATOR_DIV_12);
    run_test(c_ds_output, 3, DECIMATOR_NO_FRAME_OVERLAP, 0, 12, g_third_stage_div_12_fir, FIR_COMPENSATOR_DIV_12);
    run_test(c_ds_output, 2, DECIMATOR_NO_FRAME_OVERLAP, window, 12, g_third_stage_div_12_fir, FIR_COMPENSATOR_DIV_12);
    run_test(c_ds_output, 3, DECIMATOR_NO_FRAME_OVERLAP, window, 12, g_third_stage_div_12_fir, FIR_COMPENSATOR_DIV_12);
    run_test(c_ds_output, 3, DECIMATOR_HALF_FRAME_OVERLAP, 0, 12, g_third_stage_div_12_fir, FIR_COMPENSATOR_DIV_12);
    run_test(c_ds_output, 4, DECIMATOR_HALF_FRAME_OVERLAP, 0, 12, g_third_stage_div_12_fir, FIR_COMPENSATOR_DIV_12);
    run_test(c_ds_output, 3, DECIMATOR_HALF_FRAME_OVERLAP, window, 12, g_third_stage_div_12_fir, FIR_COMPENSATOR_DIV_12);
    run_test(c_ds_output, 4, DECIMATOR_HALF_FRAME_OVERLAP, window, 12, g_third_stage_div_12_fir, FIR_COMPENSATOR_DIV_12);

    _Exit(1);
}


static int pseudo_random(unsigned &x){
    crc32(x, -1, 0xEB31D82E);
    return (int)x;
}

int main(){

    streaming chan c_4x_pdm_mic_0;
    streaming chan c_ds_output[1];

    par{
        {
            unsigned x = 0x1;
            while(1) c_4x_pdm_mic_0 <: pseudo_random(x);
        }
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        check_metadata(c_ds_output);
    }

    return 0;
}
