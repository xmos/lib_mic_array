// Copyright (c) 2015, XMOS Ltd, All rights reserved
#include <platform.h>
#include <stdlib.h>
#include <xs1.h>
#include "mic_array.h"
#include <xscope.h>
#include <stdio.h>

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

int data_0[4*COEFS_PER_PHASE*MAX_DECIMATION_FACTOR] = {0};
int data_1[4*COEFS_PER_PHASE*MAX_DECIMATION_FACTOR] = {0};

void example(streaming chanend c_pcm_0,
        streaming chanend c_pcm_1){

    unsigned buffer;

    frame_audio audio[2];    //double buffered

#define TEST_SECONDS 16  //don't exceed 20
#define TPS 100000000

    for(unsigned decimation_factor=1; decimation_factor<=8;decimation_factor++){

        unsafe{
            decimator_config_common dcc = {FRAME_SIZE_LOG2, 1, 0, 0, decimation_factor, fir_coefs[decimation_factor], 0};
            decimator_config dc0 = {&dcc, data_0, {0, 0, 0, 0}};
            decimator_config dc1 = {&dcc, data_1, {0, 0, 0, 0}};
            decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
        }

        decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

        timer t;
        unsigned now, then;

        for(unsigned pass =0 ; pass < 1; pass++){

            for(unsigned i=0;i<8;i++)
                decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);

            decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
            t :> then;
            for(unsigned i=0;i<((TEST_SECONDS*48000)/decimation_factor)-2;i++)
                decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
            decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);
            t :> now;

            unsigned elapsed = now - then;
            int diff = elapsed - TPS*TEST_SECONDS;
            if (diff<0) diff = -diff;
            float error = (diff*100.0)/(TPS*TEST_SECONDS);
            printf("decimation:%d rate:%d error:%f%%: %s\n", decimation_factor,
                    48000/decimation_factor, error, (error < 0.01)?"Pass":"Fail");
        }
    }
    _Exit(1);
}

int main(){
    par{
        on tile[0]:{
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output_0, c_ds_output_1;

            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            par{
                pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
                decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);
                example(c_ds_output_0, c_ds_output_1);
            }
        }
    }
    return 0;
}
