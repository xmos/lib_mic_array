// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include "mic_array.h"

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

//This sets the FIR decimation factor.
//Note that the coefficient array passed into dcc must match this.
#define DF 6

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];

void example(streaming chanend c_ds_output[2]){

    unsigned buffer;
    unsafe{
        decimator_config_common dcc = {
                0, // frame size log 2 is set to 0, i.e. one sample per channel will be present in each frame
                1, // DC offset elimination is turned on
                0, // Index bit reversal is off
                0, // No windowing function is being applied
                DF,// The decimation factor is set to 6
                g_third_16kHz_fir, //This corresponds to a 16kHz output hence this coef array is used
                0, // Gain compensation is turned off
                0  // FIR compensation is turned off
        };
        decimator_config dc[2] = {
                {
                        &dcc,
                        data_0,     // The storage area for the output decimator
                        {INT_MAX, INT_MAX, INT_MAX, INT_MAX},  // Microphone gain compensation (turned off)
                        4           // Enabled channel count
                },
                {
                        &dcc,
                        data_1,     // The storage area for the output decimator
                        {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, // Microphone gain compensation (turned off)
                        4           // Enabled channel count
                }
        };
        decimator_configure(c_ds_output, 2, dc);
    }

    decimator_init_audio_frame(c_ds_output, 2, buffer, audio, DECIMATOR_NO_FRAME_OVERLAP);

    while(1){

        //The final argument is set to two to reflect that frame_audio audio[2]; is size 2 also.
        frame_audio *  current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, 2);

        //buffer and audio should never be accessed.

        int ch0_sample0 = current->data[0][0];
        int ch1_sample0 = current->data[1][0];


    }
}

int main(){
    par{
        on tile[0]:{
            streaming chan c_pdm_to_dec[2];
            streaming chan c_ds_output[2];

            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            par{
                pdm_rx(p_pdm_mics, c_pdm_to_dec[0], c_pdm_to_dec[1]);
                decimate_to_pcm_4ch(c_pdm_to_dec[0], c_ds_output[0]);
                decimate_to_pcm_4ch(c_pdm_to_dec[1], c_ds_output[1]);
                example(c_ds_output);
            }
        }
    }
    return 0;
}
