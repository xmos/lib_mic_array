// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>
#include <math.h>
#include <xscope.h>

int data[4*THIRD_STAGE_COEFS_PER_STAGE*2] = {0};
frame_audio audio[2];

int dc_elim_model(int x, int &prev_x, long long & y){
    y = y - (y>>8);
    y = y - prev_x;
    y = y + x;
    prev_x = x;
    return (y>>8);
}

void test(){

    streaming chan c_pdm_to_dec;
    streaming chan c_ds_output[1];
    par {
        {
#define SINE_LENGTH 64
#define INPUT_SAMPLES (SINE_LENGTH*8)

            int one_khz_sine[INPUT_SAMPLES];
            int actual_dc_offset = 0;
            for(unsigned i=0;i<INPUT_SAMPLES;i++){
                one_khz_sine[i] = (int)((double)(INT_MAX-actual_dc_offset)
                        *sin((double)i*3.1415926535*2.0 / (double)INPUT_SAMPLES) + actual_dc_offset);
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

        decimate_to_pcm_4ch(c_pdm_to_dec, c_ds_output[0]);

        {
            unsafe{
                unsigned buffer;
                decimator_config_common dcc = {0, 1, 0, 0, 2, g_third_stage_div_2_fir, 0, 0, DECIMATOR_NO_FRAME_OVERLAP, 2  };
                decimator_config dc[1] = { { &dcc, data, { INT_MAX, INT_MAX, INT_MAX, INT_MAX },4 }};
                decimator_configure(c_ds_output, 1, dc);
                decimator_init_audio_frame(c_ds_output, 1 , buffer, audio, dcc);

                long long rolling_window[SINE_LENGTH] = {0};
                long long sum = 0;
                unsigned head = 0;

                int prev_x = 0;
                unsigned count = 0;
                while(1){
                    frame_audio *current = decimator_get_next_audio_frame(c_ds_output, 1, buffer, audio, dcc);
                    count++;
                    int x = current->data[0][0];

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
                        printf("Error: sine rapped really hard\n");
                        _Exit(1);
                    }
                    prev_x=x;

                    if((count > 3)&&(sum == 0)){
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
