// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>
#include <math.h>

//the frequency under test
#define TEST_FREQUENCY 1000.0
#define SAMPLE_RATE 384000.0

#define SAMPLE_COUNT (384000)
#define PI (3.1415926535897932384626433832795028)
#define OMEGA (2.0*PI*TEST_FREQUENCY/SAMPLE_RATE)

int data[4*THIRD_STAGE_COEFS_PER_STAGE*12] = {0};
void test_backend(){

    frame_audio audio[2];
    streaming chan c_pdm_to_dec;
    streaming chan c_ds_output[1];

    par {
        {
            FILE * movable fptr;
            fptr=fopen("input.txt","w");
            if(fptr==NULL){
                printf("Error!");
                exit(1);
            }

            fprintf(fptr,"%f\n", SAMPLE_RATE);
            fprintf(fptr,"%f\n", TEST_FREQUENCY);
            fprintf(fptr,"%d\n", SAMPLE_COUNT);

            unsigned i=0;
            for(i=0;i<SAMPLE_COUNT;i++){
                int s = (int) ((double)INT_MAX * sin((double)i * OMEGA));
                for(unsigned c=0;c<4;c++)
                    c_pdm_to_dec <: s;
                fprintf(fptr,"%d\n", s);
            }
            fclose(move(fptr));

            while(1){
                double theta = (double)i * OMEGA;
                int s = (int) ((double)INT_MAX * sin(theta));
                for(unsigned c=0;c<4;c++)
                    c_pdm_to_dec <: s;
                i++;
            }
        }
        decimate_to_pcm_4ch(c_pdm_to_dec, c_ds_output[0]);
        {
            unsafe{
                unsigned divider_lut[5] = {2, 4, 6, 8, 12};
                 const int * unsafe coef_lut[5] = {
                        g_third_stage_div_2_fir,
                        g_third_stage_div_4_fir,
                        g_third_stage_div_6_fir,
                        g_third_stage_div_8_fir,
                        g_third_stage_div_12_fir
                };
                char names_lut[5][20] = {
                        "div_2_fir.txt",
                        "div_4_fir.txt",
                        "div_6_fir.txt",
                        "div_8_fir.txt",
                        "div_12_fir.txt",
                };

                for(unsigned div_index=0;div_index<5;div_index++){
                    FILE * movable fptr;
                    fptr=fopen(names_lut[div_index],"w");
                    if(fptr==NULL){
                        printf("Error!");
                        exit(1);
                    }
                    unsigned buffer;
                    unsigned divider = divider_lut[div_index];
                    unsigned count = SAMPLE_COUNT/(4*divider);

                    fprintf(fptr,"%f\n", SAMPLE_RATE/(4.0*(double)divider));
                    fprintf(fptr,"%f\n", TEST_FREQUENCY);
                    fprintf(fptr,"%d\n", count);

                    decimator_config_common dcc = {0, 0, 0, 0, divider, coef_lut[div_index], 0, 0, DECIMATOR_NO_FRAME_OVERLAP, 2  };
                    decimator_config dc[1] = { { &dcc, data, { INT_MAX, INT_MAX, INT_MAX, INT_MAX },4 }};
                    decimator_configure(c_ds_output, 1, dc);
                    decimator_init_audio_frame(c_ds_output, 1 , buffer, audio, dcc);

                    //first wait until the filter delay has passed
                    for(unsigned i=0;i<64;i++)
                        decimator_get_next_audio_frame(c_ds_output, 1, buffer, audio, dcc);

                    for(unsigned i=0;i<count;i++){
                        frame_audio *current = decimator_get_next_audio_frame(c_ds_output, 1, buffer, audio, dcc);
                        fprintf(fptr,"%d\n", current->data[0][0]);
                    }
                    fclose(move(fptr));
                }
                _Exit(0);
            }
        }
    }
}

int main(){
    test_backend();
    return 0;
}
