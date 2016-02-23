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

extern void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

void create_DSD_source(streaming chanend c_not_a_port){

    double sampleRate = 3072000.0;
    double freq = 1000.0;
    int actual_integral = 0;
    double prevError = 0.0;

    unsigned s=0;
    while(1){
        unsigned data = 0;
        for(unsigned i=0;i<4;i++){
            double m =  freq * 2.0 *  PI / sampleRate;
            double perfect_integral = (1.0 - cos((double)s*m))/m;
            double error = (double)(actual_integral) - perfect_integral + prevError *0.1;

            prevError = error;

            data = data>>8;
            if(error <= 0.0){
                actual_integral += 1;
                data += 0xff000000;
            } else {
                actual_integral -= 1;
            }
            s++;
        }
        c_not_a_port <: data;
    }
}

void test_frontend(){
    streaming chan c_not_a_port, c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    par {
       create_DSD_source(c_not_a_port);
       pdm_rx_debug(c_not_a_port, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
       {
           FILE * movable fptr;
           fptr=fopen("pdm_output.txt","w");
           if(fptr==NULL){
               printf("Error!");
               exit(1);
           }
           unsigned count = 3072000/8;

           fprintf(fptr,"%d\n", count);
           fprintf(fptr,"%f\n", TEST_FREQUENCY);
           fprintf(fptr,"%d\n", count);

           for(unsigned i=0;i<64;i++){
               c_4x_pdm_mic_0 :> int;
               c_4x_pdm_mic_1 :> int;
           }
           for(unsigned j=0;j<count;j++){
               int a;
               for(unsigned i=0;i<4;i++){
                   c_4x_pdm_mic_0 :> a;
                   c_4x_pdm_mic_1 :> a;
               }
               fprintf(fptr,"%d\n", a);
               printf("%d\n", j);
           }
           fclose(move(fptr));
           _Exit(1);
       }
    }





}


int main(){
    test_frontend();
    //test_backend();
    return 0;
}
