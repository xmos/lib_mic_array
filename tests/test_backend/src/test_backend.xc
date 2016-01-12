// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <xclib.h>
#include <math.h>
#include <stdlib.h>
#include <print.h>

static int pseudo_random(unsigned &x){
    crc32(x, -1, 0xEB31D82E);
    return (int)x;
}

static int filter(int coefs[], int data[], const unsigned length, const int val, unsigned &n){
    long long y = 0;
    data[0] = val;
    for (unsigned i=0; i<length; i++)
        y += (long long)coefs[i] * (long long)data[i];
    for (unsigned i=length-1; i>0; i--)
        data[i] = data[i-1];
    return y>>31;
}
#define DF 2

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];


void model(streaming chanend c_4x_pdm_mic_0,
  streaming chanend c_4x_pdm_mic_1, streaming chanend c_model){
    unsigned second_stage_n=0;
    unsigned third_stage_n=0;
    int second_stage_data[16]={0};
    int third_stage_data[32*DF]={0};
#if 0
    #define PI (3.141592653589793)
    while(1){
        int val;

        for(unsigned freq = 10; freq < 16000; freq+=10){
            unsigned output_sample_counter = 0;
            unsigned input_sample_counter = 0;
            while(output_sample_counter < (384000*2/freq + (THIRD_STAGE_COEFS_PER_STAGE)) ){

                for(unsigned r=0;r<DF;r++){
                    for(unsigned p=0;p<4;p++){
                        double theta = input_sample_counter * 2.0 * PI * freq / 384000;
                        int input_sample = (int)(INT_MAX * sin(theta));
                        for(unsigned i=0;i<4;i++){
                            c_4x_pdm_mic_0 <: input_sample;
                            c_4x_pdm_mic_1 <: input_sample;
                        }
                        input_sample_counter++;
                        val = filter(fir2_debug, second_stage_data, 16, input_sample, second_stage_n);
                    }
                    val = filter(fir3_48kHz_debug, third_stage_data, 32*DF, val, third_stage_n);
                }

                c_model <: val;

                output_sample_counter++;
            }
        }
        _Exit(1);
    }
#else
    unsigned x=0x1234;
    while(1){
        int val;
        while(1 ){
            for(unsigned r=0;r<DF;r++){
                for(unsigned p=0;p<4;p++){
                    int input_sample = pseudo_random(x);
                    for(unsigned i=0;i<4;i++){
                        c_4x_pdm_mic_0 <: input_sample;
                        c_4x_pdm_mic_1 <: input_sample;
                    }
                    val = filter(fir2_debug, second_stage_data, 16, input_sample, second_stage_n);
                }
                val = filter(fir3_48kHz_debug, third_stage_data, 32*DF, val, third_stage_n);
            }
            c_model <: val;
        }
    }
#endif
}
void output( streaming chanend c_ds_output[2], streaming chanend c_actual){
    unsigned buffer;
    unsafe {
        decimator_config_common dcc = {0, 0, 0, 0, 2, g_third_48kHz_fir, 0, 0};
        decimator_config dc[2] = {
                {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
                {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };
        decimator_configure(c_ds_output, 2, dc);
    }

   decimator_init_audio_frame(c_ds_output, 2, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);
   decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);
   decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);
   while(1){
        frame_audio *  current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);
        c_actual <: current->data[0][0];
    }
}


void verifier(streaming chanend c_model,
        streaming chanend c_actual){

    int max_diff = 0;
    int max = 0, min = -0;
    while(1){
        int m, a;
        c_model :> m;
        c_actual :> a;

        int diff = m-a;

        if(a > max){
            max = a;
            printf("%12d %12d %12d\n", min, max, max_diff);
        }
        if(a < min){
            min = a;
            printf("%12d %12d %12d\n", min, max, max_diff);
        }
        if(diff > max_diff){
            max_diff = diff;
            printf("%12d %12d %12d\n", min, max, max_diff);
        }
    }
}

int main(){

    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output[2];

    streaming chan c_model, c_actual;

    par {
        model(c_4x_pdm_mic_0, c_4x_pdm_mic_1, c_model);
        decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
        decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);
        output(c_ds_output, c_actual);
        verifier(c_model, c_actual);
     }
    return 0;
}
