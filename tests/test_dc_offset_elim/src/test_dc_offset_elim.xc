// Copyright (c) 2016, XMOS Ltd, All rights reserved

#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>
#include "mic_array.h"

#define MAX_DF 8

int data_0[4*COEFS_PER_PHASE*MAX_DF] = {0};
int data_1[4*COEFS_PER_PHASE*MAX_DF] = {0};
frame_audio audio[2];

void test_dc_offset(streaming chanend c_pcm_0,
        streaming chanend c_pcm_1, chanend c){

    unsigned buffer;
    unsigned frame_size_log2 = 0;

    //switch dc elim onn and test the dc preformance=
    for(unsigned t=0;t <= 0x40;t++){

        unsigned mask = t + (t<<8) + (t<<16) + (t<<24);

        c<: mask;

        for(unsigned df = 1; df <= 8; df++){

             unsafe {
                decimator_config_common dcc = {frame_size_log2, 1, 0, 0, df, fir_coefs[df], 0};
                decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
                decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
                decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
            }

            decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);
            unsigned samples = 0;
            unsigned zero_count = 0;
            int done = 0;
            while(!done){
                frame_audio *  current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
                samples++;

                if(current->data[0][0] == 0){
                    zero_count++;
                    if(zero_count == 4)
                        done = 1;
                } else {
                    zero_count = 0;
                }
                if(samples == 8192){
                    done = 1;
                    printf("ERROR: dc offset failed to converge for: decimation factor %d and input %d\n", df, t);
                }
            }
        }
    }

    //now switch dc offset elimination off and test that
    for(unsigned t=0;t <= 0x40;t++){

            unsigned mask = t + (t<<8) + (t<<16) + (t<<24);

            c<: mask;

            for(unsigned df = 1; df <= 8; df++){

                 unsafe {
                    decimator_config_common dcc = {frame_size_log2, 0, 0, 0, df, fir_coefs[df], 0};
                    decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
                    decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
                    decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
                }

                decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

                for(unsigned i=0;i<256;i++){
                     decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
                }
                frame_audio *  current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);

                int expected = (1<<30)/32 * (t-32);

                //TODO this could be improved to be more accurate
                if(t < 32){
                    if(current->data[0][0] >= 0){
                        printf("ERROR: dc offset not working correctly when turned off for: decimation factor %d and input  %d\n", df, t);
                    }
                } else  if(t == 32){
                    if(current->data[0][0] != 0){
                        printf("ERROR: dc offset not working correctly when turned off for: decimation factor %d and input  %d\n", df, t);
                    }
                } else  if(t > 32){
                    if(current->data[0][0] <= 0){
                        printf("ERROR: dc offset not working correctly when turned off for: decimation factor %d and input  %d\n", df, t);
                    }
                }
            }

        }



    printf("done\n");

    //TODO test performance

    _Exit(1);
}

int main(){
    chan c;
    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output_0, c_ds_output_1;
    par {
        {
            unsigned mask = 0;
            c:> mask;
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
        test_dc_offset(c_ds_output_0, c_ds_output_1, c);
    }
    return 0;
}
