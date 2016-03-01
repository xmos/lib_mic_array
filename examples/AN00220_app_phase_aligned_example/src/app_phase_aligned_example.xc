// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>
#include "mic_array.h"

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_1;

// This sets the FIR decimation factor.
// Note that the coefficient array passed into dcc must match this.
#define DF 6

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};

void example(streaming chanend c_ds_output[2]) {
    unsafe{
        mic_array_frame_time_domain audio[2];    //double buffered

        unsigned buffer;

        mic_array_decimator_config_common dcc = {
                    0, // Frame size log 2 is set to 0, i.e. one sample per channel will be present in each frame
                    1, // DC offset elimination is turned on
                    0, // Index bit reversal is off
                    0, // No windowing function is being applied
                    DF,// The decimation factor is set to 6
                    g_third_stage_div_6_fir, // This corresponds to a 16kHz output hence this coef array is used
                    0, // Gain compensation is turned off
                    FIR_COMPENSATOR_DIV_6, // FIR compensation is set to the corresponding coefficients
                    DECIMATOR_NO_FRAME_OVERLAP, // Frame overlapping is turned off
                    2  // There are 2 buffers in the audio array
            };

        mic_array_decimator_config dc[2] = {
                    {
                            &dcc,
                            data_0,     // The storage area for the output decimator
                            {INT_MAX, INT_MAX, INT_MAX, INT_MAX},  // Microphone gain compensation (turned off)
                            4           // Enabled channel count (currently must be 4)
                    },
                    {
                            &dcc,
                            data_1,     // The storage area for the output decimator
                            {INT_MAX, INT_MAX, INT_MAX, INT_MAX}, // Microphone gain compensation (turned off)
                            4           // Enabled channel count (currently must be 4)
                    }
            };
        mic_array_decimator_configure(c_ds_output, 2, dc);


        mic_array_init_time_domain_frame(c_ds_output, 2, buffer, audio, dc);

        while(1){
            mic_array_frame_time_domain *  current =
                                mic_array_get_next_time_domain_frame(c_ds_output, 2, buffer, audio, dc);

            // Buffer and audio should never be accessed.
            int ch0_sample0 = current->data[0][0];
            int ch1_sample0 = current->data[1][0];
        }
    }
}

int main(){
    par{
        on tile[0]:{
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            streaming chan c_pdm_to_dec[2];
            streaming chan c_ds_output[2];

            par{
                mic_array_pdm_rx(p_pdm_mics, c_pdm_to_dec[0], c_pdm_to_dec[1]);
                mic_array_decimate_to_pcm_4ch(c_pdm_to_dec[0], c_ds_output[0]);
                mic_array_decimate_to_pcm_4ch(c_pdm_to_dec[1], c_ds_output[1]);
                example(c_ds_output);
            }
        }
    }
    return 0;
}
