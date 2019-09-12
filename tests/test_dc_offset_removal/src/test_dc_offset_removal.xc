// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <xscope.h>

int data[4*THIRD_STAGE_COEFS_PER_STAGE*2] = {0};

int dc_elim_model(int32_t x, int32_t &prev_x, int64_t & y){
#define S 0
#define N 8
    int64_t X = x;
    int64_t prev_X = prev_x;

    y = y - (y>>8);

    prev_X<<=32;
    y = y - prev_X;

    X<<=32;
    y = y + X;

    prev_x = x;
    return (y>>(32-S));
}
#define DC_OFFSET 0xf123456
void test(){

    streaming chan c_pdm_to_dec;
    streaming chan c_ds_output[1];
    par {
        {
#define SINE_LENGTH 64
#define INPUT_SAMPLES (SINE_LENGTH*8)

            int one_khz_sine[INPUT_SAMPLES];
            int actual_dc_offset = DC_OFFSET;

            for(unsigned i=0;i<INPUT_SAMPLES;i++){
                one_khz_sine[i] = (int)((double)(FIRST_STAGE_MAX_PASSBAND_OUTPUT-actual_dc_offset)
                        *sin((double)i*M_PI*2.0 / (double)INPUT_SAMPLES) + actual_dc_offset);
            }

            while(1){
                for(unsigned i=0;i<INPUT_SAMPLES;i++){
                    c_pdm_to_dec <: one_khz_sine[i];
                    c_pdm_to_dec <: one_khz_sine[i];
                    c_pdm_to_dec <: one_khz_sine[i];
                    c_pdm_to_dec <: one_khz_sine[i];
                }
            }

        }

        mic_array_decimate_to_pcm_4ch(c_pdm_to_dec, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);

        {
            unsafe{
                mic_array_frame_time_domain audio[2];
                unsigned buffer;
                mic_array_decimator_conf_common_t dcc = {0, 1, 0, 0, 2, g_third_stage_div_2_fir, 0, FIR_COMPENSATOR_DIV_2, DECIMATOR_NO_FRAME_OVERLAP, 2  };
                mic_array_decimator_config_t dc[1] = { { &dcc, data, { INT_MAX, INT_MAX, INT_MAX, INT_MAX }, 4, 0}};
                mic_array_decimator_configure(c_ds_output, 1, dc);
                mic_array_init_time_domain_frame(c_ds_output, 1 , buffer, audio, dc);

                int32_t rolling_window[SINE_LENGTH] = {0};
                int64_t sum = 0;
                unsigned head = 0;

                int32_t prev_x = 0;
                unsigned count = 0;
                while(1){
                    mic_array_frame_time_domain *current = mic_array_get_next_time_domain_frame(c_ds_output, 1, buffer, audio, dc);
                    count++;
                    int32_t x = current->data[0][0];

                    //wait for DC to become zero
                    sum -= rolling_window[head];
                    sum += x;
                    rolling_window[head] = x;
                    head ++;
                    if(head == SINE_LENGTH)
                        head = 0;

                    int diff = x - prev_x;
                    if (diff < 0) diff = -diff;
                    if(diff > (INT_MAX/2)){
                        printf("Error: sine wrapped really hard\n");
                        _Exit(1);
                    }
                    prev_x=x;

                    int32_t abs_sum = sum;
                    if(abs_sum < 0)
                        abs_sum = -abs_sum;

                    if((count > 30)&&(abs_sum < (SINE_LENGTH*2))){
                        printf("Success!\n");
                        _Exit(1);
                    }

                }
            }
        }
    }

}

int main(){

    test();
    return 0;
}
