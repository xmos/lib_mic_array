// Copyright (c) 2016-2019, XMOS Ltd, All rights reserved
#include "mic_array.h"
#include <stdio.h>
#include <xs1.h>
#include <stdlib.h>
#include <math.h>
#include  <xscope.h>

//the frequency under test
#define TEST_FREQUENCY      (1000.0)
#define SAMPLE_RATE         (384000.0)
#define PDM_SAMPLE_RATE     (3072000.0)

#define SAMPLE_COUNT        (384000)
#define PI                  (3.1415926535897932384626433832795028)
#define OMEGA               (2.0*PI*TEST_FREQUENCY/SAMPLE_RATE)

int data[4*THIRD_STAGE_COEFS_PER_STAGE*12] = {0};

#define OUTPUT_BACKEND_INPUT        0
#define OUTPUT_BACKEND_OUTPUT       1

#define OUTPUT_FRONTEND_INPUT       0
#define OUTPUT_FRONTEND_OUTPUT      0

extern void pdm_rx_debug(
        streaming chanend c_not_a_port,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend ?c_4x_pdm_mic_1);

void generate_backend_input(streaming chanend c_pdm_to_dec){
#if OUTPUT_BACKEND_INPUT
    xscope_int(3, SAMPLE_RATE);
    xscope_int(3, TEST_FREQUENCY);
#endif
    unsigned i=0;
    for(i=0;i<SAMPLE_COUNT;i++){
        int s = (int) ((double)INT_MAX * sin((double)i * OMEGA));
        for(unsigned c=0;c<4;c++)
            c_pdm_to_dec <: s;
#if OUTPUT_BACKEND_INPUT
        delay_microseconds(240);
        xscope_int(3, s);
#endif
    }
    while(1){
        double theta = (double)i * OMEGA;
        int s = (int) ((double)INT_MAX * sin(theta));
        for(unsigned c=0;c<4;c++)
            c_pdm_to_dec <: s;
        i++;
    }
}

void get_backend_output(streaming chanend c_ds_output[1]){

    mic_array_frame_time_domain audio[2];
    unsafe{
        unsigned divider_lut[5] = {2, 4, 6, 8, 12};
        const int * unsafe coef_lut[5] = {
            g_third_stage_div_2_fir,
            g_third_stage_div_4_fir,
            g_third_stage_div_6_fir,
            g_third_stage_div_8_fir,
            g_third_stage_div_12_fir
        };
        const int comp_lut[5] = {
            FIR_COMPENSATOR_DIV_2,
            FIR_COMPENSATOR_DIV_4,
            FIR_COMPENSATOR_DIV_6,
            FIR_COMPENSATOR_DIV_8,
            FIR_COMPENSATOR_DIV_12
        };

        for(unsigned div_index=0;div_index<5;div_index++){

            unsigned buffer;
            unsigned divider = divider_lut[div_index];
            unsigned count = SAMPLE_COUNT/(4*divider);
#if OUTPUT_BACKEND_OUTPUT
            xscope_int(4+div_index,  SAMPLE_RATE/(4.0*(double)divider));
            xscope_int(4+div_index, TEST_FREQUENCY);
#endif

            mic_array_decimator_conf_common_t dcc = {0, 0, 0, 0, divider, coef_lut[div_index], 0, 0, DECIMATOR_NO_FRAME_OVERLAP, 2  };
            mic_array_decimator_config_t dc[1] = { { &dcc, data, { INT_MAX, INT_MAX, INT_MAX, INT_MAX }, 4, 0}};
            mic_array_decimator_configure(c_ds_output, 1, dc);
            mic_array_init_time_domain_frame(c_ds_output, 1 , buffer, audio, dc);

            //first wait until the filter delay has passed
            for(unsigned i=0;i<64;i++)
                mic_array_get_next_time_domain_frame(c_ds_output, 1, buffer, audio, dc);

            for(unsigned i=0;i<count;i++){
                mic_array_frame_time_domain *current = mic_array_get_next_time_domain_frame(c_ds_output, 1, buffer, audio, dc);
#if OUTPUT_BACKEND_OUTPUT
                delay_microseconds(240);
                xscope_int(4+div_index, current->data[0][0]);
#endif
            }
        }

        delay_milliseconds(100);
        _Exit(1);
    }
}



void create_DSD_source(streaming chanend c_not_a_port){

    double sampleRate = 3072000.0;
    double freq = 1000.0;

#if OUTPUT_FRONTEND_INPUT
                    xscope_int(2, PDM_SAMPLE_RATE);
                    xscope_int(2, TEST_FREQUENCY);
#endif

    unsigned s=0;

    double c[] = { 0.79188240, 0.30454538, 0.06992965, 0.00949572, 0.00060680 };
    double g[] = { 0.000496, 0.001789 };

    double s0 = 0;
    double s1 = 0;
    double s2 = 0;
    double s3 = 0;
    double s4 = 0;

    while(1){
        unsigned data = 0;
        for(unsigned i=0;i<4;i++){
            double m =  freq * 2.0 *  PI / sampleRate;
            double x = sin(s*m)*0.5;
            double sum = c[0]*s0 + c[1]*s1 + c[2]*s2 + c[3]*s3 + c[4]*s4;
            double y;
            data = data>>8;
            if (sum >= 0){
                y = 1.0;
                data += 0xff000000;
#if OUTPUT_FRONTEND_INPUT
                if (s < 3072000){
                    delay_microseconds(240);
                    xscope_int(2, 1);
                }
#endif

            } else {
                y = -1.0;
#if OUTPUT_FRONTEND_INPUT
                if (s < 3072000){
                    delay_microseconds(240);
                    xscope_int(2, -1);
                }
#endif
            }
            s4 = s4 + s3;
            s3 = s3 + s2 - g[1]*s4;
            s2 = s2 + s1;
            s1 = s1 + s0 - g[0]*s2;
            s0 = s0 + (x-y);

            s++;
        }
        c_not_a_port <: data;
    }
}

void get_frontend_output(streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1){
    unsigned count = 3072000/8;
#if OUTPUT_FRONTEND_OUTPUT
    xscope_int(1, count);
    xscope_int(1, TEST_FREQUENCY);
#endif
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
#if OUTPUT_FRONTEND_OUTPUT
        delay_microseconds(240);
        xscope_int(1, a);
#endif
    }
}


void test_frontend(){
    streaming chan c_not_a_port, c_4x_pdm_mic_0, c_4x_pdm_mic_1;
    par {
       create_DSD_source(c_not_a_port);
       pdm_rx_debug(c_not_a_port, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
       get_frontend_output(c_4x_pdm_mic_0, c_4x_pdm_mic_1);
    }
}

void test_backend(){
    streaming chan c_pdm_to_dec;
    streaming chan c_ds_output[1];
    par {
        generate_backend_input(c_pdm_to_dec);
        mic_array_decimate_to_pcm_4ch(c_pdm_to_dec, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        get_backend_output(c_ds_output);
    }
}


void test_all(){
    streaming chan c_ds_output[1];
    streaming chan c_not_a_port, c_4x_pdm_mic_0;
    par {
        create_DSD_source(c_not_a_port);
        pdm_rx_debug(c_not_a_port, c_4x_pdm_mic_0, null);
        mic_array_decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0], MIC_ARRAY_NO_INTERNAL_CHANS);
        get_backend_output(c_ds_output);
    }
}


int main(){
    xscope_int(0, 0);   //to make xscope work

    test_all();
    /*
    par {
        test_frontend();
        test_backend();
    }
   */
    return 0;
}
