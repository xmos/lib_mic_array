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

           // for(unsigned i=0;i<7;i++)
            //    xscope_int(i, audio[buffer].data[i][0]);
            xscope_int(0, audio[buffer].data[0][0]);
        }
    }
}

//#define SIM
void pdm_rx16_asm(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1);

void pdm_rx16(
        in buffered port:32 p_pdm_mics,
        streaming chanend c_4x_pdm_mic_0,
        streaming chanend c_4x_pdm_mic_1){

#ifndef SIM
    delay_milliseconds(1000);
#endif
    pdm_rx16_asm(p_pdm_mics,
            c_4x_pdm_mic_0,c_4x_pdm_mic_1);
}

int main(){

    par{
        on tile[0]: {

            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output_0, c_ds_output_1;

#ifndef SIM

            configure_clock_src(mclk, p_mclk);
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(mclk);
            start_clock(pdmclk);

            unsafe {
                uint64_t coefs[3][30];
                memset(coefs, 0 ,sizeof(unsigned)*60*3);
                unsigned * unsafe p[3] = {(unsigned *)coefs[0], (unsigned *)coefs[1], (unsigned *)coefs[2]};

                uint64_t data_0[4*30*3] = {0};
                uint64_t data_1[4*30*3] = {0};

                decimator_config dc0 = {0, 1, 0, 0, 3, p, data_0, {0,0, 0, 0}};
                decimator_config dc1 = {0, 1, 0, 0, 3, p, data_1, {0,0, 0, 0}};
                par{
                    pdm_rx16(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                    decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0, dc0);
                    decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1, dc1);
                    lores_DAS_fixed(c_ds_output_0, c_ds_output_1);
                }
            }
#else
            configure_clock_ref(mclk, 50);
            configure_in_port(p_pdm_mics, mclk);
            start_clock(mclk);
            unsafe {
                uint64_t coefs[3][30];
                memset(coefs, 0 ,sizeof(unsigned)*60*3);
                unsigned * unsafe p[3] = {coefs[0], coefs[1], coefs[2]};
                uint64_t data[4*30*3] = {0};

                decimator_config dc = {0, 1, 0, 0, 3, p, data, {0,0, 0, 0}};
                par{
                    pdm_rx16(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);

                    decimate_to_pcm_4ch_16kHz(c_4x_pdm_mic_0, c_ds_output_0, dc);
                    decimate_to_pcm_4ch_16kHz(c_4x_pdm_mic_1, c_ds_output_1, dc);
                    lores_DAS_fixed(c_ds_output_0, c_ds_output_1);
                }
            }
#endif
        }
    }
    return 0;
}
