// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include "mic_array.h"

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

//This sets the FIR decimation factor.
#define DF 6

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];

void example(streaming chanend c_ds_output[2]){

    unsigned buffer;
    unsafe{
        decimator_config_common dcc = {0, 1, 0, 0, DF, g_third_16kHz_fir, 0, 0};
        decimator_config dc[2] = {
                {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4},
                {&dcc, data_1, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, 4}
        };
        decimator_configure(c_ds_output, 2, dc);
    }

    decimator_init_audio_frame(c_ds_output, 2, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

    while(1){

        frame_audio *  current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);

        // code goes here

    }
}

int main(){
    par{
        on tile[0]:{
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output[2];

            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            par{
                pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
                decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);
                example(c_ds_output);
            }
        }
    }
    return 0;
}
