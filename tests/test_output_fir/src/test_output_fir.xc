// Copyright (c) 2015, XMOS Ltd, All rights reserved

#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>
#include "mic_array.h"

#define DOIT(N)\
    {\
    abs_max = 0;\
    min_sum = 0;\
    max_sum = 0;\
    for(unsigned i=0;i<N;i++){\
        for(unsigned j=0;j<48;j++){\
            int64_t c = (int64_t)fir_ ## N ##_coefs[i][j];\
            int64_t p = ((int64_t)pos_max*c);\
            int64_t n = ((int64_t)neg_max*c);\
            if (p > 0) abs_max += p;\
            else abs_max -= p;\
            max_sum += p;\
            min_sum += n;\
        }\
    }\
    int am = lextract(abs_max, 30, 32);\
    int smax_sum = lextract(max_sum, 30, 32);\
    int smin_sum = lextract(min_sum, 30, 32);\
    if((INT_MAX - am) < 0xff) printf("decimation factor: %d SUCCESS\n", N);\
    else printf("decimation factor: %d FAILURE\n", N);\
    expected_max[N-1] = smax_sum;\
    expected_min[N-1] = smin_sum;\
    }

#define MAX_DF 8

int data_0[4*COEFS_PER_PHASE*MAX_DF] = {0};
int data_1[4*COEFS_PER_PHASE*MAX_DF] = {0};
frame_audio audio[2];

void example(streaming chanend c_pcm_0,
        streaming chanend c_pcm_1, chanend c){

    int32_t max_input_to_fir = 1<<30;
    int32_t min_input_to_fir = 0;

    int64_t abs_max = 0;
    int64_t min_sum = 0;
    int64_t max_sum = 0;

    int expected_max[9];
    int expected_min[9];

    int32_t pos_max = max_input_to_fir - (max_input_to_fir- min_input_to_fir)/2;
    int32_t neg_max = min_input_to_fir - (max_input_to_fir- min_input_to_fir)/2;

    printf("Non-overflow + full scale usage ztest\n");
    DOIT(1);
    DOIT(2);
    DOIT(3);
    DOIT(4);
    DOIT(5);
    DOIT(6);
    DOIT(7);
    DOIT(8);

    unsigned buffer;
    unsigned frame_size_log2 = 0;

    printf("Full scale positive test\n");
    for(unsigned df = 1; df <=8;df++){

         unsafe {
            decimator_config_common dcc = {frame_size_log2, 0, 0, 0, df, fir_coefs[df], 0};
            decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
            decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
            decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
        }

        decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

        for(unsigned i=0;i<256;i++)
           decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);

        frame_audio *  current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
        if( current->data[0][0] == expected_max[df-1]){
            printf("decimation factor: %d SUCCESS\n", df);
        } else {
            printf("decimation factor: %d FAILURE\n", df);
        }

    }
    printf("Full scale negative test\n");
    c<: 0;
    for(unsigned df = 1; df <=8;df++){

         unsafe {
            decimator_config_common dcc = {frame_size_log2, 0, 0, 0, df, fir_coefs[df], 0};
            decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
            decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
            decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
        }

        decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

        for(unsigned i=0;i<256;i++)
           decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);

        frame_audio *  current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
        if( current->data[0][0] == expected_min[df-1]){
            printf("decimation factor: %d SUCCESS\n", df);
        } else {
            printf("decimation factor: %d FAILURE\n", df);
        }


    }
    printf("Zero test\n");
    c<: 0x20202020;
    for(unsigned df = 1; df <=8;df++){

         unsafe {
            decimator_config_common dcc = {frame_size_log2, 0, 0, 0, df, fir_coefs[df], 0};
            decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
            decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
            decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
        }

        decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

        for(unsigned i=0;i<256;i++)
           decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);

        frame_audio *  current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
        if( current->data[0][0] == 0){
            printf("decimation factor: %d SUCCESS\n", df);
        } else {
            printf("decimation factor: %d FAILURE\n", df);
        }


    }

    _Exit(1);
}

int main(){
    chan c;
    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output_0, c_ds_output_1;

    par {
        {
            unsigned mask = 0x40404040;
            while(1){
                c_4x_pdm_mic_0 <: mask;
                c_4x_pdm_mic_1 <: mask;
                select {
                    case c:> mask: break;
                    default: break;
                }
            }
        }
        decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
        decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);
        example(c_ds_output_0, c_ds_output_1, c);
    }
    return 0;
}
