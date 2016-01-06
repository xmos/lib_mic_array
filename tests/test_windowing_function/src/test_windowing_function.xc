// Copyright (c) 2015, XMOS Ltd, All rights reserved

#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <limits.h>
#include <string.h>
#include "mic_array.h"
#include <xclib.h>

#define MAX_DF 8

int data_0[4*COEFS_PER_PHASE*MAX_DF] = {0};
int data_1[4*COEFS_PER_PHASE*MAX_DF] = {0};
frame_audio audio[3];

int expect[8] = { 1076297581, 1136204458, 1054197584, 1028568473,
        1017121881, 1010985186, 1007299976, 1004907394 };

void test_windowing_function(streaming chanend c_pcm_0,
        streaming chanend c_pcm_1){

    unsigned buffer;
    unsigned reps = 1;

    for(unsigned frame_size_log2=2;frame_size_log2<=FRAME_SIZE_LOG2; frame_size_log2++){
        int window[1<<(FRAME_SIZE_LOG2-1)];
        memset(window, 0, sizeof(int)*(1<<(FRAME_SIZE_LOG2-1)));
        for(unsigned pass = 0;pass < 3;pass++){

            for(unsigned df = 1; df <= 8; df++){
                if (pass == 0){
                    for(unsigned i=0;i<1<<(frame_size_log2-1);i++){
                        int64_t w = (int64_t)INT_MAX;
                        w=w*i;
                        w=w>>(frame_size_log2-1);
                        window[i] = ((int64_t)INT_MAX*(i+1))>>(frame_size_log2-1);
                    }
                } else if (pass == 1){
                    for(unsigned i=0;i<1<<(frame_size_log2-1);i++)
                        window[i] = INT_MAX;
                } else if (pass == 2){
                    for(unsigned i=0;i<1<<(frame_size_log2-1);i++)
                        window[i] = 0;
                }
                 unsafe {
                    decimator_config_common dcc = {frame_size_log2, 0, 0, window, df, fir_coefs[df], 0};
                    decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
                    decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
                    decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
                }
                memset(audio, 0, sizeof(frame_audio)*3);
                memset(data_0, 0, sizeof(int)*4*COEFS_PER_PHASE*MAX_DF);
                memset(data_1, 0, sizeof(int)*4*COEFS_PER_PHASE*MAX_DF);
                decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

                //flush through the transient part, leaving just the dc.
                for(unsigned i=0;i<32;i++)
                    decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, 2);

                for(unsigned i=0;i<reps;i++){
                    frame_audio * current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, 2);
                    for(unsigned j=0;j<1<<frame_size_log2;j++){
                        int all_the_channels_same = 1;
                        int data=0;
                        for(unsigned m=0;m<8;m++){
                            int x = current->data[m][j];
                            data |= x;
                            all_the_channels_same &= (data == x);
                        }
                        if(!all_the_channels_same){
                            printf("Not all channels are the same df:%d, sample %d\n", df, i);
                            for(unsigned c=0;c<8;c++)
                                printf("%14d ", current->data[c][j]);
                            printf("\n");
                        }

                        if (pass == 0){
                            unsigned b = (1<<frame_size_log2) - 1;
                            unsigned k=j;
                            if(b < j*2)
                                k = b - j;
                            uint64_t w = (uint64_t)window[k];
                            w = w * expect[df-1];
                            w = w >> 31;
                            int diff = data - (int32_t)w;
                            if (diff < 0) diff = -diff;

                            if(diff > 3){
                                printf("ERROR: Frame size %d, decimation factor %d expected:%d got:%d\n",
                                       1<<frame_size_log2, df, (int32_t)w, data);
                                _Exit(1);
                            }
                        } else if (pass == 1){
                            int diff = data - expect[df-1];
                            if (diff < 0) diff = -diff;
                            if(diff > 3){
                                printf("ERROR: Frame size %d, decimation factor %d expected:%d got:%d\n",
                                        1<<frame_size_log2, df, expect[df-1], data);
                                _Exit(1);
                            }
                        } else if (pass == 2){
                            int diff = data - 0;
                            if (diff < 0) diff = -diff;
                            if(diff > 3){
                                printf("ERROR: Frame size %d, decimation factor %d expected:%d got:%d\n",
                                        1<<frame_size_log2, df, expect[df-1], data);
                                _Exit(1);
                            }
                        }
                    }
                }
                printf("Decimation factor %d: PASS\n", df);
            }
        }

        for(unsigned pass = 0;pass < 3;pass++){
            for(unsigned df = 1; df <= 8; df++){
                if (pass == 0){
                    for(unsigned i=0;i<1<<(frame_size_log2-1);i++){
                        int64_t w = (int64_t)INT_MAX;
                        w=w*i;
                        w=w>>(frame_size_log2-1);
                        window[i] = ((int64_t)INT_MAX*(i+1))>>(frame_size_log2-1);
                    }
                } else if (pass == 1){
                    for(unsigned i=0;i<1<<(frame_size_log2-1);i++)
                        window[i] = INT_MAX;
                } else if (pass == 2){
                    for(unsigned i=0;i<1<<(frame_size_log2-1);i++)
                        window[i] = 0;
                }
                 unsafe {
                    decimator_config_common dcc = {frame_size_log2, 0, 0, window, df, fir_coefs[df], 0};
                    decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
                    decimator_config dc1 = {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
                    decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
                }
                memset(audio, 0, sizeof(frame_audio)*3);
                memset(data_0, 0, sizeof(int)*4*COEFS_PER_PHASE*MAX_DF);
                memset(data_1, 0, sizeof(int)*4*COEFS_PER_PHASE*MAX_DF);
                decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_HALF_FRAME_OVERLAP);

                //flush through the transient part, leaving just the dc.
                for(unsigned i=0;i<32;i++)
                    decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, 3);

                for(unsigned i=0;i<reps;i++){
                    frame_audio * current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, 3);
                    for(unsigned j=0;j<1<<frame_size_log2;j++){
                        int all_the_channels_same = 1;
                        int data=0;
                        for(unsigned m=0;m<8;m++){
                            int x = current->data[m][j];
                            data |= x;
                            all_the_channels_same &= (data == x);
                        }
                        if(!all_the_channels_same){
                            printf("Not all channels are the same df:%d, sample %d\n", df, i);
                            for(unsigned c=0;c<8;c++)
                                printf("%14d ", current->data[c][j]);
                            printf("\n");
                        }

                        if (pass == 0){
                            unsigned b = (1<<frame_size_log2) - 1;
                            unsigned k=j;
                            if(b < j*2)
                                k = b - j;
                            uint64_t w = (uint64_t)window[k];
                            w = w * expect[df-1];
                            w = w >> 31;
                            int diff = data - (int32_t)w;
                            if (diff < 0) diff = -diff;

                            if(diff > 3){
                                printf("ERROR: Frame size %d, decimation factor %d expected:%d got:%d\n",
                                       1<<frame_size_log2, df, (int32_t)w, data);
                                //_Exit(1);
                            }
                        } else if (pass == 1){
                            int diff = data - expect[df-1];
                            if (diff < 0) diff = -diff;
                            if(diff > 3){
                                printf("ERROR: Frame size %d, decimation factor %d expected:%d got:%d\n",
                                        1<<frame_size_log2, df, expect[df-1], data);
                               // _Exit(1);
                            }
                        } else if (pass == 2){
                            int diff = data - 0;
                            if (diff < 0) diff = -diff;
                            if(diff > 3){
                                printf("ERROR: Frame size %d, decimation factor %d expected:%d got:%d\n",
                                        1<<frame_size_log2, df, expect[df-1], data);
                               // _Exit(1);
                            }
                        }
                    }
                }
                printf("Decimation factor %d: PASS\n", df);
            }
        }
        printf("Frame size %d: PASS\n", 1<< frame_size_log2);
    }

    _Exit(1);
}

int main(){
    streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    streaming chan c_ds_output_0, c_ds_output_1;
    par {
        par(int i=0;i<4;i++)while(1);
        {
            unsigned mask = 0x40404040;
            while(1){
                    c_4x_pdm_mic_0 <: mask;
                    c_4x_pdm_mic_1 <: mask;
            }
        }
        decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
        decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);
        test_windowing_function(c_ds_output_0, c_ds_output_1);
    }
    return 0;
}
