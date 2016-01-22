// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <platform.h>
#include <xs1.h>

#include "mic_array.h"

on tile[0]: in port p_pdm_clk               = XS1_PORT_1E;
on tile[0]: in buffered port:32 p_pdm_mics  = XS1_PORT_8B;
on tile[0]: in port p_mclk                  = XS1_PORT_1F;
on tile[0]: clock pdmclk                    = XS1_CLKBLK_2;

// This sets the FIR decimation factor.
// Note that the coefficient array passed into dcc must match this.
#define DF 6

int data_0[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
int data_1[4*THIRD_STAGE_COEFS_PER_STAGE*DF] = {0};
frame_audio audio[2];    //double buffered

void example(streaming chanend c_ds_output[2], streaming chanend c_cmd) {

    unsafe{
        unsigned buffer;

            decimator_config_common dcc = {
                    0, // Frame size log 2 is set to 0, i.e. one sample per channel will be present in each frame
                    1, // DC offset elimination is turned on
                    0, // Index bit reversal is off
                    0, // No windowing function is being applied
                    DF,// The decimation factor is set to 6
                    g_third_stage_div_6_fir, // This corresponds to a 16kHz output hence this coef array is used
                    0, // Gain compensation is turned off
                    0, // FIR compensation is turned off
                    DECIMATOR_NO_FRAME_OVERLAP, // Frame overlapping is turned off
                    2  // There are 2 buffers in the audio array
            };
            decimator_config dc[2] = {
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
            decimator_configure(c_ds_output, 2, dc);


        decimator_init_audio_frame(c_ds_output, 2, buffer, audio, dcc);

        while(1){
            frame_audio *current = decimator_get_next_audio_frame(c_ds_output, 2, buffer, audio, dcc);

            // Buffer and audio should never be accessed.

            int ch0_sample0 = current->data[0][0];
            int ch1_sample0 = current->data[1][0];

            // Update the delays. Delay values must be in range 0..HIRES_MAX_DELAY
            unsigned delays[7] = {0, 1, 2, 3, 4, 5, 6};
            hires_delay_set_taps(c_cmd, delays, 7);
        }
    }
}

int main() {

    par {
        on tile[0]: {
            configure_clock_src_divide(pdmclk, p_mclk, 4);
            configure_port_clock_output(p_pdm_clk, pdmclk);
            configure_in_port(p_pdm_mics, pdmclk);
            start_clock(pdmclk);

            streaming chan c_pdm_to_hires[2];
            streaming chan c_hires_to_dec[2];
            streaming chan c_ds_output[2];
            streaming chan c_cmd;

            par {
                pdm_rx(p_pdm_mics, c_pdm_to_hires[0], c_pdm_to_hires[1]);
                hires_delay(c_pdm_to_hires, c_hires_to_dec, 2, c_cmd);
                decimate_to_pcm_4ch(c_hires_to_dec[0], c_ds_output[0]);
                decimate_to_pcm_4ch(c_hires_to_dec[1], c_ds_output[1]);
                example(c_ds_output, c_cmd);
            }
        }
    }

    return 0;
}
