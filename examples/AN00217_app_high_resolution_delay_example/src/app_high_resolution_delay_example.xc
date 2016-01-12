// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>

#include "mic_array.h"

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_2;

//This sets the FIR decimation factor.
#define DF 6

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};

void example(streaming chanend c_ds_output[2],
        hires_delay_config * unsafe config
){

    unsigned buffer;
    frame_audio audio[2];    //double buffered

    unsafe{
        decimator_config_common dcc = {0, 1, 0, 0, DF, g_third_48kHz_fir, 0, 0};
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
        on tile[0]: {
            streaming chan c_4x_pdm_mic_0, c_4x_pdm_mic_1;
            streaming chan c_ds_output[2];
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

                    decimate_to_pcm_4ch(c_4x_pdm_mic_0, c_ds_output[0]);
                    decimate_to_pcm_4ch(c_4x_pdm_mic_1, c_ds_output[1]);

                    example(c_ds_output, config);
                }
            }
        }
    }

    return 0;
}
