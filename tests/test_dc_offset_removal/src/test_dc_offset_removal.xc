// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>
#include <math.h>
#include <xscope.h>

int data[4*THIRD_STAGE_COEFS_PER_STAGE*2] = {0};
frame_audio audio[2];

void test(){

    streaming chan c_pdm_to_dec;
    streaming chan c_ds_output[1];
    par {
        {
#define SINE_LENGTH 64
#define INPUT_SAMPLES (SINE_LENGTH*8)
            int one_khz_sine[INPUT_SAMPLES];

            int actual_dc_offset = 1020983;
            for(unsigned i=0;i<INPUT_SAMPLES;i++)
                one_khz_sine[i] = (int)((double)(INT_MAX-actual_dc_offset)
                        *sin((double)i*3.1415926535*2.0 / (double)INPUT_SAMPLES) + actual_dc_offset);

            while(1){
                for(unsigned i=0;i<INPUT_SAMPLES;i++){
                    c_pdm_to_dec <: one_khz_sine[i];
                    c_pdm_to_dec <: one_khz_sine[i];
                    c_pdm_to_dec <: one_khz_sine[i];
                    c_pdm_to_dec <: one_khz_sine[i];
                }
            }

            _Exit(0);
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

                long long y = 0;
                int prev_x = 0;

                unsigned count = 0;
                while(1){
                    frame_audio *current = decimator_get_next_audio_frame(c_ds_output, 1, buffer, audio, dcc);
                    count++;
                    int x = current->data[0][0];
#if 0
                    long long X = (long long)x;
                    long long prev_X = (long long)prev_x;

                    long long t = X - prev_X;
                    y = y - (y>>13);
                    y = y + (t<<16);
                    prev_x = x;
                    int d = y>>16;
#else
                    int d = x;
#endif

                    sum -= rolling_window[head];
                    sum += d;
                    rolling_window[head] = d;
                    head ++;
                    if(head == SINE_LENGTH)
                        head = 0;

                    if((count > 3)&&((sum/SINE_LENGTH) == 0)){
                      //  printf("Success!\n");
                      //_Exit(1);
                    }
                    xscope_int(0, d);

                }
            }
        }
    }

}

int main(){

    test();
    return 0;
}
