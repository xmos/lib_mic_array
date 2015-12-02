// Copyright (c) 2015, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>

#include "mic_array.h"

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_2;

//This sets the FIR decimation factor.
#define DF 3

int data_0[4*COEFS_PER_PHASE*DF] = {0};
int data_1[4*COEFS_PER_PHASE*DF] = {0};

void example(streaming chanend c_pcm_0,
        streaming chanend c_pcm_1,
        hires_delay_config * unsafe config
){

    unsigned buffer;
    frame_audio audio[2];    //double buffered

    unsigned decimation_factor=DF;

    unsafe{
        decimator_config_common dcc = {FRAME_SIZE_LOG2, 1, 0, 0, decimation_factor, fir_coefs[decimation_factor], 0};
        decimator_config dc0 = {&dcc, data_0, {INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
        decimator_config dc1 = {&dcc, data_1,{INT_MAX, INT_MAX, INT_MAX, INT_MAX}};
        decimator_configure(c_pcm_0, c_pcm_1, dc0, dc1);
    }

    decimator_init_audio_frame(c_pcm_0, c_pcm_1, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

    while(1){

        frame_audio *  current = decimator_get_next_audio_frame(c_pcm_0, c_pcm_1, buffer, audio);

        // code goes here

    }
}

int main(){

    par{
        on tile[0]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output_0, c_ds_output_1;
            streaming chan c_sync;

            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            int64_t shared_memory[PDM_BUFFER_LENGTH] = {0};

            unsafe {
                hires_delay_config hrd_config;
                hrd_config.active_delay_set = 0;
                hrd_config.memory_size_log2 = PDM_BUFFER_LENGTH_LOG2;
                hires_delay_config * unsafe config = &hrd_config;

                int64_t * unsafe p_shared_memory = shared_memory;

                par{
                    pdm_rx_hires_delay(p_pdm_mics, p_shared_memory,
                            PDM_BUFFER_LENGTH_LOG2, c_sync);

                    hires_delay(c_4x_pdm_mic_0, c_4x_pdm_mic_1,
                           c_sync, config, p_shared_memory);

                    decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output_0);
                    decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output_1);

                    example(c_ds_output_0, c_ds_output_1, config);
                }
            }
        }
    }

    return 0;
}
