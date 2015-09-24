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

void lo_hi_res_DAS_fixed(
        streaming chanend c_hires_0,
        streaming chanend c_hires_1,
        streaming chanend c_lores_0,
        streaming chanend c_lores_1,
        hires_delay_config * unsafe config
){

    unsigned buffer = 1;     //buffer index
    frame_audio hires_audio[2];    //double buffered
    frame_audio lores_audio[2];    //double buffered
    memset(hires_audio, sizeof(frame_audio), 2);
    memset(lores_audio, sizeof(frame_audio), 2);

    unsafe{
        c_hires_0 <: (frame_audio * unsafe)hires_audio[0].data[0];
        c_hires_1 <: (frame_audio * unsafe)hires_audio[0].data[2];
        c_lores_0 <: (frame_audio * unsafe)lores_audio[0].data[0];
        c_lores_1 <: (frame_audio * unsafe)lores_audio[0].data[2];

        //set the taps
        while(1){

            schkct(c_hires_0, 8);
            schkct(c_hires_1, 8);
            schkct(c_lores_0, 8);
            schkct(c_lores_1, 8);

            c_hires_0 <: (frame_audio * unsafe)hires_audio[buffer].data[0];
            c_hires_1 <: (frame_audio * unsafe)hires_audio[buffer].data[2];
            c_lores_0 <: (frame_audio * unsafe)lores_audio[buffer].data[0];
            c_lores_1 <: (frame_audio * unsafe)lores_audio[buffer].data[2];

            buffer = 1 - buffer;

            xscope_int(0, hires_audio[buffer].data[0][0].ch_a);
            xscope_int(1, hires_audio[buffer].data[0][0].ch_b);
            xscope_int(2, lores_audio[buffer].data[0][0].ch_a);
            xscope_int(3, lores_audio[buffer].data[0][0].ch_b);
        }
    }
}

int main(){

    par{
        on tile[0]: {
            streaming chan c_hi_4x_pdm_mic_0, c_hi_4x_pdm_mic_1;
            streaming chan c_lo_4x_pdm_mic_0, c_lo_4x_pdm_mic_1;
            streaming chan c_hires_0, c_hires_1;
            streaming chan c_lores_0, c_lores_1;
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
                    pdm_rx_with_hires_delay(
                            p_pdm_mics,
                            p_shared_memory,
                            PDM_BUFFER_LENGTH_LOG2,
                            c_sync,
                            c_lo_4x_pdm_mic_0,
                            c_lo_4x_pdm_mic_1);

                    hires_delay(c_hi_4x_pdm_mic_0, c_hi_4x_pdm_mic_1,
                           c_sync, config, p_shared_memory);

                    decimate_to_pcm_4ch_48KHz(c_hi_4x_pdm_mic_0, c_hires_0, dc);
                    decimate_to_pcm_4ch_48KHz(c_hi_4x_pdm_mic_1, c_hires_1, dc);
                    decimate_to_pcm_4ch_48KHz(c_lo_4x_pdm_mic_0, c_lores_0, dc);
                    decimate_to_pcm_4ch_48KHz(c_lo_4x_pdm_mic_1, c_lores_1, dc);

                    lo_hi_res_DAS_fixed(c_hires_0, c_hires_1, c_lores_0, c_lores_1, config);

                }
            }
        }
    }

    return 0;
}
