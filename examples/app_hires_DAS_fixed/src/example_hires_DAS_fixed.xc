#include <xscope.h>
#include <platform.h>
#include <xs1.h>
#include <stdlib.h>
#include <print.h>
#include <stdio.h>
#include <string.h>
#include <xclib.h>

#include "mic_array.h"

on tile[1]: in port p_pdm_clk = XS1_PORT_1C;
on tile[1]: in buffered port:8 p_pdm_mics = XS1_PORT_8B;

out buffered port:32 p_dout[2] = on tile[1]: {XS1_PORT_1D, XS1_PORT_1H};
in buffered port:32 p_din[1] = on tile[1]: {XS1_PORT_1K};

in port p_mclk                 = on tile[1]: XS1_PORT_1E;
out buffered port:32 p_bclk    = on tile[1]: XS1_PORT_1A;
out buffered port:32 p_lrclk   = on tile[1]: XS1_PORT_1I;
port p_i2c                     = on tile[1]: XS1_PORT_4F;
port p_aud_shared              = on tile[1]: XS1_PORT_4E;
clock mclk                     = on tile[1]: XS1_CLKBLK_1;
clock bclk                     = on tile[1]: XS1_CLKBLK_2;
clock pdmclk                   = on tile[1]: XS1_CLKBLK_3;

in port p_buttons = on tile[0]: XS1_PORT_4C;




void hires_DAS_fixed(streaming chanend c_ds_output_0,
        streaming chanend c_ds_output_1,
        unsigned long long * unsafe p_taps
){

    unsigned buffer = 1;     //buffer index
    frame_audio audio[2];    //double buffered
    memset(audio, sizeof(frame_audio), 2);



    unsafe{
        c_ds_output_0 <: (frame_audio * unsafe)audio[0].data[0];
        c_ds_output_1 <: (frame_audio * unsafe)audio[0].data[2];

        //set the taps


        while(1){

                schkct(c_ds_output_0, 8);
                schkct(c_ds_output_1, 8);

                c_ds_output_0 <: (frame_audio * unsafe)audio[buffer].data[0];
                c_ds_output_1 <: (frame_audio * unsafe)audio[buffer].data[2];

                buffer = 1 - buffer;

                int sum = audio[buffer].data[0][0].ch_a+audio[buffer].data[0][0].ch_b;
                sum = audio[buffer].data[1][0].ch_a+audio[buffer].data[1][0].ch_b;
                sum = audio[buffer].data[2][0].ch_a+audio[buffer].data[2][0].ch_b;
                sum = audio[buffer].data[3][0].ch_a+audio[buffer].data[3][0].ch_b;

                xscope_int(0, sum);
        }
    }

}

int main(){

    par{
        on tile[1]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output_0, c_ds_output_1;

            streaming chan c_sync;

            configure_clock_src(mclk, p_mclk);
            configure_clock_src_divide(pdmclk, p_mclk, 8/2);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(mclk);
            start_clock(pdmclk);

            unsigned long long taps[4];
            unsigned long long shared_memory[PDM_BUFFER_LENGTH] = {0};
            unsafe {
                unsigned long long * unsafe p_taps = taps;
                unsigned long long * unsafe p_shared_memory = shared_memory;
                par{
                    //Input stage
                    pdm_first_stage_only_delay_and_sum(
                            p_pdm_mics,
                            p_shared_memory,
                            PDM_BUFFER_LENGTH_LOG2,
                            c_sync);

                   delay_and_sum(c_4x_pdm_mic_0, c_4x_pdm_mic_1,
                           c_sync, PDM_BUFFER_LENGTH_LOG2,
                           p_taps, p_shared_memory);

                    pdm_to_pcm_4x_48KHz(c_4x_pdm_mic_0, c_ds_output_0);
                    pdm_to_pcm_4x_48KHz(c_4x_pdm_mic_1, c_ds_output_1);


                    hires_DAS_fixed(c_ds_output_0, c_ds_output_1, p_taps);

                }
            }
        }
    }

    return 0;
}
