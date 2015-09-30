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

void hires_DAS_fixed(streaming chanend c_ds_output_0,
        streaming chanend c_ds_output_1,
        hires_delay_config * unsafe config
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

            for(unsigned i=0;i<7;i++)
                xscope_int(i, audio[buffer].data[i][0]);
        }
    }
}

int main(){

    par{
        on tile[0]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output_0, c_ds_output_1;
            streaming chan c_sync;

            configure_clock_src(mclk, p_mclk);
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(mclk);
            start_clock(pdmclk);

            unsigned long long shared_memory[PDM_BUFFER_LENGTH] = {0};

            decimator_config dc = {0, 1, 0, 0};
            unsafe {
                hires_delay_config hrd_config;
                hrd_config.active_delay_set = 0;
                hrd_config.memory_depth_log2 = PDM_BUFFER_LENGTH_LOG2;

                hires_delay_config * unsafe config = &hrd_config;
                unsigned long long * unsafe p_shared_memory = shared_memory;
                par{
                    //Input stage
                    pdm_rx_only_hires_delay(
                            p_pdm_mics,
                            p_shared_memory,
                            PDM_BUFFER_LENGTH_LOG2,
                            c_sync);

                    hires_delay(c_4x_pdm_mic_0, c_4x_pdm_mic_1,
                           c_sync, config, p_shared_memory);

                   decimate_to_pcm_4ch_48KHz(c_4x_pdm_mic_0, c_ds_output_0, dc);
                   decimate_to_pcm_4ch_48KHz(c_4x_pdm_mic_1, c_ds_output_1, dc);

                   hires_DAS_fixed(c_ds_output_0, c_ds_output_1, config);

                }
            }
        }
    }

    return 0;
}
