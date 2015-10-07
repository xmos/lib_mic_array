#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <xclib.h>

#include "mic_array.h"

on tile[0]: in port p_pdm_clk             = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics            = XS1_PORT_8B;
on tile[0]: in port p_mclk                = XS1_PORT_1F;
on tile[0]: clock mclk                    = XS1_CLKBLK_1;
on tile[0]: clock pdmclk                  = XS1_CLKBLK_2;

void lores_DAS_fixed(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1){

    unsigned buffer = 1;     //buffer index
    frame_audio audio[2];    //double buffered
    memset(audio, sizeof(frame_audio), 2);

    unsafe{
        c_ds_output_0 <: (frame_audio * unsafe)audio[0].data[0];
        c_ds_output_1 <: (frame_audio * unsafe)audio[0].data[4];

        while(1){

            schkct(c_ds_output_0, 8);
            schkct(c_ds_output_1, 8);

            c_ds_output_0 <: (frame_audio * unsafe)audio[buffer].data[0];
            c_ds_output_1 <: (frame_audio * unsafe)audio[buffer].data[4];

            buffer = 1 - buffer;


            //todo buffer the frame
            //sum
            //output
            for(unsigned i=0;i<7;i++)
                xscope_int(i, audio[buffer].data[i][0]);
        }
    }
}
void pdm_rx16_asm(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1);

void pdm_rx16(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1){

    delay_milliseconds(1000);

    //This will never return
    pdm_rx16_asm(p_pdm_mics,
            c_4x_pdm_mic_0,c_4x_pdm_mic_1);
}

void decimate_to_pcm_4ch_16kHz(
        streaming chanend c_4x_pdm_mic,
        streaming chanend c_frame_output,
        decimator_config config);

int main(){

    par{
        on tile[0]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output_0, c_ds_output_1;

            configure_clock_src(mclk, p_mclk);
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(mclk);
            start_clock(pdmclk);

            unsafe {
                uint64_t coefs[3][30];
                unsigned * unsafe p[3] = {coefs[0], coefs[1], coefs[2]};
                printf("%p %p %p\n", coefs[0], coefs[1], coefs[2]);


                unsigned data[4*60*3];

                decimator_config dc = {0, 1, 0, 0, 3, p, data, {0,0, 0, 0}};
                par{
                    pdm_rx16(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);

                    decimate_to_pcm_4ch_16kHz(c_4x_pdm_mic_0, c_ds_output_0, dc);
                    decimate_to_pcm_4ch_16kHz(c_4x_pdm_mic_1, c_ds_output_1, dc);
                    lores_DAS_fixed(c_ds_output_0, c_ds_output_1);
                }
            }
        }
    }
    return 0;
}
