// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <xclib.h>

#include "fir_decimator.h"
#include "mic_array.h"

on tile[0]: in port p_pdm_clk             = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics            = XS1_PORT_8B;
on tile[0]: in port p_mclk                = XS1_PORT_1F;
on tile[0]: clock mclk                    = XS1_CLKBLK_1;
on tile[0]: clock pdmclk                  = XS1_CLKBLK_2;

#define DF 6
int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];

void mic_calib(streaming chanend c_ds_output[2], chanend c){

    unsigned buffer;     //buffer index
    unsafe{

        decimator_config_common dcc = {0, 1, 0, 0, DF, g_third_stage_div_6_fir, 0, 0};
        decimator_config dcf[2] = {
                {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
                {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };
        decimator_configure(c_ds_output, 2, dcf);

        int64_t sum[7]={0};

#define N 24

        for(unsigned count=0;count<1<<N;count++){

            frame_audio *  current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);

            for(unsigned i=0;i<7;i++)
                sum[i] += current->data[i][0];
        }
        int64_t dc[7];
        for(unsigned i=0;i<7;i++){
            dc[i] = sum[i]>>N;
            printf("DC Offset for mic %d: %d\n", i, dc[i]);
        }

        int64_t rms[7] = {0};

        for(unsigned count=0;count<1<<N;count++){

            frame_audio *  current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);

            for(unsigned i=0;i<7;i++){
                int64_t v = (int64_t)current->data[i][0];
                v= (v-dc[i]) >> (33 - ((64-N)/2));
                rms[i] += v*v;
            }

        }

        for(unsigned i=0;i<7;i++)
            printf("%llu\n", rms[i]);

        _Exit(1);
    }
}

void consumer(chanend c){
    while(1){
        c:> int;
    }
}


int main(){

    par{
        on tile[0]: {

            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output[2];
            configure_clock_src(mclk, p_mclk);
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(mclk);
            start_clock(pdmclk);

            unsafe {

                chan c;
                par{
                    pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                    decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
                    decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);
                    mic_calib(c_ds_output, c);
                    consumer(c);
                }
            }
        }
    }
    return 0;
}
