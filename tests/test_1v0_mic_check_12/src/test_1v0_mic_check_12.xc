#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>

#include "mic_array.h"

on tile[0]: in port p_pdm_clk             = XS1_PORT_1E;
on tile[0]: in port p_pdm_mics            = XS1_PORT_8B;
on tile[0]: in port p_mclk                = XS1_PORT_1F;
on tile[0]: clock mclk                    = XS1_CLKBLK_1;
on tile[0]: clock pdmclk                  = XS1_CLKBLK_2;

void lores_DAS_fixed(streaming chanend c_ds_output_0, streaming chanend c_ds_output_1){

    unsigned buffer = 1;     //buffer index
    frame_audio audio[2];    //double buffered
    memset(audio, sizeof(frame_audio), 2);

    unsigned long long energy[8] = {0};
    int prev_val[8] = {0};
    int val[8] = {0};



    unsafe{
        c_ds_output_0 <: (frame_audio * unsafe)audio[0].data[0];
        c_ds_output_1 <: (frame_audio * unsafe)audio[0].data[2];

        unsigned count = 0;
        while(1){

            schkct(c_ds_output_0, 8);
            schkct(c_ds_output_1, 8);

            c_ds_output_0 <: (frame_audio * unsafe)audio[buffer].data[0];
            c_ds_output_1 <: (frame_audio * unsafe)audio[buffer].data[2];
            count++;
            buffer = 1 - buffer;


            prev_val[0] = val[0];
            val[0] = audio[buffer].data[0][0].ch_a;
            prev_val[1] = val[1];
            val[1] = audio[buffer].data[0][0].ch_b;
            prev_val[2] = val[2];
            val[2] = audio[buffer].data[1][0].ch_a;
            prev_val[3] = val[3];
            val[3] = audio[buffer].data[1][0].ch_b;
            prev_val[4] = val[4];
            val[4] = audio[buffer].data[2][0].ch_a;
            prev_val[5] = val[5];
            val[5] = audio[buffer].data[2][0].ch_b;
            prev_val[6] = val[6];
            val[6] = audio[buffer].data[3][0].ch_a;
            prev_val[7] = val[7];
            val[7] = audio[buffer].data[3][0].ch_b;

#define N 4
            for(unsigned i=0;i<8;i++){
                int delta = val[i] - prev_val[i];
                energy[i] += (delta*delta);
                energy[i] =  energy[i] - (energy[i]>>N);
            }

             if(count == (24000)){
                for(unsigned i=0;i<8;i++){
                    if(energy[i] <= (1<<N)){
                        printf("* ");
                    } else {
                        printf("%d ", i);
                    }
                }
                printf("\n");
                count = 0;
             }


        }
    }
}

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
            decimator_config dc = {0, 1, 0, 0};
            par{
                pdm_rx(p_pdm_mics, c_4x_pdm_mic_0, c_4x_pdm_mic_1);
                decimate_to_pcm_4ch_48KHz(c_4x_pdm_mic_0, c_ds_output_0, dc);
                decimate_to_pcm_4ch_48KHz(c_4x_pdm_mic_1, c_ds_output_1, dc);
                lores_DAS_fixed(c_ds_output_0, c_ds_output_1);
            }
        }
    }
    return 0;
}
